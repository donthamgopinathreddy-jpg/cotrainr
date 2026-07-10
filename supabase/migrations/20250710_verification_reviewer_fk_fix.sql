-- =========================================
-- Verification reviewer_id FK fix
-- =========================================
-- Root cause: admin_validate_actor (bootstrap mode) allowed any UUID without
-- checking auth.users, but verification_submissions.reviewer_id REFERENCES auth.users(id).
-- Retool was passing retoolContext.user.id (not an auth.users UUID) → FK violation.
--
-- Fix:
-- 1) admin_validate_actor always requires auth.users(id) when p_actor_id IS NOT NULL
-- 2) admin_resolve_actor_id(email) maps Retool user email → admin_users.user_id
-- 3) approve/reject v2 return ADMIN_ACTOR_NOT_MAPPED before FK failure
-- 4) approve sets discoverable=true; reject sets discoverable=false
-- Idempotent. Does not weaken FK or RLS.
-- =========================================

-- ---------------------------------------------------------------------------
-- 1) Harden admin_validate_actor — FK-compatible actor only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_validate_actor(p_actor_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_count BIGINT;
BEGIN
  IF p_actor_id IS NULL THEN
    RETURN false;
  END IF;

  -- reviewer_id / actor_id must reference auth.users(id)
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_actor_id) THEN
    RETURN false;
  END IF;

  SELECT COUNT(*) INTO v_admin_count FROM public.admin_users;
  IF v_admin_count = 0 THEN
    -- Bootstrap: allow any valid auth.users UUID (dev only). Production should populate admin_users.
    RETURN true;
  END IF;

  RETURN EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = p_actor_id);
END;
$$;

COMMENT ON FUNCTION public.admin_validate_actor(UUID) IS
  'Validates admin actor: non-null, exists in auth.users, and in admin_users when admin_users is populated.';

-- ---------------------------------------------------------------------------
-- 2) Resolve Retool admin email → auth.users UUID via admin_users
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_resolve_actor_id(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT;
  v_actor_id UUID;
  v_admin_count BIGINT;
BEGIN
  v_email := lower(trim(COALESCE(p_email, '')));
  IF v_email = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ADMIN_ACTOR_NOT_MAPPED',
      'detail', 'Retool user email is empty'
    );
  END IF;

  SELECT COUNT(*) INTO v_admin_count FROM public.admin_users;
  IF v_admin_count = 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ADMIN_ACTOR_NOT_MAPPED',
      'detail', 'admin_users table is empty — bootstrap admin first'
    );
  END IF;

  SELECT au.user_id
  INTO v_actor_id
  FROM public.admin_users au
  INNER JOIN auth.users u ON u.id = au.user_id
  WHERE lower(u.email) = v_email
  LIMIT 1;

  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ADMIN_ACTOR_NOT_MAPPED',
      'detail', format('No admin_users row for email %s', v_email)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'actor_id', v_actor_id,
    'email', v_email
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_resolve_actor_id(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_resolve_actor_id(TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_actor_id(TEXT) TO service_role;
ALTER FUNCTION public.admin_resolve_actor_id(TEXT) OWNER TO postgres;

COMMENT ON FUNCTION public.admin_resolve_actor_id(TEXT) IS
  'Maps Retool logged-in email to auth.users UUID via admin_users. Use for p_actor_id in verification RPCs.';

-- ---------------------------------------------------------------------------
-- 3) approve_verification_v2 — FK guard + discoverable=true
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.approve_verification_v2(UUID, UUID);

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

    INSERT INTO public.providers (user_id, provider_type, verified, discoverable)
    VALUES (v_user_id, v_provider_type, true, true)
    ON CONFLICT (user_id) DO UPDATE
      SET verified = true,
          discoverable = true,
          provider_type = EXCLUDED.provider_type;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('approve_verification', p_actor_id, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true, 'reviewer_id', p_actor_id);
END;
$$;

REVOKE ALL ON FUNCTION public.approve_verification_v2(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification_v2(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification_v2(UUID, UUID) TO service_role;
ALTER FUNCTION public.approve_verification_v2(UUID, UUID) OWNER TO postgres;

-- ---------------------------------------------------------------------------
-- 4) reject_verification_v2 — FK guard + discoverable=false
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.reject_verification_v2(UUID, TEXT, UUID);

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

    INSERT INTO public.providers (user_id, provider_type, verified, discoverable)
    VALUES (v_user_id, v_provider_type, false, false)
    ON CONFLICT (user_id) DO UPDATE
      SET verified = false,
          discoverable = false,
          provider_type = EXCLUDED.provider_type;

    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES ('reject_verification', p_actor_id, 'verification_submission', p_submission_id,
            jsonb_build_object('user_id', v_user_id, 'provider_type', v_provider_type, 'notes', p_notes));
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true, 'reviewer_id', p_actor_id);
END;
$$;

REVOKE ALL ON FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) TO service_role;
ALTER FUNCTION public.reject_verification_v2(UUID, UUID, TEXT) OWNER TO postgres;

-- Wrappers unchanged (delegate to v2)
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

CREATE OR REPLACE FUNCTION public.reject_verification(
  p_submission_id UUID,
  p_notes TEXT DEFAULT '',
  p_reviewer_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.reject_verification_v2(p_submission_id, p_reviewer_id, p_notes);
END;
$$;

-- ---------------------------------------------------------------------------
-- Bootstrap helpers (run manually in SQL Editor — do not hardcode secrets)
-- ---------------------------------------------------------------------------
-- Check FK target:
--   reviewer_id → auth.users(id)
--
-- List auth users (pick admin email):
--   SELECT id, email FROM auth.users ORDER BY created_at;
--
-- Check current admin mapping:
--   SELECT au.user_id, u.email, au.added_at
--   FROM public.admin_users au
--   JOIN auth.users u ON u.id = au.user_id;
--
-- Add admin (use real auth.users.id from query above):
--   SELECT public.admin_add_admin_user('<auth-users-uuid>'::uuid, NULL);
--
-- Test actor resolve (Retool email):
--   SELECT public.admin_resolve_actor_id('admin@yourdomain.com');
--
-- Verify FK compatibility before approve:
--   SELECT EXISTS (SELECT 1 FROM auth.users WHERE id = '<actor-uuid>'::uuid);
