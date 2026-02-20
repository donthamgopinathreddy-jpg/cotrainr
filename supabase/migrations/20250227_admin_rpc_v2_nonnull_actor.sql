-- =========================================
-- ADMIN RPC V2 NON-NULL ACTOR
-- =========================================
-- 1) Remove DEFAULT NULL from p_actor_id in v2 signatures
-- 2) Wrappers unchanged: pure delegation only (no audit, set_config, validation)
-- 3) Identical ownership + grants for wrapper and v2
-- Idempotent. No rating edits.
-- =========================================

-- DROP required: PostgreSQL cannot remove parameter defaults via CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.approve_verification_v2(UUID, UUID);

-- 1) approve_verification_v2: p_actor_id required (no default)
CREATE OR REPLACE FUNCTION public.approve_verification_v2(
  p_submission_id UUID,
  p_actor_id UUID
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

-- DROP required: PostgreSQL cannot remove parameter defaults via CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.reject_verification_v2(UUID, TEXT, UUID);

-- 2) reject_verification_v2: p_actor_id required (no default), p_notes last with default ''
-- Param order: p_actor_id before p_notes (params with defaults must come last)
CREATE OR REPLACE FUNCTION public.reject_verification_v2(
  p_submission_id UUID,
  p_actor_id UUID,
  p_notes TEXT DEFAULT ''
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

REVOKE ALL ON FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) TO service_role;
ALTER FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) OWNER TO postgres;

-- 3) approve_verification: thin wrapper, delegation only (no audit, set_config, validation)
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

-- 4) reject_verification: thin wrapper, delegation only (no audit, set_config, validation)
CREATE OR REPLACE FUNCTION public.reject_verification(p_submission_id UUID, p_notes TEXT DEFAULT '', p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.reject_verification_v2(p_submission_id, p_reviewer_id, p_notes);
END;
$$;

REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification(UUID, TEXT, UUID) TO service_role;
ALTER FUNCTION public.reject_verification(UUID, TEXT, UUID) OWNER TO postgres;
