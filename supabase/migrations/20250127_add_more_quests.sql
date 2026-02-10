-- =========================================
-- ADDITIONAL QUEST DEFINITIONS
-- Adds more variety to daily and weekly quests
-- =========================================

-- Insert additional quest definitions (idempotent)
-- Handle both TEXT and UUID id types
DO $$
DECLARE
  v_id_type TEXT;
BEGIN
  -- Check if quests table exists and what type the id column is
  SELECT data_type INTO v_id_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'quests'
    AND column_name = 'id';
  
  IF v_id_type = 'uuid' THEN
    -- If id is UUID, check if quests already exist by title to avoid duplicates
    INSERT INTO public.quests (id, title, description, category, difficulty, time_window, reward_xp, reward_points, requirements, cooldown_days, icon_name, icon_color, quest_type)
    SELECT gen_random_uuid(), '5K Steps', 'Hit 5,000 steps today', 'steps', 'easy', 'anytime', 30, 5, '{"target": 5000, "type": "steps"}'::jsonb, 1, 'directions_walk', '#FF9800', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '5K Steps')
    UNION ALL
    SELECT gen_random_uuid(), '12K Steps', 'Hit 12,000 steps today', 'steps', 'medium', 'anytime', 90, 18, '{"target": 12000, "type": "steps"}'::jsonb, 2, 'directions_walk', '#FF9800', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '12K Steps')
    UNION ALL
    SELECT gen_random_uuid(), '15K Steps', 'Hit 15,000 steps today', 'steps', 'hard', 'anytime', 120, 25, '{"target": 15000, "type": "steps"}'::jsonb, 3, 'directions_walk', '#FF9800', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '15K Steps')
    UNION ALL
    SELECT gen_random_uuid(), 'Walk 3KM', 'Walk 3 kilometers today', 'workout', 'easy', 'anytime', 50, 10, '{"target": 3.0, "type": "distance"}'::jsonb, 2, 'directions_walk', '#4CAF50', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Walk 3KM')
    UNION ALL
    SELECT gen_random_uuid(), 'Walk 5KM', 'Walk 5 kilometers today', 'workout', 'medium', 'anytime', 80, 16, '{"target": 5.0, "type": "distance"}'::jsonb, 2, 'directions_walk', '#4CAF50', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Walk 5KM')
    UNION ALL
    SELECT gen_random_uuid(), 'Burn 300 Calories', 'Burn 300 calories today', 'workout', 'medium', 'anytime', 70, 14, '{"target": 300, "type": "calories"}'::jsonb, 2, 'local_fire_department', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Burn 300 Calories')
    UNION ALL
    SELECT gen_random_uuid(), 'Burn 500 Calories', 'Burn 500 calories today', 'workout', 'hard', 'anytime', 100, 20, '{"target": 500, "type": "calories"}'::jsonb, 3, 'local_fire_department', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Burn 500 Calories')
    UNION ALL
    SELECT gen_random_uuid(), 'Hydration Level 1', 'Drink 1.5L water today', 'hydration', 'easy', 'anytime', 30, 6, '{"target": 1.5, "type": "water"}'::jsonb, 1, 'water_drop', '#2196F3', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Hydration Level 1')
    UNION ALL
    SELECT gen_random_uuid(), 'Hydration Level 2', 'Drink 2.5L water today', 'hydration', 'medium', 'anytime', 60, 12, '{"target": 2.5, "type": "water"}'::jsonb, 2, 'water_drop', '#2196F3', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Hydration Level 2')
    UNION ALL
    SELECT gen_random_uuid(), 'Hydration Master', 'Drink 3.0L water today', 'hydration', 'hard', 'anytime', 80, 16, '{"target": 3.0, "type": "water"}'::jsonb, 3, 'water_drop', '#2196F3', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Hydration Master')
    UNION ALL
    SELECT gen_random_uuid(), '30 Min Workout', 'Complete 30 min workout today', 'workout', 'medium', 'anytime', 80, 16, '{"target": 30, "type": "workout_minutes"}'::jsonb, 2, 'fitness_center', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '30 Min Workout')
    UNION ALL
    SELECT gen_random_uuid(), '45 Min Workout', 'Complete 45 min workout today', 'workout', 'hard', 'anytime', 110, 22, '{"target": 45, "type": "workout_minutes"}'::jsonb, 3, 'fitness_center', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '45 Min Workout')
    UNION ALL
    SELECT gen_random_uuid(), 'Log 3 Meals', 'Log 3 meals today', 'nutrition', 'easy', 'anytime', 50, 10, '{"target": 3, "type": "meals"}'::jsonb, 2, 'restaurant', '#4CAF50', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Log 3 Meals')
    UNION ALL
    SELECT gen_random_uuid(), 'Protein Champion', 'Hit 100g protein today', 'nutrition', 'hard', 'anytime', 80, 16, '{"target": 100, "type": "protein"}'::jsonb, 3, 'fitness_center', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Protein Champion')
    UNION ALL
    SELECT gen_random_uuid(), 'Evening Walker', 'Hit 3,000 steps after 6:00 PM', 'steps', 'medium', 'evening', 60, 12, '{"target": 3000, "type": "steps", "after": "18:00"}'::jsonb, 2, 'wb_twilight', '#9C27B0', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Evening Walker')
    UNION ALL
    SELECT gen_random_uuid(), 'Weekend Warrior', 'Hit 10K steps on weekend', 'steps', 'medium', 'anytime', 100, 20, '{"target": 10000, "type": "steps", "weekend_only": true}'::jsonb, 1, 'directions_walk', '#FF9800', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Weekend Warrior')
    UNION ALL
    SELECT gen_random_uuid(), '75K Steps Week', 'Total 75,000 steps this week', 'steps', 'hard', 'anytime', 350, 70, '{"target": 75000, "type": "steps", "period": "week"}'::jsonb, 0, 'directions_walk', '#FF9800', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '75K Steps Week')
    UNION ALL
    SELECT gen_random_uuid(), '100K Steps Week', 'Total 100,000 steps this week', 'steps', 'hard', 'anytime', 500, 100, '{"target": 100000, "type": "steps", "period": "week"}'::jsonb, 0, 'directions_walk', '#FF9800', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '100K Steps Week')
    UNION ALL
    SELECT gen_random_uuid(), 'Weekly Distance', 'Walk 25 kilometers this week', 'workout', 'medium', 'anytime', 300, 60, '{"target": 25.0, "type": "distance", "period": "week"}'::jsonb, 0, 'directions_walk', '#4CAF50', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Weekly Distance')
    UNION ALL
    SELECT gen_random_uuid(), 'Calorie Burner', 'Burn 2,000 calories this week', 'workout', 'medium', 'anytime', 280, 56, '{"target": 2000, "type": "calories", "period": "week"}'::jsonb, 0, 'local_fire_department', '#F44336', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Calorie Burner')
    UNION ALL
    SELECT gen_random_uuid(), 'Calorie Master', 'Burn 3,500 calories this week', 'workout', 'hard', 'anytime', 400, 80, '{"target": 3500, "type": "calories", "period": "week"}'::jsonb, 0, 'local_fire_department', '#F44336', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Calorie Master')
    UNION ALL
    SELECT gen_random_uuid(), 'Workout Warrior', 'Complete 5 workouts this week', 'workout', 'hard', 'anytime', 350, 70, '{"target": 5, "type": "workouts", "period": "week"}'::jsonb, 0, 'fitness_center', '#F44336', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Workout Warrior')
    UNION ALL
    SELECT gen_random_uuid(), 'Hydration Champion', 'Hit water goal 6 days this week', 'hydration', 'hard', 'anytime', 250, 50, '{"target": 6, "type": "water_goal_days", "period": "week"}'::jsonb, 0, 'water_drop', '#2196F3', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Hydration Champion')
    UNION ALL
    SELECT gen_random_uuid(), 'Meal Logger', 'Log meals 6 days this week', 'nutrition', 'medium', 'anytime', 250, 50, '{"target": 6, "type": "meals_days", "period": "week"}'::jsonb, 0, 'restaurant', '#4CAF50', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Meal Logger')
    UNION ALL
    SELECT gen_random_uuid(), '7-Day Streak', 'Maintain a 7-day streak', 'consistency', 'hard', 'anytime', 400, 80, '{"target": 7, "type": "streak_days", "period": "week"}'::jsonb, 0, 'local_fire_department', '#FF9800', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '7-Day Streak')
    UNION ALL
    SELECT gen_random_uuid(), 'Perfect Week', 'Complete all daily quests 7 days', 'consistency', 'hard', 'anytime', 500, 100, '{"target": 7, "type": "daily_quests_complete", "period": "week"}'::jsonb, 0, 'emoji_events', '#FFD700', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Perfect Week');
  ELSE
    -- If id is TEXT, use text identifiers
    INSERT INTO public.quests (id, title, description, category, difficulty, time_window, reward_xp, reward_points, requirements, cooldown_days, icon_name, icon_color, quest_type)
    VALUES
      -- Additional Daily Quests - Steps
      ('daily_steps_5k', '5K Steps', 'Hit 5,000 steps today', 'steps', 'easy', 'anytime', 30, 5, '{"target": 5000, "type": "steps"}'::jsonb, 1, 'directions_walk', '#FF9800', 'daily'),
      ('daily_steps_12k', '12K Steps', 'Hit 12,000 steps today', 'steps', 'medium', 'anytime', 90, 18, '{"target": 12000, "type": "steps"}'::jsonb, 2, 'directions_walk', '#FF9800', 'daily'),
      ('daily_steps_15k', '15K Steps', 'Hit 15,000 steps today', 'steps', 'hard', 'anytime', 120, 25, '{"target": 15000, "type": "steps"}'::jsonb, 3, 'directions_walk', '#FF9800', 'daily'),
      ('daily_steps_evening', 'Evening Walker', 'Hit 3,000 steps after 6:00 PM', 'steps', 'medium', 'evening', 60, 12, '{"target": 3000, "type": "steps", "after": "18:00"}'::jsonb, 2, 'wb_twilight', '#9C27B0', 'daily'),
      ('daily_steps_weekend', 'Weekend Warrior', 'Hit 10K steps on weekend', 'steps', 'medium', 'anytime', 100, 20, '{"target": 10000, "type": "steps", "weekend_only": true}'::jsonb, 1, 'directions_walk', '#FF9800', 'daily'),
      
      -- Additional Daily Quests - Workout (Distance & Calories)
      ('daily_distance_3km', 'Walk 3KM', 'Walk 3 kilometers today', 'workout', 'easy', 'anytime', 50, 10, '{"target": 3.0, "type": "distance"}'::jsonb, 2, 'directions_walk', '#4CAF50', 'daily'),
      ('daily_distance_5km', 'Walk 5KM', 'Walk 5 kilometers today', 'workout', 'medium', 'anytime', 80, 16, '{"target": 5.0, "type": "distance"}'::jsonb, 2, 'directions_walk', '#4CAF50', 'daily'),
      ('daily_calories_300', 'Burn 300 Calories', 'Burn 300 calories today', 'workout', 'medium', 'anytime', 70, 14, '{"target": 300, "type": "calories"}'::jsonb, 2, 'local_fire_department', '#F44336', 'daily'),
      ('daily_calories_500', 'Burn 500 Calories', 'Burn 500 calories today', 'workout', 'hard', 'anytime', 100, 20, '{"target": 500, "type": "calories"}'::jsonb, 3, 'local_fire_department', '#F44336', 'daily'),
      ('daily_workout_30min', '30 Min Workout', 'Complete 30 min workout today', 'workout', 'medium', 'anytime', 80, 16, '{"target": 30, "type": "workout_minutes"}'::jsonb, 2, 'fitness_center', '#F44336', 'daily'),
      ('daily_workout_45min', '45 Min Workout', 'Complete 45 min workout today', 'workout', 'hard', 'anytime', 110, 22, '{"target": 45, "type": "workout_minutes"}'::jsonb, 3, 'fitness_center', '#F44336', 'daily'),
      
      -- Additional Daily Quests - Hydration
      ('daily_water_1.5l', 'Hydration Level 1', 'Drink 1.5L water today', 'hydration', 'easy', 'anytime', 30, 6, '{"target": 1.5, "type": "water"}'::jsonb, 1, 'water_drop', '#2196F3', 'daily'),
      ('daily_water_2.5l', 'Hydration Level 2', 'Drink 2.5L water today', 'hydration', 'medium', 'anytime', 60, 12, '{"target": 2.5, "type": "water"}'::jsonb, 2, 'water_drop', '#2196F3', 'daily'),
      ('daily_water_3l', 'Hydration Master', 'Drink 3.0L water today', 'hydration', 'hard', 'anytime', 80, 16, '{"target": 3.0, "type": "water"}'::jsonb, 3, 'water_drop', '#2196F3', 'daily'),
      
      -- Additional Daily Quests - Nutrition
      ('daily_meals_3', 'Log 3 Meals', 'Log 3 meals today', 'nutrition', 'easy', 'anytime', 50, 10, '{"target": 3, "type": "meals"}'::jsonb, 2, 'restaurant', '#4CAF50', 'daily'),
      ('daily_protein_100g', 'Protein Champion', 'Hit 100g protein today', 'nutrition', 'hard', 'anytime', 80, 16, '{"target": 100, "type": "protein"}'::jsonb, 3, 'fitness_center', '#F44336', 'daily'),
      
      -- Additional Weekly Quests - Steps
      ('weekly_steps_75k', '75K Steps Week', 'Total 75,000 steps this week', 'steps', 'hard', 'anytime', 350, 70, '{"target": 75000, "type": "steps", "period": "week"}'::jsonb, 0, 'directions_walk', '#FF9800', 'weekly'),
      ('weekly_steps_100k', '100K Steps Week', 'Total 100,000 steps this week', 'steps', 'hard', 'anytime', 500, 100, '{"target": 100000, "type": "steps", "period": "week"}'::jsonb, 0, 'directions_walk', '#FF9800', 'weekly'),
      
      -- Additional Weekly Quests - Workout
      ('weekly_distance_25km', 'Weekly Distance', 'Walk 25 kilometers this week', 'workout', 'medium', 'anytime', 300, 60, '{"target": 25.0, "type": "distance", "period": "week"}'::jsonb, 0, 'directions_walk', '#4CAF50', 'weekly'),
      ('weekly_calories_2000', 'Calorie Burner', 'Burn 2,000 calories this week', 'workout', 'medium', 'anytime', 280, 56, '{"target": 2000, "type": "calories", "period": "week"}'::jsonb, 0, 'local_fire_department', '#F44336', 'weekly'),
      ('weekly_calories_3500', 'Calorie Master', 'Burn 3,500 calories this week', 'workout', 'hard', 'anytime', 400, 80, '{"target": 3500, "type": "calories", "period": "week"}'::jsonb, 0, 'local_fire_department', '#F44336', 'weekly'),
      ('weekly_workouts_5', 'Workout Warrior', 'Complete 5 workouts this week', 'workout', 'hard', 'anytime', 350, 70, '{"target": 5, "type": "workouts", "period": "week"}'::jsonb, 0, 'fitness_center', '#F44336', 'weekly'),
      
      -- Additional Weekly Quests - Hydration
      ('weekly_water_6days', 'Hydration Champion', 'Hit water goal 6 days this week', 'hydration', 'hard', 'anytime', 250, 50, '{"target": 6, "type": "water_goal_days", "period": "week"}'::jsonb, 0, 'water_drop', '#2196F3', 'weekly'),
      
      -- Additional Weekly Quests - Nutrition
      ('weekly_meals_6days', 'Meal Logger', 'Log meals 6 days this week', 'nutrition', 'medium', 'anytime', 250, 50, '{"target": 6, "type": "meals_days", "period": "week"}'::jsonb, 0, 'restaurant', '#4CAF50', 'weekly'),
      
      -- Additional Weekly Quests - Consistency
      ('weekly_streak_7days', '7-Day Streak', 'Maintain a 7-day streak', 'consistency', 'hard', 'anytime', 400, 80, '{"target": 7, "type": "streak_days", "period": "week"}'::jsonb, 0, 'local_fire_department', '#FF9800', 'weekly'),
      ('weekly_perfect_week', 'Perfect Week', 'Complete all daily quests 7 days', 'consistency', 'hard', 'anytime', 500, 100, '{"target": 7, "type": "daily_quests_complete", "period": "week"}'::jsonb, 0, 'emoji_events', '#FFD700', 'weekly')
    ON CONFLICT (id) DO NOTHING;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    -- If table doesn't exist or other error, skip seed data
    NULL;
END $$;
