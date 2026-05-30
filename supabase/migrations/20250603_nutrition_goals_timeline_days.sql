-- Timeline in days for Nutrition Goal Planner.

ALTER TABLE public.nutrition_goals
  ADD COLUMN IF NOT EXISTS timeline_days int;
