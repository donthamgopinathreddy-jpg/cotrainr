-- =========================================
-- DYNAMIC QUEST SYSTEM WITH LEVEL SCALING
-- =========================================
-- This migration adds:
-- 1. Dynamic quest generation based on user level
-- 2. Exponential XP requirements for levels
-- 3. Auto-generation of new quests when old ones are completed
-- 4. Quest difficulty scaling with user level
-- =========================================

-- =========================================
-- STEP 0: ADD REQUIREMENTS COLUMN TO USER_QUESTS
-- =========================================

-- Add requirements column to store dynamic quest metadata
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'user_quests' 
    AND column_name = 'requirements'
  ) THEN
    ALTER TABLE public.user_quests 
    ADD COLUMN requirements JSONB DEFAULT '{}'::jsonb;
  END IF;
  
  -- Make quest_definition_id nullable for dynamic quests
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'user_quests' 
    AND column_name = 'quest_definition_id'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.user_quests 
    ALTER COLUMN quest_definition_id DROP NOT NULL;
  END IF;
END $$;

-- =========================================
-- STEP 1: UPDATE LEVEL CALCULATION FUNCTION
-- =========================================

-- Function to calculate XP required for a level (exponential growth)
CREATE OR REPLACE FUNCTION public.calculate_level_xp(p_level INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_base_xp INTEGER := 100;
  v_multiplier NUMERIC := 1.15; -- 15% increase per level
  v_xp INTEGER;
BEGIN
  IF p_level <= 1 THEN
    RETURN 0;
  END IF;
  
  -- Exponential formula: base * (multiplier ^ (level - 1))
  -- Level 1: 0 XP
  -- Level 2: 100 XP
  -- Level 3: 115 XP (100 * 1.15)
  -- Level 4: 132 XP (115 * 1.15)
  -- Level 5: 152 XP (132 * 1.15)
  -- etc.
  
  v_xp := FLOOR(v_base_xp * POWER(v_multiplier, p_level - 2));
  
  -- Cap at 5000 XP per level for very high levels
  RETURN LEAST(v_xp, 5000);
END;
$$;

-- Function to calculate current level from total XP
CREATE OR REPLACE FUNCTION public.calculate_level_from_xp(p_total_xp INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_level INTEGER := 1;
  v_required_xp INTEGER := 0;
  v_accumulated_xp INTEGER := 0;
BEGIN
  -- Start from level 1
  LOOP
    v_level := v_level + 1;
    v_required_xp := public.calculate_level_xp(v_level);
    
    -- If we don't have enough XP for this level, return previous level
    IF v_accumulated_xp + v_required_xp > p_total_xp THEN
      RETURN v_level - 1;
    END IF;
    
    v_accumulated_xp := v_accumulated_xp + v_required_xp;
    
    -- Safety: max level 100
    IF v_level >= 100 THEN
      RETURN 100;
    END IF;
  END LOOP;
END;
$$;

-- Function to get XP needed for next level
CREATE OR REPLACE FUNCTION public.get_xp_for_next_level(p_current_level INTEGER, p_total_xp INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_next_level INTEGER;
  v_next_level_xp INTEGER;
  v_accumulated_xp INTEGER := 0;
  v_level INTEGER;
  v_required_xp INTEGER;
BEGIN
  v_next_level := p_current_level + 1;
  v_next_level_xp := public.calculate_level_xp(v_next_level);
  
  -- Calculate accumulated XP up to current level
  FOR v_level IN 2..p_current_level LOOP
    v_required_xp := public.calculate_level_xp(v_level);
    v_accumulated_xp := v_accumulated_xp + v_required_xp;
  END LOOP;
  
  -- Return XP needed to reach next level
  RETURN (v_accumulated_xp + v_next_level_xp) - p_total_xp;
END;
$$;

-- =========================================
-- STEP 2: DYNAMIC QUEST GENERATION FUNCTION
-- =========================================

-- Function to generate a dynamic quest based on user level and category
CREATE OR REPLACE FUNCTION public.generate_dynamic_quest(
  p_user_id UUID,
  p_category TEXT,
  p_quest_type TEXT DEFAULT 'daily'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_level INTEGER;
  v_user_xp INTEGER;
  v_difficulty TEXT;
  v_base_target NUMERIC;
  v_scaled_target NUMERIC;
  v_reward_xp INTEGER;
  v_reward_points INTEGER;
  v_title TEXT;
  v_description TEXT;
  v_icon_name TEXT;
  v_icon_color TEXT;
  v_requirements JSONB;
  v_quest_id UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Get user level and XP (create profile if doesn't exist)
  SELECT COALESCE(level, 1), COALESCE(total_xp, 0)
  INTO v_user_level, v_user_xp
  FROM public.user_profiles
  WHERE user_id = p_user_id;
  
  -- If no profile exists, create one with default values
  IF v_user_level IS NULL THEN
    INSERT INTO public.user_profiles (user_id, level, total_xp)
    VALUES (p_user_id, 1, 0)
    ON CONFLICT (user_id) DO NOTHING;
    v_user_level := 1;
    v_user_xp := 0;
  END IF;
  
  -- Determine difficulty based on level
  IF v_user_level <= 5 THEN
    v_difficulty := 'easy';
  ELSIF v_user_level <= 15 THEN
    v_difficulty := 'medium';
  ELSIF v_user_level <= 30 THEN
    v_difficulty := 'hard';
  ELSE
    v_difficulty := 'hard'; -- All high levels get hard
  END IF;
  
  -- Generate quest based on category
  CASE p_category
    WHEN 'steps' THEN
      -- Base targets: Daily 5K/10K/15K, Weekly 35K/70K/105K (7x daily)
      IF p_quest_type = 'weekly' THEN
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 35000
          WHEN 'medium' THEN 70000
          ELSE 105000
        END;
        -- Scale with level: +3500 steps per 5 levels (7x daily scaling)
        v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 3500);
        v_scaled_target := LEAST(v_scaled_target, 210000); -- Cap at 210K
      ELSE
        -- Daily quests
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 5000
          WHEN 'medium' THEN 10000
          ELSE 15000
        END;
        -- Scale with level: +500 steps per 5 levels
        v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 500);
        v_scaled_target := LEAST(v_scaled_target, 30000); -- Cap at 30K
      END IF;
      
      IF p_quest_type = 'weekly' THEN
        v_title := FLOOR(v_scaled_target / 1000) || 'K Steps';
        v_description := 'Hit ' || FLOOR(v_scaled_target) || ' steps this week';
      ELSE
        v_title := FLOOR(v_scaled_target / 1000) || 'K Steps';
        v_description := 'Hit ' || FLOOR(v_scaled_target) || ' steps today';
      END IF;
      v_icon_name := 'directions_walk';
      v_icon_color := '#FF9800';
      v_requirements := jsonb_build_object(
        'target', v_scaled_target,
        'type', 'steps'
      );
      
      -- Reward: Daily 30-150 XP, Weekly 210-1050 XP (7x daily)
      IF p_quest_type = 'weekly' THEN
        v_reward_xp := CASE v_difficulty
          WHEN 'easy' THEN 210 + (v_user_level * 14)
          WHEN 'medium' THEN 420 + (v_user_level * 21)
          ELSE 630 + (v_user_level * 28)
        END;
      ELSE
        v_reward_xp := CASE v_difficulty
          WHEN 'easy' THEN 30 + (v_user_level * 2)
          WHEN 'medium' THEN 60 + (v_user_level * 3)
          ELSE 90 + (v_user_level * 4)
        END;
      END IF;
      v_reward_points := FLOOR(v_reward_xp * 0.2);
      
    WHEN 'workout' THEN
      -- Distance or calories based on level
      IF v_user_level % 2 = 0 THEN
        -- Distance quest
        IF p_quest_type = 'weekly' THEN
          v_base_target := CASE v_difficulty
            WHEN 'easy' THEN 14.0
            WHEN 'medium' THEN 35.0
            ELSE 56.0
          END;
          v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 7.0);
          v_scaled_target := LEAST(v_scaled_target, 140.0);
          v_title := 'Walk ' || v_scaled_target || 'KM';
          v_description := 'Walk ' || v_scaled_target || ' kilometers this week';
        ELSE
          v_base_target := CASE v_difficulty
            WHEN 'easy' THEN 2.0
            WHEN 'medium' THEN 5.0
            ELSE 8.0
          END;
          v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 1.0);
          v_scaled_target := LEAST(v_scaled_target, 20.0);
          v_title := 'Walk ' || v_scaled_target || 'KM';
          v_description := 'Walk ' || v_scaled_target || ' kilometers today';
        END IF;
        v_requirements := jsonb_build_object(
          'target', v_scaled_target,
          'type', 'distance'
        );
      ELSE
        -- Calories quest
        IF p_quest_type = 'weekly' THEN
          v_base_target := CASE v_difficulty
            WHEN 'easy' THEN 1400
            WHEN 'medium' THEN 2800
            ELSE 4200
          END;
          v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 350);
          v_scaled_target := LEAST(v_scaled_target, 7000);
          v_title := 'Burn ' || FLOOR(v_scaled_target) || ' Calories';
          v_description := 'Burn ' || FLOOR(v_scaled_target) || ' calories this week';
        ELSE
          v_base_target := CASE v_difficulty
            WHEN 'easy' THEN 200
            WHEN 'medium' THEN 400
            ELSE 600
          END;
          v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 50);
          v_scaled_target := LEAST(v_scaled_target, 1000);
          v_title := 'Burn ' || FLOOR(v_scaled_target) || ' Calories';
          v_description := 'Burn ' || FLOOR(v_scaled_target) || ' calories today';
        END IF;
        v_requirements := jsonb_build_object(
          'target', v_scaled_target,
          'type', 'calories'
        );
      END IF;
      
      v_icon_name := 'fitness_center';
      v_icon_color := '#F44336';
      -- Reward: Daily 50-120 XP, Weekly 350-840 XP (7x daily)
      IF p_quest_type = 'weekly' THEN
        v_reward_xp := CASE v_difficulty
          WHEN 'easy' THEN 350 + (v_user_level * 14)
          WHEN 'medium' THEN 560 + (v_user_level * 21)
          ELSE 840 + (v_user_level * 28)
        END;
      ELSE
        v_reward_xp := CASE v_difficulty
          WHEN 'easy' THEN 50 + (v_user_level * 2)
          WHEN 'medium' THEN 80 + (v_user_level * 3)
          ELSE 120 + (v_user_level * 4)
        END;
      END IF;
      v_reward_points := FLOOR(v_reward_xp * 0.2);
      
    WHEN 'hydration' THEN
      IF p_quest_type = 'weekly' THEN
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 10.5
          WHEN 'medium' THEN 17.5
          ELSE 24.5
        END;
        v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 10) * 3.5);
        v_scaled_target := LEAST(v_scaled_target, 35.0);
        v_title := 'Drink ' || v_scaled_target || 'L Water';
        v_description := 'Drink ' || v_scaled_target || ' liters of water this week';
      ELSE
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 1.5
          WHEN 'medium' THEN 2.5
          ELSE 3.5
        END;
        v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 10) * 0.5);
        v_scaled_target := LEAST(v_scaled_target, 5.0);
        v_title := 'Drink ' || v_scaled_target || 'L Water';
        v_description := 'Drink ' || v_scaled_target || ' liters of water today';
      END IF;
      v_icon_name := 'water_drop';
      v_icon_color := '#2196F3';
      v_requirements := jsonb_build_object(
        'target', v_scaled_target,
        'type', 'water'
      );
      
      -- Reward: Daily 30-70 XP, Weekly 210-490 XP (7x daily)
      IF p_quest_type = 'weekly' THEN
        v_reward_xp := CASE v_difficulty
          WHEN 'easy' THEN 210 + (v_user_level * 7)
          WHEN 'medium' THEN 350 + (v_user_level * 14)
          ELSE 490 + (v_user_level * 21)
        END;
      ELSE
        v_reward_xp := CASE v_difficulty
          WHEN 'easy' THEN 30 + (v_user_level * 1)
          WHEN 'medium' THEN 50 + (v_user_level * 2)
          ELSE 70 + (v_user_level * 3)
        END;
      END IF;
      v_reward_points := FLOOR(v_reward_xp * 0.2);
      
    WHEN 'nutrition' THEN
      IF v_user_level % 2 = 0 THEN
        -- Meal logging quest
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 2
          WHEN 'medium' THEN 3
          ELSE 4
        END;
        v_title := 'Log ' || FLOOR(v_base_target) || ' Meals';
        v_description := 'Log ' || FLOOR(v_base_target) || ' meals today';
        v_requirements := jsonb_build_object(
          'target', v_base_target,
          'type', 'meals'
        );
      ELSE
        -- Protein quest
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 60
          WHEN 'medium' THEN 80
          ELSE 100
        END;
        v_base_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 10);
        v_base_target := LEAST(v_base_target, 150);
        
        v_title := 'Hit ' || FLOOR(v_base_target) || 'g Protein';
        v_description := 'Hit ' || FLOOR(v_base_target) || 'g protein today';
        v_requirements := jsonb_build_object(
          'target', v_base_target,
          'type', 'protein'
        );
      END IF;
      
      v_icon_name := 'restaurant';
      v_icon_color := '#4CAF50';
      v_reward_xp := CASE v_difficulty
        WHEN 'easy' THEN 40 + (v_user_level * 2)
        WHEN 'medium' THEN 60 + (v_user_level * 3)
        ELSE 80 + (v_user_level * 4)
      END;
      v_reward_points := FLOOR(v_reward_xp * 0.2);
      
    ELSE
      -- Default: consistency quest
      v_title := 'Daily Check-in';
      v_description := 'Open Cotrainr and log 1 metric';
      v_icon_name := 'check_circle';
      v_icon_color := '#9C27B0';
      v_requirements := jsonb_build_object(
        'target', 1,
        'type', 'log_metric'
      );
      v_reward_xp := 20 + (v_user_level * 1);
      v_reward_points := FLOOR(v_reward_xp * 0.25);
  END CASE;
  
  -- Set expiration
  IF p_quest_type = 'daily' THEN
    v_expires_at := (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMPTZ;
  ELSE
    v_expires_at := (DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '1 week')::TIMESTAMPTZ;
  END IF;
  
  -- Create quest instance with requirements including metadata
  INSERT INTO public.user_quests (
    user_id,
    quest_definition_id, -- NULL for dynamic quests
    type,
    category,
    difficulty,
    status,
    progress_current,
    progress_target,
    reward_xp,
    reward_coins,
    assigned_at,
    expires_at,
    requirements
  ) VALUES (
    p_user_id,
    NULL, -- Dynamic quests don't reference quest definitions
    p_quest_type,
    p_category,
    v_difficulty,
    'available',
    0,
    v_scaled_target,
    v_reward_xp,
    v_reward_points,
    NOW(),
    v_expires_at,
    v_requirements || jsonb_build_object(
      'title', v_title,
      'description', v_description,
      'icon_name', v_icon_name,
      'icon_color', v_icon_color
    )
  )
  RETURNING id INTO v_quest_id;
  
  RETURN v_quest_id;
END;
$$;

-- =========================================
-- STEP 3: UPDATE ALLOCATE DAILY QUESTS FUNCTION
-- =========================================

-- Drop old function first (it has different return type)
DROP FUNCTION IF EXISTS public.allocate_daily_quests(UUID);

-- Enhanced function that generates dynamic quests
CREATE OR REPLACE FUNCTION public.allocate_daily_quests(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_existing_count INTEGER;
  v_user_level INTEGER;
  v_quest_id UUID;
  v_categories TEXT[] := ARRAY['steps', 'workout', 'hydration', 'nutrition', 'consistency'];
  v_selected_category TEXT;
  v_quests_created INTEGER := 0;
  v_attempts INTEGER := 0;
  v_max_attempts INTEGER := 50;
BEGIN
  -- Check if already allocated today
  SELECT COUNT(*) INTO v_existing_count
  FROM public.user_quests
  WHERE user_id = p_user_id
    AND type = 'daily'
    AND DATE(assigned_at) = v_today
    AND status IN ('available', 'in_progress', 'completed');
  
  IF v_existing_count >= 5 THEN
    RETURN 0; -- Already have 5 quests today
  END IF;
  
  -- Get user level (create profile if doesn't exist)
  SELECT COALESCE(level, 1) INTO v_user_level
  FROM public.user_profiles
  WHERE user_id = p_user_id;
  
  -- If no profile exists, create one with default values
  IF v_user_level IS NULL THEN
    INSERT INTO public.user_profiles (user_id, level, total_xp)
    VALUES (p_user_id, 1, 0)
    ON CONFLICT (user_id) DO NOTHING;
    v_user_level := 1;
  END IF;
  
  -- Generate dynamic quests to fill up to 5
  WHILE v_quests_created < (5 - v_existing_count) AND v_attempts < v_max_attempts LOOP
    v_attempts := v_attempts + 1;
    
    -- Pick a random category
    v_selected_category := v_categories[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_categories, 1))::INTEGER];
    
    -- Check if we already have a quest in this category today
    IF NOT EXISTS (
      SELECT 1 FROM public.user_quests
      WHERE user_id = p_user_id
        AND type = 'daily'
        AND DATE(assigned_at) = v_today
        AND category = v_selected_category
    ) THEN
      -- Generate dynamic quest
      BEGIN
        v_quest_id := public.generate_dynamic_quest(p_user_id, v_selected_category, 'daily');
        v_quests_created := v_quests_created + 1;
      EXCEPTION WHEN OTHERS THEN
        -- Log error but continue
        RAISE WARNING 'Error generating quest for category %: %', v_selected_category, SQLERRM;
      END;
    END IF;
  END LOOP;
  
  -- Update last refresh
  INSERT INTO public.user_quest_settings (user_id, last_daily_refresh)
  VALUES (p_user_id, NOW())
  ON CONFLICT (user_id) DO UPDATE SET last_daily_refresh = NOW();
  
  RETURN v_quests_created;
END;
$$;

-- =========================================
-- STEP 3.5: UPDATE ALLOCATE WEEKLY QUESTS FUNCTION
-- =========================================

-- Drop old function first (it has different return type)
DROP FUNCTION IF EXISTS public.allocate_weekly_quests(UUID);

-- Enhanced function that generates dynamic weekly quests
CREATE OR REPLACE FUNCTION public.allocate_weekly_quests(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_week_start DATE := DATE_TRUNC('week', CURRENT_DATE)::DATE;
  v_existing_count INTEGER;
  v_user_level INTEGER;
  v_quest_id UUID;
  v_categories TEXT[] := ARRAY['steps', 'workout', 'hydration', 'nutrition', 'consistency'];
  v_selected_category TEXT;
  v_quests_created INTEGER := 0;
  v_attempts INTEGER := 0;
  v_max_attempts INTEGER := 50;
BEGIN
  -- Check if already allocated this week
  SELECT COUNT(*) INTO v_existing_count
  FROM public.user_quests
  WHERE user_id = p_user_id
    AND type = 'weekly'
    AND assigned_at >= v_week_start::TIMESTAMPTZ
    AND status IN ('available', 'in_progress', 'completed');
  
  IF v_existing_count >= 4 THEN
    RETURN 0; -- Already have 4 weekly quests this week
  END IF;
  
  -- Get user level (create profile if doesn't exist)
  SELECT COALESCE(level, 1) INTO v_user_level
  FROM public.user_profiles
  WHERE user_id = p_user_id;
  
  -- If no profile exists, create one with default values
  IF v_user_level IS NULL THEN
    INSERT INTO public.user_profiles (user_id, level, total_xp)
    VALUES (p_user_id, 1, 0)
    ON CONFLICT (user_id) DO NOTHING;
    v_user_level := 1;
  END IF;
  
  -- Generate dynamic weekly quests to fill up to 4
  WHILE v_quests_created < (4 - v_existing_count) AND v_attempts < v_max_attempts LOOP
    v_attempts := v_attempts + 1;
    
    -- Pick a random category
    v_selected_category := v_categories[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_categories, 1))::INTEGER];
    
    -- Check if we already have a quest in this category this week
    IF NOT EXISTS (
      SELECT 1 FROM public.user_quests
      WHERE user_id = p_user_id
        AND type = 'weekly'
        AND assigned_at >= v_week_start::TIMESTAMPTZ
        AND category = v_selected_category
    ) THEN
      -- Generate dynamic quest
      BEGIN
        v_quest_id := public.generate_dynamic_quest(p_user_id, v_selected_category, 'weekly');
        v_quests_created := v_quests_created + 1;
      EXCEPTION WHEN OTHERS THEN
        -- Log error but continue
        RAISE WARNING 'Error generating weekly quest for category %: %', v_selected_category, SQLERRM;
      END;
    END IF;
  END LOOP;
  
  -- Update last refresh
  INSERT INTO public.user_quest_settings (user_id, last_weekly_refresh)
  VALUES (p_user_id, NOW())
  ON CONFLICT (user_id) DO UPDATE SET last_weekly_refresh = NOW();
  
  RETURN v_quests_created;
END;
$$;

-- =========================================
-- STEP 4: AUTO-GENERATE QUEST ON COMPLETION
-- =========================================

-- Function to auto-generate new quest when one is completed
CREATE OR REPLACE FUNCTION public.auto_generate_quest_on_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_quest_type TEXT;
  v_quest_category TEXT;
  v_today DATE;
  v_daily_count INTEGER;
  v_new_quest_id UUID;
  v_categories TEXT[] := ARRAY['steps', 'workout', 'hydration', 'nutrition', 'consistency'];
  v_selected_category TEXT;
BEGIN
  -- Only trigger on status change to 'claimed'
  IF NEW.status = 'claimed' AND (OLD.status IS NULL OR OLD.status != 'claimed') THEN
    v_user_id := NEW.user_id;
    v_quest_type := NEW.type;
    v_quest_category := NEW.category;
    v_today := CURRENT_DATE;
    
    -- Only for daily quests
    IF v_quest_type = 'daily' THEN
      -- Count current daily quests
      SELECT COUNT(*) INTO v_daily_count
      FROM public.user_quests
      WHERE user_id = v_user_id
        AND type = 'daily'
        AND DATE(assigned_at) = v_today
        AND status IN ('available', 'in_progress', 'completed');
      
      -- If less than 5, generate a new one
      IF v_daily_count < 5 THEN
        -- Pick a different category if possible
        SELECT category INTO v_selected_category
        FROM (
          SELECT unnest(v_categories) AS category
          EXCEPT
          SELECT category FROM public.user_quests
          WHERE user_id = v_user_id
            AND type = 'daily'
            AND DATE(assigned_at) = v_today
            AND status IN ('available', 'in_progress', 'completed')
        ) available_categories
        ORDER BY RANDOM()
        LIMIT 1;
        
        -- If all categories used, pick random
        IF v_selected_category IS NULL THEN
          v_selected_category := v_categories[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_categories, 1))::INTEGER];
        END IF;
        
        -- Generate new quest
        v_new_quest_id := public.generate_dynamic_quest(v_user_id, v_selected_category, 'daily');
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for auto-generation
DROP TRIGGER IF EXISTS trg_auto_generate_quest ON public.user_quests;
CREATE TRIGGER trg_auto_generate_quest
  AFTER UPDATE OF status ON public.user_quests
  FOR EACH ROW
  WHEN (NEW.status = 'claimed' AND (OLD.status IS NULL OR OLD.status != 'claimed'))
  EXECUTE FUNCTION public.auto_generate_quest_on_completion();

-- =========================================
-- STEP 5: UPDATE CLAIM QUEST REWARDS FUNCTION
-- =========================================

-- Drop old function first (it has different return type)
DROP FUNCTION IF EXISTS public.claim_quest_rewards(UUID);

-- Enhanced claim function that updates level
CREATE OR REPLACE FUNCTION public.claim_quest_rewards(p_quest_instance_id UUID)
RETURNS TABLE(
  xp_awarded INTEGER,
  coins_awarded INTEGER,
  new_total_xp INTEGER,
  new_level INTEGER,
  level_up BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_quest_xp INTEGER;
  v_quest_coins INTEGER;
  v_current_xp INTEGER;
  v_current_level INTEGER;
  v_new_xp INTEGER;
  v_new_level INTEGER;
  v_level_up BOOLEAN := false;
BEGIN
  -- Get quest info
  SELECT user_id, reward_xp, reward_coins
  INTO v_user_id, v_quest_xp, v_quest_coins
  FROM public.user_quests
  WHERE id = p_quest_instance_id
    AND status = 'completed';
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Quest not found or not completed';
  END IF;
  
  -- Get current XP and level
  SELECT COALESCE(total_xp, 0), COALESCE(level, 1)
  INTO v_current_xp, v_current_level
  FROM public.user_profiles
  WHERE user_id = v_user_id;
  
  -- Calculate new XP
  v_new_xp := v_current_xp + v_quest_xp;
  
  -- Calculate new level
  v_new_level := public.calculate_level_from_xp(v_new_xp);
  
  -- Check if leveled up
  IF v_new_level > v_current_level THEN
    v_level_up := true;
  END IF;
  
  -- Update user profile
  UPDATE public.user_profiles
  SET 
    total_xp = v_new_xp,
    level = v_new_level,
    updated_at = NOW()
  WHERE user_id = v_user_id;
  
  -- Mark quest as claimed
  UPDATE public.user_quests
  SET status = 'claimed', claimed_at = NOW()
  WHERE id = p_quest_instance_id;
  
  -- Award leaderboard points
  INSERT INTO public.leaderboard_points (user_id, period_type, period_start, points)
  VALUES (
    v_user_id,
    'daily',
    CURRENT_DATE,
    v_quest_coins
  )
  ON CONFLICT (user_id, period_type, period_start)
  DO UPDATE SET points = leaderboard_points.points + v_quest_coins;
  
  -- Return results
  RETURN QUERY SELECT
    v_quest_xp,
    v_quest_coins,
    v_new_xp,
    v_new_level,
    v_level_up;
END;
$$;

-- =========================================
-- STEP 6: UPDATE USER_PROFILES LEVEL ON XP CHANGE
-- =========================================

-- Trigger to auto-update level when XP changes
CREATE OR REPLACE FUNCTION public.update_level_on_xp_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_new_level INTEGER;
BEGIN
  -- Calculate level from total_xp
  v_new_level := public.calculate_level_from_xp(COALESCE(NEW.total_xp, 0));
  
  -- Update level if changed
  IF NEW.level IS NULL OR NEW.level != v_new_level THEN
    NEW.level := v_new_level;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trg_update_level_on_xp ON public.user_profiles;
CREATE TRIGGER trg_update_level_on_xp
  BEFORE INSERT OR UPDATE OF total_xp ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_level_on_xp_change();

-- =========================================
-- STEP 7: GRANT PERMISSIONS
-- =========================================

REVOKE EXECUTE ON FUNCTION public.calculate_level_xp FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_level_xp TO authenticated;

REVOKE EXECUTE ON FUNCTION public.calculate_level_from_xp FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_level_from_xp TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_xp_for_next_level FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_xp_for_next_level TO authenticated;

REVOKE EXECUTE ON FUNCTION public.generate_dynamic_quest FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_dynamic_quest TO authenticated;

REVOKE EXECUTE ON FUNCTION public.auto_generate_quest_on_completion FROM PUBLIC;

-- =========================================
-- STEP 8: COMMENTS
-- =========================================

COMMENT ON FUNCTION public.calculate_level_xp IS 'Calculates XP required for a specific level (exponential growth)';
COMMENT ON FUNCTION public.calculate_level_from_xp IS 'Calculates user level from total XP';
COMMENT ON FUNCTION public.get_xp_for_next_level IS 'Gets XP needed to reach next level';
COMMENT ON FUNCTION public.generate_dynamic_quest IS 'Generates a dynamic quest scaled to user level';
COMMENT ON FUNCTION public.auto_generate_quest_on_completion IS 'Auto-generates new quest when one is completed';
