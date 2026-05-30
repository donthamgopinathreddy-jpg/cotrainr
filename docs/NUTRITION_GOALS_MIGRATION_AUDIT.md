# Nutrition Goals Migration Audit

Migration file: `supabase/migrations/20250604_nutrition_goals_planner_complete.sql`

---

## Before changing — review findings

| Problem | Risk | Existing data impact |
|--------|------|----------------------|
| `ALTER TABLE ADD COLUMN` without follow-up NOT NULL on upgraded DBs | **Medium** | Legacy rows could have NULL `goal_calories`, macros, timestamps |
| `EXCEPTION WHEN others THEN NULL` on `formula_version SET NOT NULL` | **High** | Migration could succeed while column stayed nullable — silent failure |
| No CHECK constraints on macro targets | **Medium** | Invalid zeros/negatives could be stored from bad clients |
| No `updated_at` trigger | **Low** | Stale `updated_at` if Flutter omits the field |
| `formula_version` backfill present but weak enforcement | **Medium** | Old rows might lack version for recalculation |
| Planner negatives not guarded | **Low** | Negative weight/timeline possible in DB |
| RLS policies | **Low** | Already correct; idempotent recreate is safe |

**Existing data:** Backfill step resets invalid macro NULLs/negatives to MVP defaults (`2000` kcal, etc.). Negative planner fields are set to `NULL` (not deleted). Rows with deliberately invalid macros before migration will be **corrected**, not removed.

---

## After changing

### 1. Changes made

- Kept **single table**, `user_id` PRIMARY KEY (no history table).
- Added explicit **backfill** then **DEFAULT + NOT NULL** for: `goal_calories`, `goal_protein`, `goal_carbs`, `goal_fats`, `goal_fiber`, `is_active`, `created_at`, `updated_at`, `formula_version`.
- Removed unsafe **`EXCEPTION WHEN others THEN NULL`** block.
- Added **CHECK** constraints for macros, water, timeline, and planner numerics.
- Ensured **`set_updated_at()`** + `trg_nutrition_goals_updated_at` on `BEFORE UPDATE`.
- Preserved all **planner fields** (`current_weight_kg`, `target_weight_kg`, `timeline_days`, `timeline_weeks`, `weekly_change_kg`, `maintenance_calories`, `bmr`, `formula_version`).
- Recreated **RLS** policies (SELECT/INSERT/UPDATE/DELETE own row).
- Added table/column **COMMENT** documenting Flutter upsert requirement.

### 2. Constraints added

| Constraint | Rule |
|------------|------|
| `nutrition_goals_goal_calories_positive` | `goal_calories > 0` |
| `nutrition_goals_goal_protein_non_negative` | `goal_protein >= 0` |
| `nutrition_goals_goal_carbs_non_negative` | `goal_carbs >= 0` |
| `nutrition_goals_goal_fats_non_negative` | `goal_fats >= 0` |
| `nutrition_goals_goal_fiber_non_negative` | `goal_fiber >= 0` |
| `nutrition_goals_goal_water_ml_valid` | `goal_water_ml IS NULL OR goal_water_ml >= 0` |
| `nutrition_goals_timeline_days_positive` | `timeline_days IS NULL OR timeline_days > 0` |
| `nutrition_goals_timeline_weeks_positive` | `timeline_weeks IS NULL OR timeline_weeks > 0` |
| `nutrition_goals_planner_non_negative` | Planner numerics `>= 0` or NULL; age 13–120; workout days 0–7 |

### 3. Trigger added

```sql
CREATE OR REPLACE FUNCTION public.set_updated_at() ...
CREATE TRIGGER trg_nutrition_goals_updated_at
  BEFORE UPDATE ON public.nutrition_goals
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

`updated_at` is refreshed on every UPDATE regardless of Flutter payload.

### 4. RLS verification

| Operation | Policy | Rule |
|-----------|--------|------|
| SELECT | `Users can select own nutrition goals` | `auth.uid() = user_id` |
| INSERT | `Users can insert own nutrition goals` | `WITH CHECK (auth.uid() = user_id)` |
| UPDATE | `Users can update own nutrition goals` | `USING` + `WITH CHECK (auth.uid() = user_id)` |
| DELETE | `Users can delete own nutrition goals` | `auth.uid() = user_id` |

### 5. Upsert strategy (Flutter)

`user_id` is the primary key. **Always** save with upsert:

```dart
await supabase.from('nutrition_goals').upsert(
  { 'user_id': userId, ...fields },
  onConflict: 'user_id',
);
```

Implemented in: `lib/repositories/nutrition_goal_planner_repository.dart` (`saveActiveGoal`).

Do **not** use insert-only flows for goal saves — a second insert for the same user will fail on PK conflict.

`updated_at` in the upsert payload is optional; DB trigger sets it on UPDATE. `created_at` is set by default on first insert.

### 6. Remaining risks

| Risk | Mitigation |
|------|------------|
| Backfill overwrites custom low calorie goals that were `<= 0` | App should never send invalid values; CHECK blocks future bad writes |
| `goal_protein = 0` allowed by CHECK | Valid for edge cases; calories must be `> 0` |
| Upsert without `onConflict` | Documented; repository already correct |
| Older partial migrations (`20250601`–`20250603`) | `20250604` is idempotent; safe to run after them |

### 7. Final schema summary

**Table:** `public.nutrition_goals`  
**PK:** `user_id` → `auth.users(id)` ON DELETE CASCADE  
**Cardinality:** One row per user  

**Required columns (NOT NULL):**  
`goal_calories`, `goal_protein`, `goal_carbs`, `goal_fats`, `goal_fiber`, `formula_version`, `is_active`, `created_at`, `updated_at`

**Optional planner / metadata:**  
`goal_water_ml`, `goal_type`, `activity_level`, `workout_days_per_week`, `planner_*`, `current_weight_kg`, `target_weight_kg`, `timeline_days`, `timeline_weeks`, `weekly_change_kg`, `maintenance_calories`, `bmr`

**Defaults:** Macros per MVP; `formula_version = 'mifflin_st_jeor_v1'`; `is_active = true`; timestamps `now()`
