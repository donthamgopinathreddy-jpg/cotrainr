-- Nutrition Goal Planner v2 fields (extends existing nutrition_goals).

ALTER TABLE public.nutrition_goals
  ADD COLUMN IF NOT EXISTS current_weight_kg numeric,
  ADD COLUMN IF NOT EXISTS target_weight_kg numeric,
  ADD COLUMN IF NOT EXISTS timeline_weeks int,
  ADD COLUMN IF NOT EXISTS weekly_change_kg numeric,
  ADD COLUMN IF NOT EXISTS maintenance_calories int,
  ADD COLUMN IF NOT EXISTS bmr int,
  ADD COLUMN IF NOT EXISTS formula_version text NOT NULL DEFAULT 'mifflin_st_jeor_v1';
