-- Cotrainr — Notification security hardening (Android MVP P0).
--
-- Problem
-- -------
-- public.create_notification(p_user_id, p_type, p_title, p_body, p_data) was
-- created in 20250213_notification_system.sql as a SECURITY DEFINER RPC that
-- inserts straight into public.notifications with a caller-supplied target
-- user id. Because Supabase grants EXECUTE on new functions to PUBLIC by
-- default, any signed-in (or anonymous) client holding the anon key could
-- fabricate notifications for arbitrary users — spoofed lead requests,
-- spoofed video-session invites, phishing bodies with attacker-controlled
-- deep-link payloads.
--
-- Decision
-- --------
-- No Flutter code calls create_notification. Every production notification is
-- written by a database trigger, by a SECURITY DEFINER RPC with an explicit
-- relationship check, or by service_role server code (Edge Functions / cron).
-- Client roles therefore lose EXECUTE entirely; the function stays for
-- trigger/service_role/internal use.
--
-- Idempotent: safe to re-run.

BEGIN;

-- 1. Re-declare the function with a defence-in-depth actor check so a future
--    accidental GRANT cannot re-open arbitrary-target notification creation.
--    CREATE OR REPLACE preserves the existing owner; grants are reset below.
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id UUID;
  v_role TEXT;
BEGIN
  -- auth.role() is 'anon'/'authenticated' for client calls and NULL (or
  -- 'service_role') for trigger, cron and service-role server calls.
  BEGIN
    v_role := auth.role();
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;

  IF v_role IN ('anon', 'authenticated') THEN
    RAISE EXCEPTION
      'create_notification is not callable by client roles'
      USING ERRCODE = '42501';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'create_notification requires p_user_id'
      USING ERRCODE = '22004';
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- 2. Deny client execution. Notifications must originate from trusted paths.
REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB)
  FROM anon;
REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB)
  FROM authenticated;

-- 3. Preserve the trusted server path only.
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB)
  TO service_role;

COMMENT ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB) IS
  'Internal notification writer. NOT client-callable: EXECUTE is revoked from '
  'anon/authenticated/PUBLIC because p_user_id is caller-supplied and would '
  'allow spoofing notifications for arbitrary users. Use database triggers, a '
  'purpose-built RPC with a relationship check, or service_role server code.';

COMMIT;
