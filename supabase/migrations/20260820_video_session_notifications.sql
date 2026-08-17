-- Video session notifications, unread activity, and server-side reminder jobs.
-- Canonical times are timestamptz (UTC). Do not use device clocks.
-- Membership is video_session_participants (no video_sessions.client_id).

CREATE TABLE IF NOT EXISTS public.video_session_notification_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.video_sessions(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('reminder_5m', 'starting')),
  fire_at TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (session_id, kind)
);

CREATE INDEX IF NOT EXISTS idx_vs_notif_jobs_due
  ON public.video_session_notification_jobs (fire_at)
  WHERE sent_at IS NULL AND cancelled_at IS NULL;

CREATE TABLE IF NOT EXISTS public.video_session_notification_log (
  session_id UUID NOT NULL REFERENCES public.video_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  notification_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (session_id, user_id, kind)
);

ALTER TABLE public.video_session_notification_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_session_notification_log ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.video_session_notification_jobs IS
  'Server-side 5-minute and start-time notification jobs. Edge/service_role only.';
COMMENT ON TABLE public.video_session_notification_log IS
  'Idempotency log for video-session notifications. Edge/service_role only.';

CREATE OR REPLACE FUNCTION public.profile_display_name(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(NULLIF(BTRIM(full_name), ''), 'your session partner')
  FROM public.profiles
  WHERE id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION public.video_session_when_label(p_start TIMESTAMPTZ)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  -- Instant is UTC; Flutter in-app list reformats from data.scheduled_start locally.
  SELECT TRIM(to_char(p_start AT TIME ZONE 'UTC', 'DD Mon at HH12:MI AM')) || ' UTC';
$$;

CREATE OR REPLACE FUNCTION public.cancel_video_session_notification_jobs(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.video_session_notification_jobs
  SET cancelled_at = NOW()
  WHERE session_id = p_session_id
    AND sent_at IS NULL
    AND cancelled_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.schedule_video_session_notification_jobs(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start TIMESTAMPTZ;
  v_status TEXT;
BEGIN
  SELECT scheduled_start, status
    INTO v_start, v_status
  FROM public.video_sessions
  WHERE id = p_session_id;

  IF v_start IS NULL OR v_status IS DISTINCT FROM 'scheduled' THEN
    PERFORM public.cancel_video_session_notification_jobs(p_session_id);
    RETURN;
  END IF;

  PERFORM public.cancel_video_session_notification_jobs(p_session_id);

  INSERT INTO public.video_session_notification_jobs (session_id, kind, fire_at)
  VALUES
    (p_session_id, 'reminder_5m', v_start - INTERVAL '5 minutes'),
    (p_session_id, 'starting', v_start)
  ON CONFLICT (session_id, kind) DO UPDATE
    SET fire_at = EXCLUDED.fire_at,
        sent_at = NULL,
        cancelled_at = NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._insert_video_session_notification(
  p_user_id UUID,
  p_session_id UUID,
  p_kind TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_log_kind TEXT := p_kind;
  v_claimed UUID;
BEGIN
  -- Reschedule may fire more than once; unique log only for one-shot kinds.
  IF p_kind = 'rescheduled' THEN
    v_log_kind := 'rescheduled:' || COALESCE(p_data->>'scheduled_start', gen_random_uuid()::text);
  END IF;

  INSERT INTO public.video_session_notification_log (session_id, user_id, kind)
  VALUES (p_session_id, p_user_id, v_log_kind)
  ON CONFLICT DO NOTHING
  RETURNING session_id INTO v_claimed;

  IF v_claimed IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    p_user_id,
    'video_session_' || CASE
      WHEN p_kind = 'reminder_5m' THEN 'reminder_5m'
      WHEN p_kind = 'starting' THEN 'starting'
      ELSE p_kind
    END,
    p_title,
    p_body,
    p_data
  )
  RETURNING id INTO v_id;

  UPDATE public.video_session_notification_log
  SET notification_id = v_id
  WHERE session_id = p_session_id
    AND user_id = p_user_id
    AND kind = v_log_kind
    AND notification_id IS NULL;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_video_session_created(p_session_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host UUID;
  v_host_name TEXT;
  v_start TIMESTAMPTZ;
  v_join TEXT;
  v_title TEXT;
  v_when TEXT;
  v_count INTEGER := 0;
  r RECORD;
BEGIN
  SELECT host_id, scheduled_start, join_url, title
    INTO v_host, v_start, v_join, v_title
  FROM public.video_sessions
  WHERE id = p_session_id AND status = 'scheduled';

  IF v_host IS NULL THEN
    RETURN 0;
  END IF;

  v_host_name := public.profile_display_name(v_host);
  v_when := public.video_session_when_label(v_start);

  PERFORM public.schedule_video_session_notification_jobs(p_session_id);

  FOR r IN
    SELECT user_id
    FROM public.video_session_participants
    WHERE session_id = p_session_id
      AND role = 'participant'
      AND user_id <> v_host
  LOOP
    IF public._insert_video_session_notification(
      r.user_id,
      p_session_id,
      'created',
      'New video session',
      v_host_name || ' scheduled a session with you for ' || v_when || '.',
      jsonb_build_object(
        'type', 'video_session_created',
        'video_session_id', p_session_id,
        'scheduled_start', v_start,
        'host_id', v_host,
        'host_name', v_host_name,
        'counterpart_name', v_host_name,
        'join_url', v_join,
        'session_title', v_title
      )
    ) IS NOT NULL THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_video_session_rescheduled(p_session_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host UUID;
  v_host_name TEXT;
  v_start TIMESTAMPTZ;
  v_join TEXT;
  v_title TEXT;
  v_when TEXT;
  v_count INTEGER := 0;
  r RECORD;
BEGIN
  SELECT host_id, scheduled_start, join_url, title
    INTO v_host, v_start, v_join, v_title
  FROM public.video_sessions
  WHERE id = p_session_id AND status = 'scheduled';

  IF v_host IS NULL THEN
    RETURN 0;
  END IF;

  v_host_name := public.profile_display_name(v_host);
  v_when := public.video_session_when_label(v_start);
  PERFORM public.schedule_video_session_notification_jobs(p_session_id);

  -- Old 5m/start jobs were cancelled+rescheduled; also drop unsent reminder logs
  -- so a later reminder can send once for the new time.
  DELETE FROM public.video_session_notification_log
  WHERE session_id = p_session_id
    AND kind IN ('reminder_5m', 'starting');

  FOR r IN
    SELECT user_id
    FROM public.video_session_participants
    WHERE session_id = p_session_id
      AND role = 'participant'
      AND user_id <> v_host
  LOOP
    IF public._insert_video_session_notification(
      r.user_id,
      p_session_id,
      'rescheduled',
      'Session rescheduled',
      v_host_name || ' moved your session to ' || v_when || '.',
      jsonb_build_object(
        'type', 'video_session_rescheduled',
        'video_session_id', p_session_id,
        'scheduled_start', v_start,
        'host_id', v_host,
        'host_name', v_host_name,
        'counterpart_name', v_host_name,
        'join_url', v_join,
        'session_title', v_title
      )
    ) IS NOT NULL THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_video_session_cancelled(p_session_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host UUID;
  v_host_name TEXT;
  v_start TIMESTAMPTZ;
  v_title TEXT;
  v_when TEXT;
  v_count INTEGER := 0;
  r RECORD;
BEGIN
  SELECT host_id, scheduled_start, title
    INTO v_host, v_start, v_title
  FROM public.video_sessions
  WHERE id = p_session_id;

  IF v_host IS NULL THEN
    RETURN 0;
  END IF;

  v_host_name := public.profile_display_name(v_host);
  v_when := public.video_session_when_label(v_start);
  PERFORM public.cancel_video_session_notification_jobs(p_session_id);

  FOR r IN
    SELECT user_id
    FROM public.video_session_participants
    WHERE session_id = p_session_id
      AND role = 'participant'
      AND user_id <> v_host
  LOOP
    IF public._insert_video_session_notification(
      r.user_id,
      p_session_id,
      'cancelled',
      'Session cancelled',
      v_host_name || ' cancelled your video session scheduled for ' || v_when || '.',
      jsonb_build_object(
        'type', 'video_session_cancelled',
        'video_session_id', p_session_id,
        'scheduled_start', v_start,
        'host_id', v_host,
        'host_name', v_host_name,
        'counterpart_name', v_host_name,
        'session_title', v_title
      )
    ) IS NOT NULL THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.dispatch_video_session_notification_jobs()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER := 0;
  job RECORD;
  sess RECORD;
  r RECORD;
  v_kind TEXT;
  v_title TEXT;
  v_body TEXT;
  v_counterpart TEXT;
  v_when TEXT;
BEGIN
  FOR job IN
    SELECT j.id, j.session_id, j.kind, j.fire_at
    FROM public.video_session_notification_jobs j
    WHERE j.sent_at IS NULL
      AND j.cancelled_at IS NULL
      AND j.fire_at <= NOW() + INTERVAL '15 seconds'
    ORDER BY j.fire_at
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT s.id, s.host_id, s.scheduled_start, s.duration_minutes, s.status, s.join_url, s.title
      INTO sess
    FROM public.video_sessions s
    WHERE s.id = job.session_id;

    IF sess.id IS NULL OR sess.status IS DISTINCT FROM 'scheduled' THEN
      UPDATE public.video_session_notification_jobs
      SET cancelled_at = NOW()
      WHERE id = job.id AND sent_at IS NULL;
      CONTINUE;
    END IF;

    -- Skip 5m reminder if the session already started; skip starting if already ended.
    IF job.kind = 'reminder_5m' AND NOW() >= sess.scheduled_start THEN
      UPDATE public.video_session_notification_jobs
      SET cancelled_at = NOW()
      WHERE id = job.id AND sent_at IS NULL;
      CONTINUE;
    END IF;
    IF job.kind = 'starting'
       AND NOW() > sess.scheduled_start + make_interval(mins => sess.duration_minutes) THEN
      UPDATE public.video_session_notification_jobs
      SET cancelled_at = NOW()
      WHERE id = job.id AND sent_at IS NULL;
      CONTINUE;
    END IF;

    v_when := public.video_session_when_label(sess.scheduled_start);

    FOR r IN
      SELECT p.user_id, p.role
      FROM public.video_session_participants p
      WHERE p.session_id = sess.id
    LOOP
      IF r.role = 'host' OR r.user_id = sess.host_id THEN
        SELECT string_agg(public.profile_display_name(p.user_id), ', ' ORDER BY p.user_id)
          INTO v_counterpart
        FROM public.video_session_participants p
        WHERE p.session_id = sess.id AND p.role = 'participant';
        v_counterpart := COALESCE(NULLIF(v_counterpart, ''), 'your session partner');
      ELSE
        v_counterpart := public.profile_display_name(sess.host_id);
      END IF;

      IF job.kind = 'reminder_5m' THEN
        v_kind := 'reminder_5m';
        v_title := 'Session starts in 5 minutes';
        v_body := 'Your session with ' || v_counterpart || ' starts at ' || v_when || '.';
      ELSE
        v_kind := 'starting';
        v_title := 'Video session is ready';
        v_body := 'Your session with ' || v_counterpart || ' is starting now.';
      END IF;

      IF public._insert_video_session_notification(
        r.user_id,
        sess.id,
        v_kind,
        v_title,
        v_body,
        jsonb_build_object(
          'type', 'video_session_' || v_kind,
          'video_session_id', sess.id,
          'scheduled_start', sess.scheduled_start,
          'host_id', sess.host_id,
          'counterpart_name', v_counterpart,
          'join_url', sess.join_url,
          'session_title', sess.title,
          'actions', jsonb_build_array('join', 'dismiss')
        )
      ) IS NOT NULL THEN
        v_count := v_count + 1;
      END IF;
    END LOOP;

    UPDATE public.video_session_notification_jobs
    SET sent_at = NOW()
    WHERE id = job.id;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_video_sessions_notify_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    PERFORM public.notify_video_session_cancelled(NEW.id);
    RETURN NEW;
  END IF;

  IF NEW.status = 'scheduled'
     AND OLD.status = 'scheduled'
     AND (
       NEW.scheduled_start IS DISTINCT FROM OLD.scheduled_start
       OR NEW.duration_minutes IS DISTINCT FROM OLD.duration_minutes
     ) THEN
    PERFORM public.notify_video_session_rescheduled(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_sessions_notify_update ON public.video_sessions;
CREATE TRIGGER trg_video_sessions_notify_update
  AFTER UPDATE ON public.video_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_video_sessions_notify_update();

REVOKE ALL ON FUNCTION public.notify_video_session_created(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_video_session_rescheduled(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_video_session_cancelled(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dispatch_video_session_notification_jobs() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.schedule_video_session_notification_jobs(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_video_session_notification_jobs(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._insert_video_session_notification(UUID, UUID, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.notify_video_session_created(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.notify_video_session_rescheduled(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.notify_video_session_cancelled(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_video_session_notification_jobs() TO service_role;
GRANT EXECUTE ON FUNCTION public.schedule_video_session_notification_jobs(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_video_session_notification_jobs(UUID) TO service_role;

-- Optional pg_cron (hosted Pro). Safe no-op if extension is unavailable.
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule('cotrainr-video-session-reminders');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.schedule(
    'cotrainr-video-session-reminders',
    '* * * * *',
    $cron$SELECT public.dispatch_video_session_notification_jobs();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END $$;
