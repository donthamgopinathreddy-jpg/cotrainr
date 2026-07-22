-- =========================================
-- Fix: verification approval not reaching Discover
-- =========================================
-- Source of truth for Discover:
--   providers.verified = true AND providers.discoverable = true
--
-- Workflow state (Retool list / history):
--   verification_submissions.status = 'approved' | 'rejected' | 'pending'
--
-- Confirmed failure mode:
-- Retool (or a partial path) can leave verification_submissions.status='approved'
-- while providers.verified stays false. nearby_providers / discover_providers
-- only read providers.verified → trainer never appears in Discover.
--
-- Also: protect_providers_verified previously SILENTLY reverted verified changes
-- when app.allow_verified_update was not set, so an UPDATE could "succeed"
-- without changing verified.
-- =========================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1) Loud protect trigger (no silent revert)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_providers_verified()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.verified IS DISTINCT FROM NEW.verified THEN
    IF current_setting('app.allow_verified_update', true) IS DISTINCT FROM 'true' THEN
      RAISE EXCEPTION
        'providers.verified can only be changed via approve/reject verification RPCs (or sync trigger)'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_providers_verified ON public.providers;
CREATE TRIGGER trg_protect_providers_verified
  BEFORE UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_providers_verified();

-- ---------------------------------------------------------------------------
-- 2) Keep providers.verified in sync when submission status changes
--    (covers Retool direct table updates + RPC approve/reject)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_provider_verified_from_submission()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'approved' THEN
    PERFORM set_config('app.allow_verified_update', 'true', true);
    INSERT INTO public.providers (user_id, provider_type, verified, discoverable)
    VALUES (NEW.user_id, NEW.provider_type, true, true)
    ON CONFLICT (user_id) DO UPDATE
      SET verified = true,
          discoverable = true,
          provider_type = EXCLUDED.provider_type;
    PERFORM set_config('app.allow_verified_update', '', true);
  ELSIF NEW.status = 'rejected' THEN
    PERFORM set_config('app.allow_verified_update', 'true', true);
    INSERT INTO public.providers (user_id, provider_type, verified, discoverable)
    VALUES (NEW.user_id, NEW.provider_type, false, false)
    ON CONFLICT (user_id) DO UPDATE
      SET verified = false,
          discoverable = false,
          provider_type = EXCLUDED.provider_type;
    PERFORM set_config('app.allow_verified_update', '', true);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_provider_verified_from_submission
  ON public.verification_submissions;
CREATE TRIGGER trg_sync_provider_verified_from_submission
  AFTER UPDATE OF status ON public.verification_submissions
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_provider_verified_from_submission();

COMMENT ON FUNCTION public.sync_provider_verified_from_submission() IS
  'Single write-path sync: verification_submissions.status → providers.verified/discoverable.';

-- ---------------------------------------------------------------------------
-- 3) Harden approve_verification_v2 — always set verified+discoverable and verify
-- ---------------------------------------------------------------------------
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
  v_verified BOOLEAN;
BEGIN
  IF p_actor_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ADMIN_ACTOR_NOT_MAPPED',
      'detail', 'p_actor_id is required'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_actor_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ADMIN_ACTOR_NOT_MAPPED',
      'detail', 'Actor UUID is not a valid auth.users id — use admin_resolve_actor_id from Retool email'
    );
  END IF;

  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ADMIN_ACTOR_NOT_MAPPED',
      'detail', 'Actor is not an authorized admin'
    );
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
    -- AFTER UPDATE trigger also syncs providers; explicit upsert keeps RPC self-contained.

    INSERT INTO public.providers (user_id, provider_type, verified, discoverable)
    VALUES (v_user_id, v_provider_type, true, true)
    ON CONFLICT (user_id) DO UPDATE
      SET verified = true,
          discoverable = true,
          provider_type = EXCLUDED.provider_type;

    SELECT verified INTO v_verified
    FROM public.providers
    WHERE user_id = v_user_id;

    IF v_verified IS NOT TRUE THEN
      RAISE EXCEPTION
        'approve_verification_v2 failed: providers.verified remained false for user %',
        v_user_id;
    END IF;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES (
      'approve_verification',
      p_actor_id,
      'verification_submission',
      p_submission_id,
      jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type)
    );
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true, 'reviewer_id', p_actor_id, 'user_id', v_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.approve_verification_v2(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification_v2(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification_v2(UUID, UUID) TO service_role;
ALTER FUNCTION public.approve_verification_v2(UUID, UUID) OWNER TO postgres;

-- Keep thin wrapper
CREATE OR REPLACE FUNCTION public.approve_verification(
  p_submission_id UUID,
  p_reviewer_id UUID DEFAULT NULL
)
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

-- ---------------------------------------------------------------------------
-- 4) Repair existing drift: approved submissions → providers.verified
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
BEGIN
  PERFORM set_config('app.allow_verified_update', 'true', true);

  FOR r IN
    SELECT DISTINCT ON (vs.user_id)
      vs.user_id,
      vs.provider_type
    FROM public.verification_submissions vs
    WHERE vs.status = 'approved'
    ORDER BY vs.user_id, vs.reviewed_at DESC NULLS LAST, vs.submitted_at DESC
  LOOP
    INSERT INTO public.providers (user_id, provider_type, verified, discoverable)
    VALUES (r.user_id, r.provider_type, true, true)
    ON CONFLICT (user_id) DO UPDATE
      SET verified = true,
          discoverable = true,
          provider_type = EXCLUDED.provider_type;
  END LOOP;

  PERFORM set_config('app.allow_verified_update', '', true);
END $$;
