-- Auto-award XP when quest is completed (no claim button needed)
-- When update_quest_progress sets progress >= target, immediately award XP and mark as claimed.

CREATE OR REPLACE FUNCTION public.update_quest_progress(
  p_quest_instance_id UUID,
  p_delta NUMERIC
)
RETURNS TABLE(
  quest_id UUID,
  current_progress NUMERIC,
  target_progress NUMERIC,
  is_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quest RECORD;
  v_new_progress NUMERIC;
  v_just_completed BOOLEAN := false;
  v_user_id UUID;
  v_quest_xp INTEGER;
  v_quest_coins INTEGER;
  v_current_xp INTEGER := 0;
  v_current_level INTEGER := 1;
  v_new_xp INTEGER;
  v_new_level INTEGER;
BEGIN
  -- Get quest
  SELECT * INTO v_quest
  FROM public.user_quests
  WHERE id = p_quest_instance_id
    AND user_id = auth.uid()
    AND status IN ('available', 'in_progress');
  
  IF v_quest IS NULL THEN
    RAISE EXCEPTION 'Quest not found or not accessible';
  END IF;
  
  -- Update progress
  v_new_progress := LEAST(
    (v_quest.progress_current + p_delta),
    v_quest.progress_target
  );
  
  v_just_completed := (v_new_progress >= v_quest.progress_target);
  
  IF v_just_completed THEN
    -- Quest just completed: award XP immediately and mark as claimed
    v_user_id := v_quest.user_id;
    v_quest_xp := COALESCE(v_quest.reward_xp, 0);
    v_quest_coins := COALESCE(v_quest.reward_coins, 0);
    
    -- Ensure user_profiles row exists
    INSERT INTO public.user_profiles (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Get current XP and level
    SELECT COALESCE(total_xp, COALESCE(xp, 0), 0), COALESCE(level, 1)
    INTO v_current_xp, v_current_level
    FROM public.user_profiles
    WHERE user_id = v_user_id;
    
    v_current_xp := COALESCE(v_current_xp, 0);
    v_current_level := COALESCE(v_current_level, 1);
    v_new_xp := v_current_xp + v_quest_xp;
    v_new_level := public.calculate_level_from_xp(v_new_xp);
    
    -- Update user profile
    UPDATE public.user_profiles
    SET total_xp = v_new_xp, level = v_new_level, xp = v_new_xp, updated_at = NOW()
    WHERE user_id = v_user_id;
    
    -- Award leaderboard points
    INSERT INTO public.leaderboard_points (user_id, period_type, period_start, points)
    VALUES (v_user_id, 'daily', CURRENT_DATE, v_quest_coins)
    ON CONFLICT (user_id, period_type, period_start)
    DO UPDATE SET points = leaderboard_points.points + v_quest_coins;
    
    -- Update quest: set to claimed (not just completed)
    UPDATE public.user_quests
    SET progress_current = v_new_progress,
        status = 'claimed',
        completed_at = COALESCE(completed_at, NOW()),
        claimed_at = NOW()
    WHERE id = p_quest_instance_id;
  ELSE
    -- Not yet complete: just update progress
    UPDATE public.user_quests
    SET progress_current = v_new_progress,
        status = 'in_progress'
    WHERE id = p_quest_instance_id;
  END IF;
  
  RETURN QUERY
  SELECT 
    p_quest_instance_id,
    v_new_progress,
    v_quest.progress_target,
    v_just_completed;
END;
$$;

COMMENT ON FUNCTION public.update_quest_progress(UUID, NUMERIC) IS 'Updates quest progress. When target is reached, auto-awards XP and marks as claimed.';
