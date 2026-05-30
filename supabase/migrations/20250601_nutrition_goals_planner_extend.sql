-- Extend existing nutrition_goals for Nutrition Goal Planner (meal tracker compatible).
-- Keeps user_id as primary key (one active goal row per user via upsert).

ALTER TABLE public.nutrition_goals
  ADD COLUMN IF NOT EXISTS goal_water_ml int,
  ADD COLUMN IF NOT EXISTS goal_type text,
  ADD COLUMN IF NOT EXISTS activity_level text,
  ADD COLUMN IF NOT EXISTS workout_days_per_week int,
  ADD COLUMN IF NOT EXISTS planner_age int,
  ADD COLUMN IF NOT EXISTS planner_gender text,
  ADD COLUMN IF NOT EXISTS planner_height_cm numeric,
  ADD COLUMN IF NOT EXISTS planner_weight_kg numeric,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- Backfill created_at from updated_at where missing
UPDATE public.nutrition_goals
SET created_at = updated_at
WHERE created_at IS NULL;

DROP POLICY IF EXISTS "Users can delete own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can delete own nutrition goals"
  ON public.nutrition_goals FOR DELETE
  USING (auth.uid() = user_id);
