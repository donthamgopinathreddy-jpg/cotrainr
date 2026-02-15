-- =========================================
-- REFERRAL SYSTEM (Production-grade, idempotent)
-- =========================================
-- Domain: https://www.cotrainr.com
-- Rewards: referrer +500 XP + 2x for 24h, referred +250 XP
-- Rewards granted ONLY when referred user reaches milestone (500 XP)
-- Safe to re-run: drops and recreates referral objects only
-- =========================================

-- Drop existing objects (idempotent)
DROP TRIGGER IF EXISTS trg_referral_milestone_on_xp ON public.user_profiles;
DROP FUNCTION IF EXISTS public.trg_referral_milestone_check();
DROP FUNCTION IF EXISTS public.grant_referral_rewards(UUID);
DROP FUNCTION IF EXISTS public.apply_referral_code(TEXT);
DROP FUNCTION IF EXISTS public.generate_referral_code();
DROP TABLE IF EXISTS public.referral_rewards CASCADE;
DROP TABLE IF EXISTS public.referrals CASCADE;
DROP TABLE IF EXISTS public.referral_codes CASCADE;

-- A) referral_codes: one code per user
CREATE TABLE public.referral_codes (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  code TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- B) referrals: links referrer -> referred (rewarded=false until milestone)
CREATE TABLE public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_used TEXT NOT NULL,
  rewarded BOOLEAN NOT NULL DEFAULT false,
  rewarded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(referred_id),
  CHECK (referrer_id <> referred_id)
);

CREATE INDEX idx_referrals_referrer ON public.referrals(referrer_id);
CREATE INDEX idx_referrals_referred ON public.referrals(referred_id);
CREATE INDEX idx_referrals_code_used ON public.referrals(code_used);

-- C) referral_rewards: audit log, UNIQUE for idempotent inserts
CREATE TABLE public.referral_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_id UUID NOT NULL REFERENCES public.referrals(id) ON DELETE CASCADE,
  reward_type TEXT NOT NULL CHECK (reward_type IN ('xp', 'multiplier')),
  reward_value NUMERIC NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(referral_id, user_id, reward_type)
);

CREATE INDEX idx_referral_rewards_user ON public.referral_rewards(user_id);

-- D) Ensure user_profiles has total_xp and xp_multiplier_until
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_profiles' AND column_name = 'total_xp'
  ) THEN
    ALTER TABLE public.user_profiles ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0;
    UPDATE public.user_profiles SET total_xp = COALESCE(xp, 0) WHERE total_xp = 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_profiles' AND column_name = 'xp_multiplier_until'
  ) THEN
    ALTER TABLE public.user_profiles ADD COLUMN xp_multiplier_until TIMESTAMPTZ;
  END IF;
END $$;

-- =========================================
-- RLS: SELECT only for own data, no INSERT/UPDATE/DELETE
-- =========================================
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can select own referral code" ON public.referral_codes;
CREATE POLICY "Users can select own referral code" ON public.referral_codes
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can select own referrals" ON public.referrals;
CREATE POLICY "Users can select own referrals" ON public.referrals
  FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

DROP POLICY IF EXISTS "Users can select own referral rewards" ON public.referral_rewards;
CREATE POLICY "Users can select own referral rewards" ON public.referral_rewards
  FOR SELECT USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE policies: only RPC (SECURITY DEFINER) can write
-- Service role bypasses RLS for triggers/RPCs

-- =========================================
-- RPC: generate_referral_code
-- 8 chars, uppercase, exclude I,O,1,0 (ambiguous)
-- =========================================
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_code TEXT;
  v_exists BOOLEAN;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_i INT;
  v_idx INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT code INTO v_code FROM public.referral_codes WHERE user_id = v_user_id;
  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  LOOP
    v_code := '';
    FOR v_i IN 1..8 LOOP
      v_idx := 1 + FLOOR(RANDOM() * LENGTH(v_chars))::INT;
      v_code := v_code || SUBSTRING(v_chars FROM v_idx FOR 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM public.referral_codes WHERE code = v_code) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;

  INSERT INTO public.referral_codes (user_id, code)
  VALUES (v_user_id, v_code)
  ON CONFLICT (user_id) DO UPDATE SET code = EXCLUDED.code;

  RETURN v_code;
END;
$$;

-- =========================================
-- RPC: apply_referral_code
-- Creates referral row with rewarded=false. No rewards yet.
-- Returns: success | invalid_code | already_used | self_referral
-- =========================================
CREATE OR REPLACE FUNCTION public.apply_referral_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referred_id UUID := auth.uid();
  v_referrer_id UUID;
  v_referral_id UUID;
BEGIN
  IF v_referred_id IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_code', 'message', 'Not authenticated');
  END IF;

  p_code := UPPER(TRIM(NULLIF(p_code, '')));
  IF p_code IS NULL OR LENGTH(p_code) < 4 THEN
    RETURN jsonb_build_object('status', 'invalid_code', 'message', 'Invalid referral code');
  END IF;

  SELECT user_id INTO v_referrer_id FROM public.referral_codes WHERE code = p_code;
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_code', 'message', 'Referral code not found');
  END IF;

  IF v_referrer_id = v_referred_id THEN
    RETURN jsonb_build_object('status', 'self_referral', 'message', 'Cannot use your own referral code');
  END IF;

  SELECT id INTO v_referral_id FROM public.referrals WHERE referred_id = v_referred_id;
  IF v_referral_id IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'already_used', 'message', 'Referral already applied', 'referral_id', v_referral_id);
  END IF;

  INSERT INTO public.referrals (referrer_id, referred_id, code_used, rewarded)
  VALUES (v_referrer_id, v_referred_id, p_code, false)
  RETURNING id INTO v_referral_id;

  RETURN jsonb_build_object(
    'status', 'success',
    'message', 'Referral applied. Rewards unlock when you reach 500 XP!',
    'referrer_id', v_referrer_id,
    'referral_id', v_referral_id
  );
END;
$$;

-- =========================================
-- RPC: grant_referral_rewards
-- Idempotent: ON CONFLICT DO NOTHING on referral_rewards
-- =========================================
CREATE OR REPLACE FUNCTION public.grant_referral_rewards(p_referred_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referral RECORD;
  v_referrer_xp INTEGER;
  v_referrer_level INTEGER;
  v_referrer_multiplier_until TIMESTAMPTZ;
  v_referred_xp INTEGER;
  v_referred_level INTEGER;
  v_new_referrer_xp INTEGER;
  v_new_referred_xp INTEGER;
  v_new_referrer_level INTEGER;
  v_new_referred_level INTEGER;
BEGIN
  SELECT * INTO v_referral
  FROM public.referrals
  WHERE referred_id = p_referred_id AND rewarded = false
  LIMIT 1
  FOR UPDATE;

  IF v_referral IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'status', 'no_pending', 'message', 'No pending referral to reward');
  END IF;

  INSERT INTO public.user_profiles (user_id)
  VALUES (v_referral.referrer_id), (p_referred_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT COALESCE(up.total_xp, COALESCE(up.xp, 0), 0), COALESCE(up.level, 1), up.xp_multiplier_until
  INTO v_referrer_xp, v_referrer_level, v_referrer_multiplier_until
  FROM public.user_profiles up WHERE up.user_id = v_referral.referrer_id;

  SELECT COALESCE(up.total_xp, COALESCE(up.xp, 0), 0), COALESCE(up.level, 1)
  INTO v_referred_xp, v_referred_level
  FROM public.user_profiles up WHERE up.user_id = p_referred_id;

  v_referrer_xp := COALESCE(v_referrer_xp, 0);
  v_referred_xp := COALESCE(v_referred_xp, 0);

  v_new_referrer_xp := v_referrer_xp + 500;
  v_new_referrer_level := public.calculate_level_from_xp(v_new_referrer_xp);
  v_new_referred_xp := v_referred_xp + 250;
  v_new_referred_level := public.calculate_level_from_xp(v_new_referred_xp);

  UPDATE public.user_profiles
  SET total_xp = v_new_referrer_xp, level = v_new_referrer_level, xp = v_new_referrer_xp,
      xp_multiplier_until = GREATEST(COALESCE(xp_multiplier_until, '1970-01-01'::timestamptz), NOW()) + INTERVAL '24 hours',
      updated_at = NOW()
  WHERE user_id = v_referral.referrer_id;

  UPDATE public.user_profiles
  SET total_xp = v_new_referred_xp, level = v_new_referred_level, xp = v_new_referred_xp,
      updated_at = NOW()
  WHERE user_id = p_referred_id;

  -- Idempotent: ON CONFLICT DO NOTHING
  INSERT INTO public.referral_rewards (user_id, referral_id, reward_type, reward_value)
  VALUES (v_referral.referrer_id, v_referral.id, 'xp', 500),
         (v_referral.referrer_id, v_referral.id, 'multiplier', 2),
         (p_referred_id, v_referral.id, 'xp', 250)
  ON CONFLICT (referral_id, user_id, reward_type) DO NOTHING;

  UPDATE public.referrals
  SET rewarded = true, rewarded_at = NOW()
  WHERE id = v_referral.id;

  RETURN jsonb_build_object('ok', true, 'status', 'rewarded', 'message', 'Referral rewards granted', 'referral_id', v_referral.id);
END;
$$;

-- =========================================
-- Trigger: fires exactly once when XP crosses 500
-- Uses total_xp (fallback to xp if total_xp column missing in older schema)
-- =========================================
CREATE OR REPLACE FUNCTION public.trg_referral_milestone_check()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_xp INTEGER;
  v_old_xp INTEGER;
BEGIN
  v_new_xp := COALESCE(NEW.total_xp, NEW.xp, 0);
  v_old_xp := COALESCE(OLD.total_xp, OLD.xp, 0);

  IF v_new_xp >= 500 AND v_old_xp < 500 THEN
    PERFORM public.grant_referral_rewards(NEW.user_id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_referral_milestone_on_xp
  AFTER UPDATE OF total_xp ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_referral_milestone_check();

GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_referral_rewards(UUID) TO authenticated;
