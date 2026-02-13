-- One-time backfill: Award XP for quests that were completed before auto-award was implemented
-- Handles quests with status 'completed' that never got claimed

DO $$
DECLARE
  v_quest RECORD;
  v_current_xp INTEGER;
  v_new_xp INTEGER;
  v_new_level INTEGER;
  v_quest_xp INTEGER;
  v_quest_coins INTEGER;
BEGIN
  FOR v_quest IN
    SELECT id, user_id, reward_xp, reward_coins
    FROM public.user_quests
    WHERE status = 'completed'
      AND claimed_at IS NULL
      AND progress_current >= progress_target
  LOOP
    v_quest_xp := COALESCE(v_quest.reward_xp, 0);
    v_quest_coins := COALESCE(v_quest.reward_coins, 0);
    
    -- Ensure user_profiles exists
    INSERT INTO public.user_profiles (user_id)
    VALUES (v_quest.user_id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Get current XP
    SELECT COALESCE(total_xp, COALESCE(xp, 0), 0) INTO v_current_xp
    FROM public.user_profiles
    WHERE user_id = v_quest.user_id;
    
    v_current_xp := COALESCE(v_current_xp, 0);
    v_new_xp := v_current_xp + v_quest_xp;
    v_new_level := public.calculate_level_from_xp(v_new_xp);
    
    -- Update profile
    UPDATE public.user_profiles
    SET total_xp = v_new_xp, level = v_new_level, xp = v_new_xp, updated_at = NOW()
    WHERE user_id = v_quest.user_id;
    
    -- Leaderboard points
    INSERT INTO public.leaderboard_points (user_id, period_type, period_start, points)
    VALUES (v_quest.user_id, 'daily', CURRENT_DATE, v_quest_coins)
    ON CONFLICT (user_id, period_type, period_start)
    DO UPDATE SET points = leaderboard_points.points + v_quest_coins;
    
    -- Mark as claimed
    UPDATE public.user_quests
    SET status = 'claimed', claimed_at = NOW()
    WHERE id = v_quest.id;
  END LOOP;
END $$;
