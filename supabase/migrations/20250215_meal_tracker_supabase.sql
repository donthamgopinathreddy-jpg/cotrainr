-- Meal Tracker Supabase Integration
-- Idempotent migration: fiber, nutrition_goals, consumed_date, uniqueness, dedupe, indexes, RLS
-- Day-bucketing: LOCAL-DAY. App sends consumed_date (user's selected calendar date). DB does NOT compute it.

-- =============================================================================
-- PREFLIGHT: Require meals and meal_items tables (strict for production)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.meals') IS NULL OR to_regclass('public.meal_items') IS NULL THEN
    RAISE EXCEPTION 'Meal Tracker migration requires public.meals and public.meal_items. Run base schema migrations first.';
  END IF;
END $$;

-- =============================================================================
-- 1. Add fiber to meal_items
-- =============================================================================
ALTER TABLE public.meal_items
  ADD COLUMN IF NOT EXISTS fiber numeric(6,2) NOT NULL DEFAULT 0;

-- =============================================================================
-- 2. Create nutrition_goals table
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.nutrition_goals (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_calories int NOT NULL DEFAULT 2000,
  goal_protein int NOT NULL DEFAULT 150,
  goal_carbs int NOT NULL DEFAULT 200,
  goal_fats int NOT NULL DEFAULT 65,
  goal_fiber int NOT NULL DEFAULT 30,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 3. Add consumed_date to meals (stored, for day uniqueness)
-- LOCAL-DAY: App sends consumed_date (user's selected calendar date). DB does NOT compute it.
--
-- Backfill strategy: NONE. profiles.timezone is not available. Backfilling from UTC would
-- put old meals on wrong days relative to the UI (local-day). Existing rows keep
-- consumed_date NULL and will NOT appear in day-based queries. New rows from the app
-- will have consumed_date set. If you have production data and need backfill, add
-- profiles.timezone first, then backfill with:
--   (consumed_at AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date
-- =============================================================================
ALTER TABLE public.meals
  ADD COLUMN IF NOT EXISTS consumed_date date;

-- No backfill: leave consumed_date NULL for existing rows (LOCAL-DAY consistency).
-- No DEFAULT: app must always send consumed_date.
DO $$
BEGIN
  ALTER TABLE public.meals ALTER COLUMN consumed_date DROP DEFAULT;
EXCEPTION
  WHEN others THEN NULL;  -- No default exists, or column not present
END $$;

-- consumed_date stays nullable (existing rows have NULL; app sends it for new rows).

-- =============================================================================
-- 4. Safe dedupe: keep earliest row per (user_id, consumed_date, meal_type)
-- meal_media update guarded: table may not exist (to_regclass check)
-- =============================================================================
DO $$
DECLARE
  dup_group record;
  keeper_id uuid;
  dup_id uuid;
  i int;
BEGIN
  FOR dup_group IN
    SELECT user_id, consumed_date, meal_type, array_agg(id ORDER BY consumed_at ASC, id ASC) as ids
    FROM public.meals
    WHERE consumed_date IS NOT NULL
    GROUP BY user_id, consumed_date, meal_type
    HAVING count(*) > 1
  LOOP
    keeper_id := dup_group.ids[1];
    FOR i IN 2..array_length(dup_group.ids, 1) LOOP
      dup_id := dup_group.ids[i];
      UPDATE public.meal_items SET meal_id = keeper_id WHERE meal_id = dup_id;
      IF to_regclass('public.meal_media') IS NOT NULL THEN
        UPDATE public.meal_media SET meal_id = keeper_id WHERE meal_id = dup_id;
      END IF;
      DELETE FROM public.meals WHERE id = dup_id;
    END LOOP;
  END LOOP;
END $$;

-- =============================================================================
-- 5. Add unique index (user_id, consumed_date, meal_type)
-- Partial: only for rows with consumed_date (app-created). Legacy NULL rows unconstrained.
-- Schema-qualified drops; IF NOT EXISTS for create.
-- =============================================================================
ALTER TABLE public.meals
  DROP CONSTRAINT IF EXISTS uq_meals_user_date_meal_type;

DROP INDEX IF EXISTS public.uq_meals_user_date_meal_type;

CREATE UNIQUE INDEX IF NOT EXISTS uq_meals_user_date_meal_type
  ON public.meals (user_id, consumed_date, meal_type)
  WHERE consumed_date IS NOT NULL;

-- =============================================================================
-- 6. Indexes for fetch performance
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_meals_user_consumed_date
  ON public.meals (user_id, consumed_date);

CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id
  ON public.meal_items (meal_id);

-- =============================================================================
-- 7. RLS for nutrition_goals
-- =============================================================================
ALTER TABLE public.nutrition_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can select own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can select own nutrition goals"
  ON public.nutrition_goals FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can insert own nutrition goals"
  ON public.nutrition_goals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can update own nutrition goals"
  ON public.nutrition_goals FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- 8. No trigger: LOCAL-DAY strategy. App always sends consumed_date.
-- Drop trigger if it was created by an earlier run.
-- =============================================================================
DROP TRIGGER IF EXISTS trg_meals_set_consumed_date ON public.meals;

-- =============================================================================
-- VERIFICATION SNIPPETS (run manually to confirm migration state)
-- =============================================================================
-- Verify partial unique index exists:
--   SELECT indexname, indexdef FROM pg_indexes WHERE indexname = 'uq_meals_user_date_meal_type';
--
-- Verify consumed_date is nullable:
--   SELECT column_name, is_nullable FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'consumed_date';
--
-- Verify nutrition_goals RLS enabled:
--   SELECT relname, relrowsecurity FROM pg_class
--   WHERE relname = 'nutrition_goals' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
