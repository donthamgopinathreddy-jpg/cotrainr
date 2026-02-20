-- =========================================
-- ADMIN PRODUCTION HARDENING
-- =========================================
-- 1) admin_audit_log table
-- 2) approve_verification: block if cert/gov_id path NULL
-- 3) admin_update_app_setting: whitelist keys, validate email/URL
-- 4) admin_force_reverification RPC
-- 5) Audit logging for all admin actions
-- Idempotent. No rating edits.
-- =========================================

-- 1) admin_audit_log table
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,
  actor_id UUID,
  target_type TEXT,
  target_id UUID,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_action ON public.admin_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created_at ON public.admin_audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target ON public.admin_audit_log(target_type, target_id);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- No policies: only service_role (via RPCs) can insert. No SELECT for authenticated.
DROP POLICY IF EXISTS "Service role manages audit log" ON public.admin_audit_log;
CREATE POLICY "Service role manages audit log"
  ON public.admin_audit_log FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.admin_audit_log IS 'Admin action audit trail. Insert-only from RPCs.';

-- admin_list_audit_log for Retool (REST-only pattern)
CREATE OR REPLACE FUNCTION public.admin_list_audit_log(
  p_action TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 100
)
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
  SELECT a.id, a.action, a.actor_id, a.target_type, a.target_id, a.details, a.created_at
  FROM public.admin_audit_log a
  WHERE (p_action IS NULL OR a.action = p_action)
  ORDER BY a.created_at DESC
  LIMIT least(greatest(coalesce(p_limit, 100), 1), 500);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER) TO service_role;
ALTER FUNCTION public.admin_list_audit_log(TEXT, INTEGER) OWNER TO postgres;

-- 2) approve_verification: block if certificate_path or gov_id_path is NULL, add audit log
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
BEGIN
  SELECT user_id, status, provider_type, certificate_path, gov_id_path INTO v_row
  FROM public.verification_submissions
  WHERE id = p_submission_id;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission not found');
  END IF;

  IF v_row.status != 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission is not pending');
  END IF;

  -- Block approval if document paths are missing (do not rely on Retool UI alone)
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
        reviewer_id = p_reviewer_id
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, true)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('approve_verification', p_reviewer_id, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- 3) reject_verification: add audit log
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
BEGIN
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
        reviewer_id = p_reviewer_id,
        rejection_notes = NULLIF(TRIM(COALESCE(p_notes, '')), '')
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, false)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('reject_verification', p_reviewer_id, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type, 'notes', p_notes));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- 4) admin_update_app_setting: whitelist keys, validate email/URL
CREATE OR REPLACE FUNCTION public.admin_update_app_setting(p_key TEXT, p_value TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key TEXT := lower(trim(p_key));
  v_val TEXT := trim(coalesce(p_value, ''));
BEGIN
  -- Whitelist keys
  IF v_key NOT IN ('support_email', 'terms_url', 'privacy_url') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid key. Allowed: support_email, terms_url, privacy_url');
  END IF;

  -- support_email: validate email format (basic)
  IF v_key = 'support_email' AND v_val != '' THEN
    IF v_val !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Invalid email format');
    END IF;
  END IF;

  -- terms_url, privacy_url: validate URL format (basic) if non-empty
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

REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) TO service_role;
ALTER FUNCTION public.admin_update_app_setting(TEXT, TEXT) OWNER TO postgres;

-- 5) admin_grant_comp: add audit log
CREATE OR REPLACE FUNCTION public.admin_grant_comp(p_user_id UUID, p_comp_until TIMESTAMPTZ, p_actor_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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

REVOKE ALL ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ, UUID) TO service_role;
ALTER FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ, UUID) OWNER TO postgres;

-- Backward compatibility: admin_grant_comp(UUID, TIMESTAMPTZ) calls 3-arg version
DROP FUNCTION IF EXISTS public.admin_grant_comp(UUID, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.admin_grant_comp(p_user_id UUID, p_comp_until TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.admin_grant_comp(p_user_id, p_comp_until, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) TO service_role;
ALTER FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) OWNER TO postgres;

-- 6) admin_remove_comp: add audit log
CREATE OR REPLACE FUNCTION public.admin_remove_comp(p_user_id UUID, p_actor_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.subscriptions SET comp_until = NULL, updated_at = NOW() WHERE user_id = p_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES ('admin_remove_comp', p_actor_id, 'user', p_user_id, '{}'::jsonb);

  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_remove_comp(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_remove_comp(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_comp(UUID, UUID) TO service_role;
ALTER FUNCTION public.admin_remove_comp(UUID, UUID) OWNER TO postgres;

DROP FUNCTION IF EXISTS public.admin_remove_comp(UUID);
CREATE OR REPLACE FUNCTION public.admin_remove_comp(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.admin_remove_comp(p_user_id, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_remove_comp(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_remove_comp(UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_comp(UUID) TO service_role;
ALTER FUNCTION public.admin_remove_comp(UUID) OWNER TO postgres;

-- 7) admin_force_reverification: set providers.verified = false for re-verification
CREATE OR REPLACE FUNCTION public.admin_force_reverification(p_user_id UUID, p_actor_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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

REVOKE ALL ON FUNCTION public.admin_force_reverification(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_force_reverification(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_reverification(UUID, UUID) TO service_role;
ALTER FUNCTION public.admin_force_reverification(UUID, UUID) OWNER TO postgres;

-- Backward compatibility: 1-arg version
DROP FUNCTION IF EXISTS public.admin_force_reverification(UUID);
CREATE OR REPLACE FUNCTION public.admin_force_reverification(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.admin_force_reverification(p_user_id, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_force_reverification(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_force_reverification(UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_reverification(UUID) TO service_role;
ALTER FUNCTION public.admin_force_reverification(UUID) OWNER TO postgres;

COMMENT ON FUNCTION public.admin_force_reverification(UUID) IS 'Admin-only: set providers.verified=false for re-verification. User can submit new verification_submissions.';
