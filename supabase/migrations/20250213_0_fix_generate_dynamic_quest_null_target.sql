-- Fix generate_dynamic_quest: nutrition and consistency cases never set v_scaled_target,
-- causing NULL progress_target when auto_generate_quest_on_completion runs after backfill.

-- Add v_scaled_target for nutrition (uses v_base_target)
-- Add v_scaled_target for consistency (uses 1)

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
  SELECT COALESCE(level, 1), COALESCE(total_xp, 0)
  INTO v_user_level, v_user_xp
  FROM public.user_profiles
  WHERE user_id = p_user_id;
  
  IF v_user_level IS NULL THEN
    INSERT INTO public.user_profiles (user_id, level, total_xp)
    VALUES (p_user_id, 1, 0)
    ON CONFLICT (user_id) DO NOTHING;
    v_user_level := 1;
    v_user_xp := 0;
  END IF;
  
  IF v_user_level <= 5 THEN
    v_difficulty := 'easy';
  ELSIF v_user_level <= 15 THEN
    v_difficulty := 'medium';
  ELSIF v_user_level <= 30 THEN
    v_difficulty := 'hard';
  ELSE
    v_difficulty := 'hard';
  END IF;
  
  CASE p_category
    WHEN 'steps' THEN
      IF p_quest_type = 'weekly' THEN
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 35000
          WHEN 'medium' THEN 70000
          ELSE 105000
        END;
        v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 3500);
        v_scaled_target := LEAST(v_scaled_target, 210000);
      ELSE
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 5000
          WHEN 'medium' THEN 10000
          ELSE 15000
        END;
        v_scaled_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 500);
        v_scaled_target := LEAST(v_scaled_target, 30000);
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
      v_requirements := jsonb_build_object('target', v_scaled_target, 'type', 'steps');
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
      IF v_user_level % 2 = 0 THEN
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
        v_requirements := jsonb_build_object('target', v_scaled_target, 'type', 'distance');
      ELSE
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
        v_requirements := jsonb_build_object('target', v_scaled_target, 'type', 'calories');
      END IF;
      v_icon_name := 'fitness_center';
      v_icon_color := '#F44336';
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
      v_requirements := jsonb_build_object('target', v_scaled_target, 'type', 'water');
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
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 2
          WHEN 'medium' THEN 3
          ELSE 4
        END;
        v_title := 'Log ' || FLOOR(v_base_target) || ' Meals';
        v_description := 'Log ' || FLOOR(v_base_target) || ' meals today';
        v_requirements := jsonb_build_object('target', v_base_target, 'type', 'meals');
      ELSE
        v_base_target := CASE v_difficulty
          WHEN 'easy' THEN 60
          WHEN 'medium' THEN 80
          ELSE 100
        END;
        v_base_target := v_base_target + (FLOOR((v_user_level - 1) / 5) * 10);
        v_base_target := LEAST(v_base_target, 150);
        v_title := 'Hit ' || FLOOR(v_base_target) || 'g Protein';
        v_description := 'Hit ' || FLOOR(v_base_target) || 'g protein today';
        v_requirements := jsonb_build_object('target', v_base_target, 'type', 'protein');
      END IF;
      v_scaled_target := v_base_target;  -- FIX: was never set, caused NULL progress_target
      v_icon_name := 'restaurant';
      v_icon_color := '#4CAF50';
      v_reward_xp := CASE v_difficulty
        WHEN 'easy' THEN 40 + (v_user_level * 2)
        WHEN 'medium' THEN 60 + (v_user_level * 3)
        ELSE 80 + (v_user_level * 4)
      END;
      v_reward_points := FLOOR(v_reward_xp * 0.2);
      
    ELSE
      v_title := 'Daily Check-in';
      v_description := 'Open Cotrainr and log 1 metric';
      v_icon_name := 'check_circle';
      v_icon_color := '#9C27B0';
      v_requirements := jsonb_build_object('target', 1, 'type', 'log_metric');
      v_scaled_target := 1;  -- FIX: was never set, caused NULL progress_target
      v_reward_xp := 20 + (v_user_level * 1);
      v_reward_points := FLOOR(v_reward_xp * 0.25);
  END CASE;
  
  IF p_quest_type = 'daily' THEN
    v_expires_at := (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMPTZ;
  ELSE
    v_expires_at := (DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '1 week')::TIMESTAMPTZ;
  END IF;
  
  INSERT INTO public.user_quests (
    user_id, quest_definition_id, type, category, difficulty, status,
    progress_current, progress_target, reward_xp, reward_coins,
    assigned_at, expires_at, requirements
  ) VALUES (
    p_user_id, NULL, p_quest_type, p_category, v_difficulty, 'available',
    0, v_scaled_target, v_reward_xp, v_reward_points,
    NOW(), v_expires_at,
    v_requirements || jsonb_build_object(
      'title', v_title, 'description', v_description,
      'icon_name', v_icon_name, 'icon_color', v_icon_color
    )
  )
  RETURNING id INTO v_quest_id;
  
  RETURN v_quest_id;
END;
$$;
