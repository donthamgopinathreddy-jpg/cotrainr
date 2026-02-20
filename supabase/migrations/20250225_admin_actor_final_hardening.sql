-- =========================================
-- ADMIN ACTOR FINAL HARDENING
-- =========================================
-- 1) Tighten admin_validate_actor: NULL only when admin_users empty
-- 2) All admin RPCs: fail fast if p_actor_id NULL when admin_users has rows
-- 3) admin_list_audit_log: re-add 2-arg wrapper for backward compatibility
-- 4) admin_update_app_setting: add p_actor_id, call validation
-- Idempotent. No rating edits.
-- =========================================

-- 1) Tighten admin_validate_actor
-- NULL allowed only when admin_users is empty OR when called from admin_add_admin_user (which doesn't use this).
-- Otherwise: require p_actor_id IS NOT NULL AND exists in admin_users.
CREATE OR REPLACE FUNCTION public.admin_validate_actor(p_actor_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.admin_users;
  IF v_count = 0 THEN
    RETURN true;  -- bootstrap: no enforcement, NULL allowed
  END IF;
  -- admin_users has >= 1 row: require p_actor_id IS NOT NULL AND in admin_users
  IF p_actor_id IS NULL THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = p_actor_id);
END;
$$;

-- 2) approve_verification: fail fast when admin_users populated and p_reviewer_id NULL
CREATE OR REPLACE FUNCTION public.approve_verification(p_submission_id UUID, p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_provider_type public.provider_type;
  v_row RECORD;
  v_actor UUID;
BEGIN
  v_actor := p_reviewer_id;
  IF NOT public.admin_validate_actor(v_actor) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  SELECT user_id, status, provider_type, certificate_path, gov_id_path INTO v_row
  FROM public.verification_submissions
  WHERE id = p_submission_id;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission not found');
  END IF;

  IF v_row.status != 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission is not pending');
  END IF;

  IF COALESCE(trim(v_row.certificate_path), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Certificate path is missing. Cannot approve without document.');
  END IF;
  IF COALESCE(trim(v_row.gov_id_path), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Government ID path is missing. Cannot approve without document.');
  END IF;

  v_user_id := v_row.user_id;
  v_provider_type := v_row.provider_type;

  PERFORM set_config('app.allow_verified_update', 'true', true);

  BEGIN
    UPDATE public.verification_submissions
    SET status = 'approved',
        reviewed_at = now(),
        reviewer_id = v_actor
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, true)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('approve_verification', v_actor, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification(UUID, UUID) TO service_role;
ALTER FUNCTION public.approve_verification(UUID, UUID) OWNER TO postgres;

-- reject_verification
CREATE OR REPLACE FUNCTION public.reject_verification(p_submission_id UUID, p_notes TEXT DEFAULT '', p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_provider_type public.provider_type;
  v_row RECORD;
  v_actor UUID;
BEGIN
  v_actor := p_reviewer_id;
  IF NOT public.admin_validate_actor(v_actor) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  SELECT user_id, status, provider_type INTO v_row
  FROM public.verification_submissions
  WHERE id = p_submission_id;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission not found');
  END IF;

  IF v_row.status != 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission is not pending');
  END IF;

  v_user_id := v_row.user_id;
  v_provider_type := v_row.provider_type;

  PERFORM set_config('app.allow_verified_update', 'true', true);

  BEGIN
    UPDATE public.verification_submissions
    SET status = 'rejected',
        reviewed_at = now(),
        reviewer_id = v_actor,
        rejection_notes = NULLIF(TRIM(COALESCE(p_notes, '')), '')
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, false)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('reject_verification', v_actor, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type, 'notes', p_notes));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification(UUID, TEXT, UUID) TO service_role;
ALTER FUNCTION public.reject_verification(UUID, TEXT, UUID) OWNER TO postgres;

-- admin_grant_comp_v2
CREATE OR REPLACE FUNCTION public.admin_grant_comp_v2(
  p_user_id UUID,
  p_comp_until TIMESTAMPTZ,
  p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  INSERT INTO public.subscriptions (user_id, comp_until, updated_at)
  VALUES (p_user_id, p_comp_until, NOW())
  ON CONFLICT (user_id) DO UPDATE SET comp_until = EXCLUDED.comp_until, updated_at = NOW();

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES ('admin_grant_comp', p_actor_id, 'user', p_user_id, jsonb_build_object('comp_until', p_comp_until));

  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_grant_comp_v2(UUID, TIMESTAMPTZ, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_grant_comp_v2(UUID, TIMESTAMPTZ, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_comp_v2(UUID, TIMESTAMPTZ, UUID) TO service_role;
ALTER FUNCTION public.admin_grant_comp_v2(UUID, TIMESTAMPTZ, UUID) OWNER TO postgres;

-- admin_remove_comp_v2
CREATE OR REPLACE FUNCTION public.admin_remove_comp_v2(
  p_user_id UUID,
  p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  UPDATE public.subscriptions SET comp_until = NULL, updated_at = NOW() WHERE user_id = p_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES ('admin_remove_comp', p_actor_id, 'user', p_user_id, '{}'::jsonb);

  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_remove_comp_v2(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_remove_comp_v2(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_comp_v2(UUID, UUID) TO service_role;
ALTER FUNCTION public.admin_remove_comp_v2(UUID, UUID) OWNER TO postgres;

-- admin_force_reverification_v2
CREATE OR REPLACE FUNCTION public.admin_force_reverification_v2(
  p_user_id UUID,
  p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  PERFORM set_config('app.allow_verified_update', 'true', true);

  UPDATE public.providers SET verified = false WHERE user_id = p_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES ('admin_force_reverification', p_actor_id, 'user', p_user_id, '{}'::jsonb);

  PERFORM set_config('app.allow_verified_update', '', true);

  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_force_reverification_v2(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_force_reverification_v2(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_reverification_v2(UUID, UUID) TO service_role;
ALTER FUNCTION public.admin_force_reverification_v2(UUID, UUID) OWNER TO postgres;

-- admin_update_app_setting: add p_actor_id, call validation
CREATE OR REPLACE FUNCTION public.admin_update_app_setting(p_key TEXT, p_value TEXT, p_actor_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key TEXT := lower(trim(p_key));
  v_val TEXT := trim(coalesce(p_value, ''));
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  IF v_key NOT IN ('support_email', 'terms_url', 'privacy_url') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid key. Allowed: support_email, terms_url, privacy_url');
  END IF;

  IF v_key = 'support_email' AND v_val != '' THEN
    IF v_val !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Invalid email format');
    END IF;
  END IF;

  IF v_key IN ('terms_url', 'privacy_url') AND v_val != '' THEN
    IF v_val !~ '^https?://[^\s]+$' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Invalid URL format. Must start with http:// or https://');
    END IF;
  END IF;

  INSERT INTO public.app_settings (key, value, updated_at)
  VALUES (v_key, v_val, NOW())
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(TEXT, TEXT, UUID) TO service_role;
ALTER FUNCTION public.admin_update_app_setting(TEXT, TEXT, UUID) OWNER TO postgres;

-- Backward compat: admin_update_app_setting(p_key, p_value) - calls 3-arg with NULL actor (only works when admin_users empty)
DROP FUNCTION IF EXISTS public.admin_update_app_setting(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.admin_update_app_setting(p_key TEXT, p_value TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.admin_update_app_setting(p_key, p_value, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) TO service_role;
ALTER FUNCTION public.admin_update_app_setting(TEXT, TEXT) OWNER TO postgres;

-- 3) admin_list_audit_log: re-add 2-arg wrapper for backward compatibility
CREATE OR REPLACE FUNCTION public.admin_list_audit_log(p_action TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 100)
RETURNS TABLE (
  id UUID,
  action TEXT,
  actor_id UUID,
  target_type TEXT,
  target_id UUID,
  details JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.admin_list_audit_log(p_action, p_limit, 0, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER) TO service_role;
ALTER FUNCTION public.admin_list_audit_log(TEXT, INTEGER) OWNER TO postgres;

-- =========================================
-- VERIFICATION SQL (run manually for testing)
-- =========================================
-- Test actor enforcement WITH admin_users empty (bootstrap mode):
--   SELECT approve_verification('<submission_id>'::uuid, NULL);  -- should succeed
--   SELECT admin_grant_comp_v2('<user_id>'::uuid, now() + interval '30 days', NULL);  -- should succeed
--
-- Add first admin, then test enforcement:
--   SELECT admin_add_admin_user('<retool_admin_uuid>'::uuid, NULL);
--
-- Test actor enforcement WITH admin_users populated:
--   SELECT approve_verification('<submission_id>'::uuid, NULL);  -- should return {ok:false, error:'Invalid actor'}
--   SELECT approve_verification('<submission_id>'::uuid, '<retool_admin_uuid>'::uuid);  -- should succeed
--   SELECT admin_grant_comp_v2('<user_id>'::uuid, now() + interval '30 days', NULL);  -- should return {ok:false, error:'Invalid actor'}
--   SELECT admin_grant_comp_v2('<user_id>'::uuid, now() + interval '30 days', '<retool_admin_uuid>'::uuid);  -- should succeed
--
-- Call 5-arg admin_list_audit_log:
--   SELECT * FROM admin_list_audit_log(NULL, 50, 0, '2025-02-01'::timestamptz, '2025-02-28'::timestamptz);
--   SELECT * FROM admin_list_audit_log('approve_verification', 100, 0, NULL, NULL);
--
-- Call 2-arg wrapper (backward compat):
--   SELECT * FROM admin_list_audit_log(NULL, 100);
--   SELECT * FROM admin_list_audit_log('admin_grant_comp', 50);
