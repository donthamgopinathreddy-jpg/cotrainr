-- Nutrition Goal Planner — production-ready schema (idempotent).
-- Single table: one row per user (user_id PK). Flutter saves via upsert(onConflict: user_id).
-- Requires: auth.users. Reuses public.set_updated_at() if already defined in project.

-- =============================================================================
-- 0. updated_at trigger helper (shared; safe to replace)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- 1. Base table — one nutrition goal row per user
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.nutrition_goals (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Meal tracker daily targets
  goal_calories int NOT NULL DEFAULT 2000,
  goal_protein int NOT NULL DEFAULT 150,
  goal_carbs int NOT NULL DEFAULT 200,
  goal_fats int NOT NULL DEFAULT 65,
  goal_fiber int NOT NULL DEFAULT 30,
  goal_water_ml int,

  -- Planner inputs / metadata
  goal_type text,
  activity_level text,
  workout_days_per_week int,
  planner_age int,
  planner_gender text,
  planner_height_cm numeric,
  planner_weight_kg numeric,

  -- Weight goal & timeline (required for recalculation / progress)
  current_weight_kg numeric,
  target_weight_kg numeric,
  timeline_days int,
  timeline_weeks int,
  weekly_change_kg numeric,

  -- Calculation outputs
  maintenance_calories int,
  bmr int,
  formula_version text NOT NULL DEFAULT 'mifflin_st_jeor_v1',

  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 2. Add missing columns (upgrade path from older migrations)
-- =============================================================================
ALTER TABLE public.nutrition_goals
  ADD COLUMN IF NOT EXISTS goal_calories int,
  ADD COLUMN IF NOT EXISTS goal_protein int,
  ADD COLUMN IF NOT EXISTS goal_carbs int,
  ADD COLUMN IF NOT EXISTS goal_fats int,
  ADD COLUMN IF NOT EXISTS goal_fiber int,
  ADD COLUMN IF NOT EXISTS goal_water_ml int,
  ADD COLUMN IF NOT EXISTS goal_type text,
  ADD COLUMN IF NOT EXISTS activity_level text,
  ADD COLUMN IF NOT EXISTS workout_days_per_week int,
  ADD COLUMN IF NOT EXISTS planner_age int,
  ADD COLUMN IF NOT EXISTS planner_gender text,
  ADD COLUMN IF NOT EXISTS planner_height_cm numeric,
  ADD COLUMN IF NOT EXISTS planner_weight_kg numeric,
  ADD COLUMN IF NOT EXISTS current_weight_kg numeric,
  ADD COLUMN IF NOT EXISTS target_weight_kg numeric,
  ADD COLUMN IF NOT EXISTS timeline_days int,
  ADD COLUMN IF NOT EXISTS timeline_weeks int,
  ADD COLUMN IF NOT EXISTS weekly_change_kg numeric,
  ADD COLUMN IF NOT EXISTS maintenance_calories int,
  ADD COLUMN IF NOT EXISTS bmr int,
  ADD COLUMN IF NOT EXISTS formula_version text,
  ADD COLUMN IF NOT EXISTS is_active boolean,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- =============================================================================
-- 3. Backfill legacy NULL / invalid values (before NOT NULL + CHECK)
-- =============================================================================
UPDATE public.nutrition_goals
SET goal_calories = 2000
WHERE goal_calories IS NULL OR goal_calories <= 0;

UPDATE public.nutrition_goals
SET goal_protein = 150
WHERE goal_protein IS NULL OR goal_protein < 0;

UPDATE public.nutrition_goals
SET goal_carbs = 200
WHERE goal_carbs IS NULL OR goal_carbs < 0;

UPDATE public.nutrition_goals
SET goal_fats = 65
WHERE goal_fats IS NULL OR goal_fats < 0;

UPDATE public.nutrition_goals
SET goal_fiber = 30
WHERE goal_fiber IS NULL OR goal_fiber < 0;

UPDATE public.nutrition_goals
SET goal_water_ml = NULL
WHERE goal_water_ml IS NOT NULL AND goal_water_ml < 0;

UPDATE public.nutrition_goals
SET formula_version = 'mifflin_st_jeor_v1'
WHERE formula_version IS NULL;

UPDATE public.nutrition_goals
SET is_active = true
WHERE is_active IS NULL;

UPDATE public.nutrition_goals
SET created_at = COALESCE(created_at, updated_at, now())
WHERE created_at IS NULL;

UPDATE public.nutrition_goals
SET updated_at = COALESCE(updated_at, created_at, now())
WHERE updated_at IS NULL;

-- Planner numerics: clamp invalid stored values to NULL
UPDATE public.nutrition_goals SET planner_age = NULL
  WHERE planner_age IS NOT NULL AND (planner_age < 13 OR planner_age > 120);
UPDATE public.nutrition_goals SET workout_days_per_week = NULL
  WHERE workout_days_per_week IS NOT NULL
    AND (workout_days_per_week < 0 OR workout_days_per_week > 7);
UPDATE public.nutrition_goals SET planner_height_cm = NULL
  WHERE planner_height_cm IS NOT NULL AND planner_height_cm < 0;
UPDATE public.nutrition_goals SET planner_weight_kg = NULL
  WHERE planner_weight_kg IS NOT NULL AND planner_weight_kg < 0;
UPDATE public.nutrition_goals SET current_weight_kg = NULL
  WHERE current_weight_kg IS NOT NULL AND current_weight_kg < 0;
UPDATE public.nutrition_goals SET target_weight_kg = NULL
  WHERE target_weight_kg IS NOT NULL AND target_weight_kg < 0;
UPDATE public.nutrition_goals SET timeline_days = NULL
  WHERE timeline_days IS NOT NULL AND timeline_days <= 0;
UPDATE public.nutrition_goals SET timeline_weeks = NULL
  WHERE timeline_weeks IS NOT NULL AND timeline_weeks <= 0;
UPDATE public.nutrition_goals SET weekly_change_kg = NULL
  WHERE weekly_change_kg IS NOT NULL AND weekly_change_kg < 0;
UPDATE public.nutrition_goals SET maintenance_calories = NULL
  WHERE maintenance_calories IS NOT NULL AND maintenance_calories < 0;
UPDATE public.nutrition_goals SET bmr = NULL
  WHERE bmr IS NOT NULL AND bmr < 0;

-- =============================================================================
-- 4. Enforce column defaults and NOT NULL
-- =============================================================================
ALTER TABLE public.nutrition_goals
  ALTER COLUMN goal_calories SET DEFAULT 2000,
  ALTER COLUMN goal_protein SET DEFAULT 150,
  ALTER COLUMN goal_carbs SET DEFAULT 200,
  ALTER COLUMN goal_fats SET DEFAULT 65,
  ALTER COLUMN goal_fiber SET DEFAULT 30,
  ALTER COLUMN formula_version SET DEFAULT 'mifflin_st_jeor_v1',
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.nutrition_goals
  ALTER COLUMN goal_calories SET NOT NULL,
  ALTER COLUMN goal_protein SET NOT NULL,
  ALTER COLUMN goal_carbs SET NOT NULL,
  ALTER COLUMN goal_fats SET NOT NULL,
  ALTER COLUMN goal_fiber SET NOT NULL,
  ALTER COLUMN formula_version SET NOT NULL,
  ALTER COLUMN is_active SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN updated_at SET NOT NULL;

-- =============================================================================
-- 5. CHECK constraints (idempotent replace)
-- =============================================================================
ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_goal_calories_positive;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_goal_calories_positive
  CHECK (goal_calories > 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_goal_protein_non_negative;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_goal_protein_non_negative
  CHECK (goal_protein >= 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_goal_carbs_non_negative;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_goal_carbs_non_negative
  CHECK (goal_carbs >= 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_goal_fats_non_negative;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_goal_fats_non_negative
  CHECK (goal_fats >= 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_goal_fiber_non_negative;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_goal_fiber_non_negative
  CHECK (goal_fiber >= 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_goal_water_ml_valid;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_goal_water_ml_valid
  CHECK (goal_water_ml IS NULL OR goal_water_ml >= 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_timeline_days_non_negative;
ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_timeline_days_positive;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_timeline_days_positive
  CHECK (timeline_days IS NULL OR timeline_days > 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_timeline_weeks_non_negative;
ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_timeline_weeks_positive;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_timeline_weeks_positive
  CHECK (timeline_weeks IS NULL OR timeline_weeks > 0);

ALTER TABLE public.nutrition_goals DROP CONSTRAINT IF EXISTS nutrition_goals_planner_non_negative;
ALTER TABLE public.nutrition_goals ADD CONSTRAINT nutrition_goals_planner_non_negative
  CHECK (
    (planner_age IS NULL OR (planner_age >= 13 AND planner_age <= 120))
    AND (workout_days_per_week IS NULL OR (workout_days_per_week >= 0 AND workout_days_per_week <= 7))
    AND (planner_height_cm IS NULL OR planner_height_cm >= 0)
    AND (planner_weight_kg IS NULL OR planner_weight_kg >= 0)
    AND (current_weight_kg IS NULL OR current_weight_kg >= 0)
    AND (target_weight_kg IS NULL OR target_weight_kg >= 0)
    AND (weekly_change_kg IS NULL OR weekly_change_kg >= 0)
    AND (maintenance_calories IS NULL OR maintenance_calories >= 0)
    AND (bmr IS NULL OR bmr >= 0)
  );

-- =============================================================================
-- 6. Auto-update updated_at on row changes
-- =============================================================================
DROP TRIGGER IF EXISTS trg_nutrition_goals_updated_at ON public.nutrition_goals;
CREATE TRIGGER trg_nutrition_goals_updated_at
  BEFORE UPDATE ON public.nutrition_goals
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- 7. RLS — own row only
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

DROP POLICY IF EXISTS "Users can delete own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can delete own nutrition goals"
  ON public.nutrition_goals FOR DELETE
  USING (auth.uid() = user_id);

-- =============================================================================
-- 8. Documentation
-- =============================================================================
COMMENT ON TABLE public.nutrition_goals IS
  'One nutrition goal row per user (user_id PK). Flutter must save with upsert(onConflict: user_id). Meal tracker reads goal_*; planner stores weight timeline and formula outputs.';

COMMENT ON COLUMN public.nutrition_goals.formula_version IS
  'Calculator version e.g. mifflin_st_jeor_v1 — required for future formula migrations.';
