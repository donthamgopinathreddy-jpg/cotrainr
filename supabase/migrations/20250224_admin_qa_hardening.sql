-- =========================================
-- ADMIN PRODUCTION QA HARDENING
-- =========================================
-- 1) Ensure all admin RPCs have OWNER postgres, REVOKE from PUBLIC/authenticated, GRANT to service_role
-- 2) admin_users table + optional actor enforcement
-- 3) admin_list_audit_log: p_offset, p_from, p_to filters
-- 4) Non-overloaded v2 RPCs for Retool (admin_grant_comp_v2, admin_remove_comp_v2, admin_force_reverification_v2)
-- 5) Actor UUID validation (trim, validate; when admin_users populated, enforce exists)
-- Idempotent. No rating edits.
-- =========================================

-- 1) admin_users table (optional enforcement: when populated, p_actor_id must exist)
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  added_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages admin_users" ON public.admin_users;
CREATE POLICY "Service role manages admin_users"
  ON public.admin_users FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.admin_users IS 'Admin users for Retool. When populated, p_actor_id in admin RPCs must exist here. Empty = bootstrap mode (no enforcement).';

-- Helper: validate actor (when provided). If admin_users has rows, actor must exist.
CREATE OR REPLACE FUNCTION public.admin_validate_actor(p_actor_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count BIGINT;
BEGIN
  IF p_actor_id IS NULL THEN
    RETURN true;  -- null allowed (backward compat, scripts)
  END IF;
  SELECT COUNT(*) INTO v_count FROM public.admin_users;
  IF v_count = 0 THEN
    RETURN true;  -- bootstrap: no enforcement
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = p_actor_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_validate_actor(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_validate_actor(UUID) FROM authenticated;
-- No GRANT: internal use only by admin RPCs

-- 2) admin_list_audit_log: add p_offset, p_from, p_to
CREATE OR REPLACE FUNCTION public.admin_list_audit_log(
  p_action TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0,
  p_from TIMESTAMPTZ DEFAULT NULL,
  p_to TIMESTAMPTZ DEFAULT NULL
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
    AND (p_from IS NULL OR a.created_at >= p_from)
    AND (p_to IS NULL OR a.created_at <= p_to)
  ORDER BY a.created_at DESC
  LIMIT least(greatest(coalesce(p_limit, 100), 1), 500)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(TEXT, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;
ALTER FUNCTION public.admin_list_audit_log(TEXT, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO postgres;

-- 3) Non-overloaded v2 RPCs (Retool should use these to avoid PostgREST overload ambiguity)
-- admin_grant_comp_v2(p_user_id, p_comp_until, p_actor_id)
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
  IF p_actor_id IS NOT NULL AND NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'actor_id is not an admin user');
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

-- admin_remove_comp_v2(p_user_id, p_actor_id)
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
  IF p_actor_id IS NOT NULL AND NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'actor_id is not an admin user');
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

-- admin_force_reverification_v2(p_user_id, p_actor_id)
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
  IF p_actor_id IS NOT NULL AND NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'actor_id is not an admin user');
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

-- 4) Update approve_verification and reject_verification with actor validation
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
  v_actor := p_reviewer_id;  -- UUID type, no trim needed; invalid UUID fails at call site
  IF v_actor IS NOT NULL AND NOT public.admin_validate_actor(v_actor) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reviewer_id is not an admin user');
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

-- reject_verification with actor validation
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
  IF v_actor IS NOT NULL AND NOT public.admin_validate_actor(v_actor) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reviewer_id is not an admin user');
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

-- 5) Ensure all admin RPCs have correct permissions (explicit re-apply)
REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) TO service_role;
ALTER FUNCTION public.admin_update_app_setting(TEXT, TEXT) OWNER TO postgres;

-- admin_list_audit_log old signature (2 args) - drop and rely on 5-arg only
DROP FUNCTION IF EXISTS public.admin_list_audit_log(TEXT, INTEGER);

-- RPC to add admin user (for bootstrap)
CREATE OR REPLACE FUNCTION public.admin_add_admin_user(p_user_id UUID, p_added_by UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.admin_users (user_id, added_by) VALUES (p_user_id, p_added_by)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_add_admin_user(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_add_admin_user(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_admin_user(UUID, UUID) TO service_role;
ALTER FUNCTION public.admin_add_admin_user(UUID, UUID) OWNER TO postgres;

COMMENT ON FUNCTION public.admin_add_admin_user(UUID, UUID) IS 'Add user to admin_users. Run via SQL or service_role. Bootstrap: add Retool admin UUIDs.';
