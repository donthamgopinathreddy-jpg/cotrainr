-- ---------------------------------------------------------------------------
-- Cotrainr — profiles moderation / admin field hardening (MANUAL)
-- Date: 2026-08-30
--
-- WHY
--   public.profiles has a client UPDATE policy (users update own row) and a
--   table-level UPDATE grant to `authenticated`. public.enforce_profiles_fields()
--   currently freezes only role + email on client UPDATE, so a suspended or
--   banned user can call PATCH /rest/v1/profiles?id=eq.<self> with
--   {"account_status":"active"} and clear their own moderation state.
--
-- WHAT THIS DOES
--   1. Extends public.enforce_profiles_fields() to also freeze
--      id, account_status, suspended_until and moderation_reason on
--      non-privileged UPDATE. Admin/service_role/postgres paths are unchanged.
--   2. Column-level UPDATE privileges: revokes the blanket table UPDATE from
--      anon/authenticated and re-grants UPDATE only on non-administrative
--      columns (defence in depth — a column-level REVOKE alone is ignored while
--      a table-level grant exists).
--   3. Verification queries.
--
-- SAFETY
--   - Idempotent, transactional, no DROP TABLE / TRUNCATE / DELETE.
--   - Does not touch RLS policies, notification triggers, messaging or storage.
--   - Editable profile fields (full_name, date_of_birth, gender, height_cm,
--     weight_kg, avatar_url, cover_url, bio, phone, username,
--     notification_* preferences, sharing preferences …) stay writable.
--   - public.update_my_profile(jsonb) is SECURITY DEFINER owned by postgres and
--     already uses a column allow-list, so normal profile editing is unaffected.
--
-- RUN: paste into Supabase SQL Editor. Do NOT run `supabase db push`.
-- ---------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Dependency guard — fail loudly instead of silently creating something new.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regprocedure('public.enforce_profiles_fields()') IS NULL THEN
    RAISE EXCEPTION 'Missing dependency: public.enforce_profiles_fields()';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_profiles_enforce_fields'
      AND tgrelid = 'public.profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Missing dependency: trigger trg_profiles_enforce_fields on public.profiles';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1) Freeze administrative / moderation columns for non-privileged UPDATE.
--    Body kept identical to the deployed version except the new freezes.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_profiles_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_jwt_role TEXT;
  v_incomplete BOOLEAN;
BEGIN
  BEGIN
    v_jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN
    v_jwt_role := NULL;
  END;

  v_incomplete := (OLD.username IS NULL OR length(trim(OLD.username)) = 0);

  -- Trusted paths (service_role, postgres, superuser, SECURITY DEFINER RPCs
  -- owned by postgres) keep full control, including moderation fields.
  IF v_jwt_role = 'service_role'
     OR current_user = 'postgres'
     OR (SELECT COALESCE(usesuper, false) FROM pg_user WHERE usename = current_user LIMIT 1) THEN
    IF NEW.username IS DISTINCT FROM OLD.username THEN
      IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
      END IF;
      NEW.username_lower := lower(NEW.username);
    ELSE
      NEW.username_lower := OLD.username_lower;
    END IF;
    RETURN NEW;
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated updates not allowed';
  END IF;

  -- Incomplete stubs: only trusted SECURITY DEFINER paths may finalize.
  IF v_incomplete THEN
    RAISE EXCEPTION 'Incomplete profiles must be completed via complete_cotrainr_profile';
  END IF;

  -- Complete profiles: freeze identity + role + email
  NEW.id := OLD.id;
  NEW.role := OLD.role;
  NEW.email := OLD.email;

  -- Freeze moderation state: a suspended/banned user must not self-restore.
  NEW.account_status := OLD.account_status;
  NEW.suspended_until := OLD.suspended_until;
  NEW.moderation_reason := OLD.moderation_reason;

  IF NEW.username IS DISTINCT FROM OLD.username THEN
    IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
      RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
    END IF;
    NEW.username_lower := lower(NEW.username);
  ELSE
    NEW.username_lower := OLD.username_lower;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.enforce_profiles_fields() OWNER TO postgres;

COMMENT ON FUNCTION public.enforce_profiles_fields() IS
  'BEFORE UPDATE on profiles: freezes id, role, email and moderation fields '
  '(account_status, suspended_until, moderation_reason) for client updates. '
  'service_role / postgres / superuser paths retain full control.';

-- ---------------------------------------------------------------------------
-- 2) Column-level UPDATE privileges (defence in depth).
--    A column REVOKE does not subtract from a table-level grant, so the table
--    grant is dropped and re-granted per non-administrative column.
--    NOTE: re-run this block after adding new user-editable profiles columns.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_cols text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY column_name)
  INTO v_cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'profiles'
    AND column_name NOT IN (
      'id',
      'role',
      'email',
      'account_status',
      'suspended_until',
      'moderation_reason'
    );

  IF v_cols IS NULL THEN
    RAISE EXCEPTION 'Could not resolve editable columns for public.profiles';
  END IF;

  REVOKE UPDATE ON TABLE public.profiles FROM anon;
  REVOKE UPDATE ON TABLE public.profiles FROM authenticated;

  EXECUTE format('GRANT UPDATE (%s) ON TABLE public.profiles TO authenticated', v_cols);
END $$;

-- service_role must keep unrestricted access for admin/moderation tooling.
GRANT ALL ON TABLE public.profiles TO service_role;

COMMIT;

-- ---------------------------------------------------------------------------
-- VERIFICATION (run after COMMIT)
-- ---------------------------------------------------------------------------

-- A. Trigger present and enabled ('O' = origin/enabled).
-- SELECT tgname, tgenabled
-- FROM pg_trigger
-- WHERE tgrelid = 'public.profiles'::regclass
--   AND tgname = 'trg_profiles_enforce_fields';

-- B. Function freezes moderation fields and is owned by postgres.
-- SELECT p.proname,
--        pg_get_userbyid(p.proowner) AS owner,
--        prosecdef AS security_definer,
--        position('NEW.account_status := OLD.account_status' in pg_get_functiondef(p.oid)) > 0
--          AS freezes_account_status,
--        position('NEW.suspended_until := OLD.suspended_until' in pg_get_functiondef(p.oid)) > 0
--          AS freezes_suspended_until,
--        position('NEW.moderation_reason := OLD.moderation_reason' in pg_get_functiondef(p.oid)) > 0
--          AS freezes_moderation_reason
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND p.proname = 'enforce_profiles_fields';

-- C. No table-level UPDATE grant remains for anon/authenticated.
-- SELECT grantee, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE table_schema = 'public'
--   AND table_name = 'profiles'
--   AND privilege_type = 'UPDATE'
--   AND grantee IN ('anon', 'authenticated');
-- Expected: 0 rows.

-- D. Administrative columns are NOT column-updatable by authenticated.
-- SELECT column_name, grantee
-- FROM information_schema.column_privileges
-- WHERE table_schema = 'public'
--   AND table_name = 'profiles'
--   AND privilege_type = 'UPDATE'
--   AND grantee IN ('anon', 'authenticated')
--   AND column_name IN ('id','role','email','account_status','suspended_until','moderation_reason');
-- Expected: 0 rows.

-- E. Normal editable columns ARE column-updatable by authenticated.
-- SELECT column_name
-- FROM information_schema.column_privileges
-- WHERE table_schema = 'public'
--   AND table_name = 'profiles'
--   AND privilege_type = 'UPDATE'
--   AND grantee = 'authenticated'
--   AND column_name IN ('full_name','date_of_birth','gender','height_cm','weight_kg','avatar_url','notification_push')
-- ORDER BY column_name;
-- Expected: all of the listed columns present in your schema.

-- F. Negative test as a normal signed-in user (should not change the row):
-- UPDATE public.profiles SET account_status = 'active' WHERE id = auth.uid();
-- Expected: ERROR permission denied for table/column, or 0 effective change.
