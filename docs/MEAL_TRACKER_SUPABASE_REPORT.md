# Meal Tracker → Supabase: Step 0 & Step 1 Report

## Step 0 — UI Scan and Report

### Main Meal Tracker Pages

| File | Route | Description |
|------|-------|-------------|
| `lib/pages/meal_tracker/meal_tracker_page_v2.dart` | `/meal-tracker` (via Quick Access) | **Primary screen** – full meal tracker with date, goals, meals, add/edit/delete |
| `lib/pages/meal_tracker/meal_tracker_page.dart` | (legacy, not routed) | Simpler version – mock data, Add Food sheet, Weekly Insights |
| `lib/pages/meal_tracker/weekly_insights_page.dart` | Via `WeeklyInsightsPage` | Week view – bar chart by day, metric selector (calories/protein/carbs/fats), mock data |
| `lib/theme/meal_tracker_tokens.dart` | — | Design tokens (colors, gradients, radii) |

**Active entry point:** Router uses `MealTrackerPageV2` at `/meal-tracker`.

---

### UI Elements in MealTrackerPageV2 (Primary)

#### 1. **Date picker / day navigation**
- **Location:** Header + horizontal week strip
- **Elements:**
  - Calendar icon → `showDatePicker` (full calendar)
  - Week strip: 7 days (Mon–Sun), tap to select day
- **Data needed:** `_selectedDate`, `_weekStart`, `_weekDays()` – per-day logs

#### 2. **Macro totals (daily summary card)**
- **Location:** `_DailySummary` / `_MealTrackerSummary`
- **Elements:**
  - Calories: current / goal (e.g. 1260 / 2000)
  - Progress ring (calories %)
  - Protein, Carbs, Fats, Fiber chips
  - "Edit goals" button
- **Data needed:** `calories`, `protein`, `carbs`, `fats`, `fiber`, `goalCalories`, `goalProtein`, `goalCarbs`, `goalFats`, `goalFiber`

#### 3. **Edit goals**
- **Location:** `_EditGoalsSheet` (modal)
- **Elements:** TextFields for calories, protein, carbs, fats, fiber
- **Data needed:** User goals (per-user, persistent)

#### 4. **Meal tiles (Breakfast, Lunch, Dinner, Snacks + custom)**
- **Location:** `_MealTile` list (reorderable)
- **Elements:**
  - Meal type, item count, calories, protein, carbs, fats
  - Add food button (+)
  - Add photo button (camera)
  - Tap → open meal detail sheet
- **Data needed:** Per-meal items, per-meal photo path (local for now)

#### 5. **Add custom meal**
- **Location:** `_AddMealTile` → `_addCustomMeal()`
- **Elements:** Dialog with TextField (e.g. "Pre-workout")
- **Data needed:** Custom meal type name (string)

#### 6. **Add food sheet** (`_AddFoodSheet`)
- **Step 0 – Food picker:**
  - Search TextField (filters `commonFoods` + `recentFoods`)
  - Recent foods (horizontal chips)
  - Foods list (filtered)
- **Step 1 – Food details:**
  - Meal type selector (Breakfast, Lunch, Dinner, Snacks, custom)
  - Amount: minus/plus buttons, TextField, quick chips (50g, 100g, 150g, 200g or 0.5×, 1×, 1.5×, 2×)
  - "Add to [meal]" button
- **Data needed:** `FoodItem` (name, calories, protein, carbs, fats, fiber, unit, amount)

#### 7. **Meal detail sheet** (`_MealDetailSheet`)
- **Elements:**
  - Meal type, total calories, macros
  - List of `_FoodListItem` (one per food)
  - Add Food button
  - Camera button (placeholder)
- **Per food item:**
  - Name, amount/unit, macros, calories
  - Long-press → edit amount dialog
  - Swipe-to-delete (Dismissible)
- **Data needed:** List of `FoodItem`, `onFoodDeleted`, `onFoodUpdated`

#### 8. **Weekly insights**
- **Location:** `WeeklyInsightsPage` (navigated from summary tap)
- **Elements:** Bar chart (7 days), metric selector, common/recent foods
- **Data needed:** Per-day totals for selected metric (calories, protein, carbs, fats) for 7 days

#### 9. **Meal photos**
- **Location:** `_mealPhotoPath` map, `onAddPhoto` on meal tile
- **Elements:** ImagePicker for meal photo (stored locally)
- **Data needed:** Optional – could store in `meal_media` if we wire it

---

### FoodItem Model (in meal_tracker_page_v2.dart)

```dart
class FoodItem {
  final String name;
  final int calories;      // per unit
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;
  final String unit;       // e.g. "100g", "1 medium"
  final double amount;     // grams or multiplier
  // Computed: totalCalories, totalProtein, totalCarbs, totalFats, totalFiber
}
```

- **No custom food creation** – user picks from `commonFoods` (hardcoded) or `recentFoods` (in-memory).
- **Search:** Client-side filter on `commonFoods` + `recentFoods`.

---

### Summary: UI Elements → Data Requirements

| UI Element | Data Needed |
|------------|-------------|
| Date picker / week strip | Selected date, week range |
| Daily summary (totals) | Aggregated calories, protein, carbs, fats, fiber for selected day |
| Edit goals | goalCalories, goalProtein, goalCarbs, goalFats, goalFiber (per user) |
| Meal tiles | Per-meal-type lists of FoodItems, per-day |
| Add food | FoodItem + meal type + amount |
| Edit food (amount) | Update FoodItem.amount |
| Delete food | Remove from meal |
| Meal detail sheet | Same as meal tiles (list of items) |
| Weekly insights | 7-day aggregates for selected metric |
| Add custom meal | New meal type name |
| Meal photos | Optional – local path or URL |

---

## Step 1 — Supabase Schema Discovery

### Existing Tables (from migrations)

#### `public.meals`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| user_id | UUID | FK → auth.users |
| meal_type | TEXT | breakfast, lunch, dinner, snack |
| consumed_at | TIMESTAMPTZ | When consumed |
| total_calories | NUMERIC(6,2) | Default 0 |
| total_protein | NUMERIC(6,2) | Default 0 |
| total_carbs | NUMERIC(6,2) | Default 0 |
| total_fat | NUMERIC(6,2) | Default 0 |
| notes | TEXT | Optional |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Indexes:** `idx_meals_user_id`, `idx_meals_consumed_at`

#### `public.meal_items`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| meal_id | UUID | FK → meals (CASCADE) |
| food_name | TEXT | |
| quantity | NUMERIC(6,2) | Maps to FoodItem.amount |
| unit | TEXT | e.g. "100g", "1 medium" |
| calories | NUMERIC(6,2) | Per-unit |
| protein | NUMERIC(6,2) | |
| carbs | NUMERIC(6,2) | |
| fat | NUMERIC(6,2) | Schema uses `fat`, UI uses `fats` |
| created_at | TIMESTAMPTZ | |

**Index:** `idx_meal_items_meal_id`

#### `public.meal_media`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| meal_id | UUID | FK → meals |
| media_url | TEXT | |
| media_kind | media_kind | enum (image/video) |
| created_at | TIMESTAMPTZ | |

---

### Schema vs UI Mapping

| UI Concept | Existing Schema | Gap |
|------------|-----------------|-----|
| Day | `consumed_at` (date part) | OK – group by date |
| Meal type | `meal_type` | OK – Breakfast, Lunch, Dinner, Snacks, custom |
| Food item | `meal_items` | **Missing `fiber`** in meal_items |
| Totals | `meals.total_*` or sum(meal_items) | Can compute from items |
| Goals | — | **No table** – need `user_goals` or similar |
| Custom meal | `meal_type` | OK – free text |

---

### Archive Migration (20250213_archive_unused_meal_tables.sql)

- Migration is **commented out** – tables are **not** archived.
- `meals`, `meal_items`, `meal_media` should still exist if earlier migrations ran.
- RLS policies exist: "Users can manage own meals", "Users can manage own meal items", "Users can manage own meal media".

---

### Proposed Additions (if tables exist)

1. **`meal_items.fiber`** – ADD COLUMN IF NOT EXISTS for fiber.
2. **User goals** – Either:
   - New table `nutrition_goals` (user_id, goal_calories, goal_protein, goal_carbs, goal_fats, goal_fiber), or
   - Store in `user_profiles` or `profiles` if columns exist.
3. **Index for day+user** – `(user_id, (consumed_at::date))` for efficient day fetches.

---

### If Tables Do NOT Exist

Create minimal schema:

```sql
-- meals: one row per meal session per day
CREATE TABLE meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  meal_type TEXT NOT NULL,
  consumed_at DATE NOT NULL,  -- or TIMESTAMPTZ, truncate to date
  total_calories NUMERIC(8,2) DEFAULT 0,
  total_protein NUMERIC(6,2) DEFAULT 0,
  total_carbs NUMERIC(6,2) DEFAULT 0,
  total_fats NUMERIC(6,2) DEFAULT 0,
  total_fiber NUMERIC(6,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- meal_items: individual food entries
CREATE TABLE meal_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id UUID NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
  food_name TEXT NOT NULL,
  quantity NUMERIC(8,2) NOT NULL,
  unit TEXT NOT NULL,
  calories NUMERIC(8,2) DEFAULT 0,
  protein NUMERIC(6,2) DEFAULT 0,
  carbs NUMERIC(6,2) DEFAULT 0,
  fat NUMERIC(6,2) DEFAULT 0,
  fiber NUMERIC(6,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- nutrition_goals: per-user daily targets
CREATE TABLE nutrition_goals (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_calories INT NOT NULL DEFAULT 2000,
  goal_protein INT NOT NULL DEFAULT 150,
  goal_carbs INT NOT NULL DEFAULT 200,
  goal_fats INT NOT NULL DEFAULT 65,
  goal_fiber INT NOT NULL DEFAULT 30,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Step 2 — Data Model Decision (Preview)

**Recommended: Model A — `meals` + `meal_items`** (align with existing schema)

- **meals:** One row per (user, date, meal_type). `consumed_at` can be `date` or `date + meal_type` for uniqueness.
- **meal_items:** One row per food in a meal. `quantity` = amount, `unit` = unit string.
- **nutrition_goals:** New table for user goals.

**Design choice:** One `meals` row per meal type per day (e.g. one Breakfast row per day). Simplifies:
- Fetch all meals for a day in one query.
- Aggregation per meal type.
- Add/update/delete items under that meal.

**Alternative:** One `meals` row per "meal session" (e.g. multiple Breakfast entries if user logs twice). Current UI assumes one Breakfast, one Lunch, etc. per day, so one row per (user, date, meal_type) fits.

---

## Next Steps (Step 2–5)

1. **Step 2:** Finalize data model (meals + meal_items + goals).
2. **Step 3:** Idempotent migration (ensure tables, add fiber, add goals, RLS, indexes).
3. **Step 4:** Implement `MealRepository` / `NutritionRepository`, wire all UI actions.
4. **Step 5:** Mapping table, test checklist, diffs.
