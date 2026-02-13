-- Fix claim_quest_rewards: ensure user_profiles row exists and XP is properly awarded
-- Issue: When user_profiles has no row, SELECT returns nothing, v_current_xp stays NULL,
-- UPDATE affects 0 rows, and XP is never persisted.

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
  v_current_xp INTEGER := 0;
  v_current_level INTEGER := 1;
  v_new_xp INTEGER;
  v_new_level INTEGER;
  v_level_up BOOLEAN := false;
BEGIN
  -- Get quest info (allow claiming when progress >= target even if status not yet 'completed')
  SELECT uq.user_id, uq.reward_xp, COALESCE(uq.reward_coins, 0)
  INTO v_user_id, v_quest_xp, v_quest_coins
  FROM public.user_quests uq
  WHERE uq.id = p_quest_instance_id
    AND uq.user_id = auth.uid()
    AND (
      uq.status = 'completed'
      OR (uq.progress_current >= uq.progress_target AND uq.status IN ('available', 'in_progress'))
    );
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Quest not found, not completed, or already claimed';
  END IF;
  
  -- Ensure user_profiles row exists (create if missing)
  INSERT INTO public.user_profiles (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  
  -- Get current XP and level (now row is guaranteed to exist)
  SELECT COALESCE(total_xp, COALESCE(xp, 0), 0), COALESCE(level, 1)
  INTO v_current_xp, v_current_level
  FROM public.user_profiles
  WHERE user_id = v_user_id;
  
  -- Fallback if still null
  v_current_xp := COALESCE(v_current_xp, 0);
  v_current_level := COALESCE(v_current_level, 1);
  
  -- Calculate new XP
  v_new_xp := v_current_xp + COALESCE(v_quest_xp, 0);
  
  -- Calculate new level
  v_new_level := public.calculate_level_from_xp(v_new_xp);
  
  -- Check if leveled up
  IF v_new_level > v_current_level THEN
    v_level_up := true;
  END IF;
  
  -- Update user profile (total_xp and xp for compatibility)
  UPDATE public.user_profiles
  SET 
    total_xp = v_new_xp,
    level = v_new_level,
    xp = v_new_xp,
    updated_at = NOW()
  WHERE user_id = v_user_id;
  
  -- Mark quest as claimed and ensure status/complete
  UPDATE public.user_quests
  SET status = 'claimed', claimed_at = NOW(),
      progress_current = GREATEST(progress_current, progress_target),
      completed_at = COALESCE(completed_at, NOW())
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
    COALESCE(v_quest_xp, 0),
    v_quest_coins,
    v_new_xp,
    v_new_level,
    v_level_up;
END;
$$;

COMMENT ON FUNCTION public.claim_quest_rewards(UUID) IS 'Claims quest rewards, awards XP to user_profiles. Creates user_profiles row if missing.';
