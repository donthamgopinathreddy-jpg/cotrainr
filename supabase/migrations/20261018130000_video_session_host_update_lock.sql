-- Host update lock for video_sessions.
-- NOT APPLIED. Do not db push until remote migration history is reconciled.
--
-- Authenticated clients may update scheduling copy only. join_url, provider,
-- provider_meeting_id, host_id, status, and id are not grantable.
-- Cancellation goes through cancel_my_video_session so the existing
-- AFTER UPDATE notify trigger still runs once.
--
-- Ended provider-client connections are intentionally unchanged here.

REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.video_sessions FROM PUBLIC;
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.video_sessions FROM anon;
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.video_sessions FROM authenticated;

GRANT UPDATE (
  title,
  description,
  scheduled_start,
  duration_minutes,
  updated_at
) ON TABLE public.video_sessions TO authenticated;

DROP POLICY IF EXISTS "Hosts can delete own sessions" ON public.video_sessions;

DROP POLICY IF EXISTS "Hosts can update own active sessions" ON public.video_sessions;

CREATE POLICY "Hosts can update own active sessions"
ON public.video_sessions
FOR UPDATE
TO authenticated
USING (
  (SELECT auth.uid()) = host_id
  AND public.is_account_active()
  AND EXISTS (
    SELECT 1
    FROM public.providers p
    WHERE p.user_id = host_id
      AND p.verified IS TRUE
      AND p.provider_type IN (
        'trainer'::public.provider_type,
        'nutritionist'::public.provider_type
      )
  )
)
WITH CHECK (
  (SELECT auth.uid()) = host_id
  AND public.is_account_active()
  AND EXISTS (
    SELECT 1
    FROM public.providers p
    WHERE p.user_id = host_id
      AND p.verified IS TRUE
      AND p.provider_type IN (
        'trainer'::public.provider_type,
        'nutritionist'::public.provider_type
      )
  )
);

CREATE OR REPLACE FUNCTION public.enforce_verified_video_session_host()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- A revoked host may cancel, and only cancel. Any other column change
  -- still requires a verified trainer or nutritionist host.
  IF TG_OP = 'UPDATE'
     AND OLD.host_id IS NOT DISTINCT FROM NEW.host_id
     AND OLD.id IS NOT DISTINCT FROM NEW.id
     AND OLD.created_at IS NOT DISTINCT FROM NEW.created_at
     AND OLD.join_url IS NOT DISTINCT FROM NEW.join_url
     AND OLD.provider IS NOT DISTINCT FROM NEW.provider
     AND OLD.provider_meeting_id IS NOT DISTINCT FROM NEW.provider_meeting_id
     AND OLD.title IS NOT DISTINCT FROM NEW.title
     AND OLD.description IS NOT DISTINCT FROM NEW.description
     AND OLD.scheduled_start IS NOT DISTINCT FROM NEW.scheduled_start
     AND OLD.duration_minutes IS NOT DISTINCT FROM NEW.duration_minutes
     AND OLD.max_participants IS NOT DISTINCT FROM NEW.max_participants
     AND OLD.status = 'scheduled'
     AND NEW.status = 'cancelled'
  THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.providers p
    WHERE p.user_id = NEW.host_id
      AND p.verified IS TRUE
      AND p.provider_type IN (
        'trainer'::public.provider_type,
        'nutritionist'::public.provider_type
      )
  ) THEN
    RAISE EXCEPTION 'Video session host must be a verified provider'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_sessions_require_verified_host ON public.video_sessions;

CREATE TRIGGER trg_video_sessions_require_verified_host
BEFORE INSERT OR UPDATE ON public.video_sessions
FOR EACH ROW
EXECUTE FUNCTION public.enforce_verified_video_session_host();

REVOKE ALL ON FUNCTION public.enforce_verified_video_session_host()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cancel_my_video_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_host uuid;
  v_status text;
  v_updated integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_account_active() THEN
    RAISE EXCEPTION 'account_restricted' USING ERRCODE = '42501';
  END IF;

  IF p_session_id IS NULL THEN
    RAISE EXCEPTION 'session_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.host_id, s.status
    INTO v_host, v_status
  FROM public.video_sessions s
  WHERE s.id = p_session_id
  FOR UPDATE;

  IF v_host IS NULL THEN
    RAISE EXCEPTION 'session_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_host IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_session_host' USING ERRCODE = '42501';
  END IF;

  -- Already cancelled: do not update, so the notify trigger does not fire again.
  IF v_status = 'cancelled' THEN
    RETURN;
  END IF;

  IF v_status IS DISTINCT FROM 'scheduled' THEN
    RAISE EXCEPTION 'session_not_cancellable' USING ERRCODE = '22023';
  END IF;

  UPDATE public.video_sessions
  SET status = 'cancelled',
      updated_at = now()
  WHERE id = p_session_id
    AND host_id = v_uid
    AND status = 'scheduled';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 1 THEN
    RETURN;
  END IF;

  SELECT s.status
    INTO v_status
  FROM public.video_sessions s
  WHERE s.id = p_session_id
    AND s.host_id = v_uid;

  IF v_status = 'cancelled' THEN
    RETURN;
  END IF;

  RAISE EXCEPTION 'session_not_cancellable' USING ERRCODE = '22023';
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_my_video_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_my_video_session(uuid) TO authenticated;

COMMENT ON FUNCTION public.cancel_my_video_session(uuid) IS
  'Host cancellation bound to auth.uid(). Idempotent when already cancelled. Does not require providers.verified. Status change is what fires trg_video_sessions_notify_update.';
