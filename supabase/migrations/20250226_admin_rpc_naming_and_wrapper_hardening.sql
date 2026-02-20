-- =========================================
-- ADMIN RPC NAMING AND WRAPPER HARDENING
-- =========================================
-- 1) Canonical v2 signatures: approve_verification_v2, reject_verification_v2 (p_actor_id)
-- 2) Old approve_verification/reject_verification as thin wrappers forwarding to v2
-- 3) All wrappers and v2 RPCs: identical security (SECURITY DEFINER, search_path, OWNER, REVOKE, GRANT)
-- 4) Actor validation first statement in each admin RPC (no set_config or table access before)
-- Idempotent. No rating edits.
-- =========================================

-- 1) approve_verification_v2: canonical signature with p_actor_id, validation first
CREATE OR REPLACE FUNCTION public.approve_verification_v2(
  p_submission_id UUID,
  p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_provider_type public.provider_type;
  v_row RECORD;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
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
        reviewer_id = p_actor_id
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, true)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('approve_verification', p_actor_id, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.approve_verification_v2(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification_v2(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification_v2(UUID, UUID) TO service_role;
ALTER FUNCTION public.approve_verification_v2(UUID, UUID) OWNER TO postgres;

-- 2) reject_verification_v2: canonical signature with p_actor_id, validation first
CREATE OR REPLACE FUNCTION public.reject_verification_v2(
  p_submission_id UUID,
  p_notes TEXT DEFAULT '',
  p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_provider_type public.provider_type;
  v_row RECORD;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
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
        reviewer_id = p_actor_id,
        rejection_notes = NULLIF(TRIM(COALESCE(p_notes, '')), '')
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, false)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('reject_verification', p_actor_id, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type, 'notes', p_notes));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.reject_verification_v2(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification_v2(UUID, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification_v2(UUID, TEXT, UUID) TO service_role;
ALTER FUNCTION public.reject_verification_v2(UUID, TEXT, UUID) OWNER TO postgres;

-- 3) approve_verification: thin wrapper forwarding to v2 (fails when admin_users has rows and p_reviewer_id NULL)
CREATE OR REPLACE FUNCTION public.approve_verification(p_submission_id UUID, p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.approve_verification_v2(p_submission_id, p_reviewer_id);
END;
$$;

REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification(UUID, UUID) TO service_role;
ALTER FUNCTION public.approve_verification(UUID, UUID) OWNER TO postgres;

-- 4) reject_verification: thin wrapper forwarding to v2 (fails when admin_users has rows and p_reviewer_id NULL)
CREATE OR REPLACE FUNCTION public.reject_verification(p_submission_id UUID, p_notes TEXT DEFAULT '', p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.reject_verification_v2(p_submission_id, p_notes, p_reviewer_id);
END;
$$;

REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification(UUID, TEXT, UUID) TO service_role;
ALTER FUNCTION public.reject_verification(UUID, TEXT, UUID) OWNER TO postgres;

-- 5) admin_update_app_setting 3-arg: ensure validation is first (move v_key/v_val after validation)
CREATE OR REPLACE FUNCTION public.admin_update_app_setting(p_key TEXT, p_value TEXT, p_actor_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key TEXT;
  v_val TEXT;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  v_key := lower(trim(p_key));
  v_val := trim(coalesce(p_value, ''));

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

-- =========================================
-- VERIFICATION SQL (run manually for testing)
-- =========================================
-- Wrappers fail once admin_users has rows (they forward NULL to v2, which fails validation):
--   INSERT INTO admin_users (user_id) VALUES ('<some-uuid>'::uuid);  -- populate admin_users
--   SELECT approve_verification('<submission_id>'::uuid, NULL);      -- wrapper: returns {ok:false, error:'Invalid actor'}
--   SELECT reject_verification('<submission_id>'::uuid, '', NULL);     -- wrapper: returns {ok:false, error:'Invalid actor'}
--   SELECT admin_update_app_setting('support_email', 'x@y.com');      -- 2-arg wrapper: returns {ok:false, error:'Invalid actor'}
--
-- Only service_role has EXECUTE on wrappers and v2 functions:
--   SELECT grantee, privilege_type FROM information_schema.routine_privileges
--   WHERE routine_name IN ('approve_verification', 'approve_verification_v2', 'reject_verification', 'reject_verification_v2',
--                          'admin_grant_comp_v2', 'admin_remove_comp_v2', 'admin_force_reverification_v2',
--                          'admin_update_app_setting', 'admin_list_audit_log')
--   AND routine_schema = 'public';
--   -- Expect: grantee = 'service_role', privilege_type = 'EXECUTE' only (no PUBLIC, no authenticated)
