-- Video session names, notifications, device tokens, and reminder dispatch payloads.
-- Canonical membership: video_session_participants (no video_sessions.client_id).
-- Reuses public.notifications + public.device_tokens + send-push-notification.

-- ---------------------------------------------------------------------------
-- Device tokens (may be missing on hosted DB even if older migration exists)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own device tokens" ON public.device_tokens;
CREATE POLICY "Users can insert own device tokens"
  ON public.device_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own device tokens" ON public.device_tokens;
CREATE POLICY "Users can update own device tokens"
  ON public.device_tokens FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own device tokens" ON public.device_tokens;
CREATE POLICY "Users can delete own device tokens"
  ON public.device_tokens FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own device tokens" ON public.device_tokens;
CREATE POLICY "Users can read own device tokens"
  ON public.device_tokens FOR SELECT
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Reminder job tables (idempotent with 20260820)
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Display name: never invent "your session partner" when a profile exists
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.profile_display_name(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    NULLIF(BTRIM(full_name), ''),
    NULLIF(BTRIM(username), '')
  )
  FROM public.profiles
  WHERE id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION public.video_session_when_label(p_start TIMESTAMPTZ)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT TRIM(to_char(p_start AT TIME ZONE 'UTC', 'DD Mon at HH12:MI AM')) || ' UTC';
$$;

-- ---------------------------------------------------------------------------
-- One-query session list with counterpart names (bypasses profiles RLS)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_my_video_sessions()
RETURNS TABLE (
  id UUID,
  host_id UUID,
  provider TEXT,
  title TEXT,
  description TEXT,
  scheduled_start TIMESTAMPTZ,
  duration_minutes INTEGER,
  max_participants INTEGER,
  status TEXT,
  join_url TEXT,
  provider_meeting_id TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  counterpart_name TEXT,
  participant_names TEXT[],
  participant_count INTEGER,
  name_resolution_status TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH visible AS (
    SELECT s.*
    FROM public.video_sessions s
    WHERE s.host_id = v_me
       OR EXISTS (
         SELECT 1
         FROM public.video_session_participants p
         WHERE p.session_id = s.id
           AND p.user_id = v_me
       )
  ),
  member_ids AS (
    SELECT
      v.id AS session_id,
      ARRAY_REMOVE(
        ARRAY_AGG(p.user_id ORDER BY p.user_id)
          FILTER (WHERE p.role = 'participant' AND p.user_id IS DISTINCT FROM v.host_id),
        NULL
      ) AS user_ids
    FROM visible v
    LEFT JOIN public.video_session_participants p
      ON p.session_id = v.id
    GROUP BY v.id
  )
  SELECT
    v.id,
    v.host_id,
    v.provider,
    v.title,
    v.description,
    v.scheduled_start,
    v.duration_minutes,
    v.max_participants,
    v.status,
    v.join_url,
    v.provider_meeting_id,
    v.created_at,
    v.updated_at,
    names.counterpart_name,
    names.participant_names,
    names.participant_count,
    names.name_resolution_status
  FROM visible v
  JOIN member_ids m ON m.session_id = v.id
  CROSS JOIN LATERAL (
    SELECT
      CASE
        WHEN v.host_id = v_me THEN
          COALESCE(
            (
              SELECT ARRAY_AGG(n.nm ORDER BY n.ord)
              FROM (
                SELECT COALESCE(
                         NULLIF(BTRIM(pr.full_name), ''),
                         NULLIF(BTRIM(pr.username), '')
                       ) AS nm,
                       u.ord
                FROM unnest(COALESCE(m.user_ids, ARRAY[]::uuid[])) WITH ORDINALITY AS u(uid, ord)
                LEFT JOIN public.profiles pr ON pr.id = u.uid
              ) n
              WHERE n.nm IS NOT NULL
            ),
            ARRAY[]::text[]
          )
        ELSE
          COALESCE(
            ARRAY(
              SELECT COALESCE(
                       NULLIF(BTRIM(pr.full_name), ''),
                       NULLIF(BTRIM(pr.username), '')
                     )
              FROM public.profiles pr
              WHERE pr.id = v.host_id
                AND COALESCE(
                      NULLIF(BTRIM(pr.full_name), ''),
                      NULLIF(BTRIM(pr.username), '')
                    ) IS NOT NULL
            ),
            ARRAY[]::text[]
          )
      END AS participant_names,
      CASE
        WHEN v.host_id = v_me THEN COALESCE(cardinality(m.user_ids), 0)
        ELSE 1
      END AS participant_count,
      CASE
        WHEN v.host_id = v_me THEN
          COALESCE(
            (
              SELECT COALESCE(
                       NULLIF(BTRIM(pr.full_name), ''),
                       NULLIF(BTRIM(pr.username), '')
                     )
              FROM unnest(COALESCE(m.user_ids, ARRAY[]::uuid[])) AS uid
              LEFT JOIN public.profiles pr ON pr.id = uid
              WHERE COALESCE(
                      NULLIF(BTRIM(pr.full_name), ''),
                      NULLIF(BTRIM(pr.username), '')
                    ) IS NOT NULL
              LIMIT 1
            ),
            NULL
          )
        ELSE
          (
            SELECT COALESCE(
                     NULLIF(BTRIM(pr.full_name), ''),
                     NULLIF(BTRIM(pr.username), '')
                   )
            FROM public.profiles pr
            WHERE pr.id = v.host_id
          )
      END AS counterpart_name,
      CASE
        WHEN v.host_id IS NULL THEN 'missing_host'
        WHEN v.host_id = v_me AND COALESCE(cardinality(m.user_ids), 0) = 0 THEN 'missing_participant'
        WHEN v.host_id = v_me AND NOT EXISTS (
          SELECT 1
          FROM unnest(COALESCE(m.user_ids, ARRAY[]::uuid[])) AS uid
          JOIN public.profiles pr ON pr.id = uid
          WHERE COALESCE(NULLIF(BTRIM(pr.full_name), ''), NULLIF(BTRIM(pr.username), '')) IS NOT NULL
        ) THEN 'missing_profile'
        WHEN v.host_id <> v_me AND NOT EXISTS (
          SELECT 1 FROM public.profiles pr
          WHERE pr.id = v.host_id
        ) THEN 'missing_profile'
        WHEN v.host_id <> v_me AND NOT EXISTS (
          SELECT 1 FROM public.profiles pr
          WHERE pr.id = v.host_id
            AND COALESCE(NULLIF(BTRIM(pr.full_name), ''), NULLIF(BTRIM(pr.username), '')) IS NOT NULL
        ) THEN 'missing_profile'
        ELSE 'ok'
      END AS name_resolution_status
  ) names
  ORDER BY v.scheduled_start DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_video_session(p_session_id UUID)
RETURNS TABLE (
  id UUID,
  host_id UUID,
  provider TEXT,
  title TEXT,
  description TEXT,
  scheduled_start TIMESTAMPTZ,
  duration_minutes INTEGER,
  max_participants INTEGER,
  status TEXT,
  join_url TEXT,
  provider_meeting_id TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  counterpart_name TEXT,
  participant_names TEXT[],
  participant_count INTEGER,
  name_resolution_status TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.list_my_video_sessions() s
  WHERE s.id = p_session_id;
$$;

REVOKE ALL ON FUNCTION public.list_my_video_sessions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_video_session(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_video_sessions() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_video_session(UUID) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Notification insert + jobs (replace 20260820 variants)
-- ---------------------------------------------------------------------------
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

DROP FUNCTION IF EXISTS public.notify_video_session_created(UUID);
CREATE FUNCTION public.notify_video_session_created(p_session_id UUID)
RETURNS TABLE (
  notification_id UUID,
  recipient_user_id UUID,
  push_title TEXT,
  push_body TEXT,
  payload JSONB
)
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
  v_id UUID;
  r RECORD;
  v_body TEXT;
  v_data JSONB;
BEGIN
  SELECT vs.host_id, vs.scheduled_start, vs.join_url, vs.title
    INTO v_host, v_start, v_join, v_title
  FROM public.video_sessions vs
  WHERE vs.id = p_session_id AND vs.status = 'scheduled';

  IF v_host IS NULL THEN
    RETURN;
  END IF;

  v_host_name := public.profile_display_name(v_host);
  IF v_host_name IS NULL OR BTRIM(v_host_name) = '' THEN
    RAISE NOTICE 'notify_video_session_created missing host profile name host_id=%', v_host;
    v_host_name := 'Your trainer';
  END IF;

  v_when := public.video_session_when_label(v_start);
  PERFORM public.schedule_video_session_notification_jobs(p_session_id);

  FOR r IN
    SELECT p.user_id
    FROM public.video_session_participants p
    WHERE p.session_id = p_session_id
      AND p.role = 'participant'
      AND p.user_id <> v_host
  LOOP
    v_body := v_host_name || ' scheduled a session with you for ' || v_when || '.';
    v_data := jsonb_build_object(
      'type', 'video_session_created',
      'video_session_id', p_session_id,
      'scheduled_start', v_start,
      'host_id', v_host,
      'host_name', v_host_name,
      'counterpart_name', v_host_name,
      'join_url', v_join,
      'session_title', v_title
    );
    v_id := public._insert_video_session_notification(
      r.user_id,
      p_session_id,
      'created',
      'New video session',
      v_body,
      v_data
    );
    IF v_id IS NOT NULL THEN
      notification_id := v_id;
      recipient_user_id := r.user_id;
      push_title := 'New video session';
      push_body := v_body;
      payload := v_data;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS public.notify_video_session_rescheduled(UUID);
CREATE FUNCTION public.notify_video_session_rescheduled(p_session_id UUID)
RETURNS TABLE (
  notification_id UUID,
  recipient_user_id UUID,
  push_title TEXT,
  push_body TEXT,
  payload JSONB
)
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
  v_id UUID;
  r RECORD;
  v_body TEXT;
  v_data JSONB;
BEGIN
  SELECT vs.host_id, vs.scheduled_start, vs.join_url, vs.title
    INTO v_host, v_start, v_join, v_title
  FROM public.video_sessions vs
  WHERE vs.id = p_session_id AND vs.status = 'scheduled';

  IF v_host IS NULL THEN
    RETURN;
  END IF;

  v_host_name := COALESCE(public.profile_display_name(v_host), 'Your trainer');
  v_when := public.video_session_when_label(v_start);
  PERFORM public.schedule_video_session_notification_jobs(p_session_id);

  DELETE FROM public.video_session_notification_log
  WHERE session_id = p_session_id
    AND kind IN ('reminder_5m', 'starting');

  FOR r IN
    SELECT p.user_id
    FROM public.video_session_participants p
    WHERE p.session_id = p_session_id
      AND p.role = 'participant'
      AND p.user_id <> v_host
  LOOP
    v_body := v_host_name || ' moved your session to ' || v_when || '.';
    v_data := jsonb_build_object(
      'type', 'video_session_rescheduled',
      'video_session_id', p_session_id,
      'scheduled_start', v_start,
      'host_id', v_host,
      'host_name', v_host_name,
      'counterpart_name', v_host_name,
      'join_url', v_join,
      'session_title', v_title
    );
    v_id := public._insert_video_session_notification(
      r.user_id, p_session_id, 'rescheduled', 'Session rescheduled', v_body, v_data
    );
    IF v_id IS NOT NULL THEN
      notification_id := v_id;
      recipient_user_id := r.user_id;
      push_title := 'Session rescheduled';
      push_body := v_body;
      payload := v_data;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS public.notify_video_session_cancelled(UUID);
CREATE FUNCTION public.notify_video_session_cancelled(p_session_id UUID)
RETURNS TABLE (
  notification_id UUID,
  recipient_user_id UUID,
  push_title TEXT,
  push_body TEXT,
  payload JSONB
)
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
  v_id UUID;
  r RECORD;
  v_body TEXT;
  v_data JSONB;
BEGIN
  SELECT vs.host_id, vs.scheduled_start, vs.title
    INTO v_host, v_start, v_title
  FROM public.video_sessions vs
  WHERE vs.id = p_session_id;

  IF v_host IS NULL THEN
    RETURN;
  END IF;

  v_host_name := COALESCE(public.profile_display_name(v_host), 'Your trainer');
  v_when := public.video_session_when_label(v_start);
  PERFORM public.cancel_video_session_notification_jobs(p_session_id);

  FOR r IN
    SELECT p.user_id
    FROM public.video_session_participants p
    WHERE p.session_id = p_session_id
      AND p.role = 'participant'
      AND p.user_id <> v_host
  LOOP
    v_body := v_host_name || ' cancelled your video session scheduled for ' || v_when || '.';
    v_data := jsonb_build_object(
      'type', 'video_session_cancelled',
      'video_session_id', p_session_id,
      'scheduled_start', v_start,
      'host_id', v_host,
      'host_name', v_host_name,
      'counterpart_name', v_host_name,
      'session_title', v_title
    );
    v_id := public._insert_video_session_notification(
      r.user_id, p_session_id, 'cancelled', 'Session cancelled', v_body, v_data
    );
    IF v_id IS NOT NULL THEN
      notification_id := v_id;
      recipient_user_id := r.user_id;
      push_title := 'Session cancelled';
      push_body := v_body;
      payload := v_data;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS public.dispatch_video_session_notification_jobs();
CREATE FUNCTION public.dispatch_video_session_notification_jobs()
RETURNS TABLE (
  notification_id UUID,
  recipient_user_id UUID,
  push_title TEXT,
  push_body TEXT,
  payload JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  job RECORD;
  sess RECORD;
  r RECORD;
  v_kind TEXT;
  v_title TEXT;
  v_body TEXT;
  v_counterpart TEXT;
  v_when TEXT;
  v_id UUID;
  v_data JSONB;
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
        SELECT string_agg(nm, ', ' ORDER BY nm)
          INTO v_counterpart
        FROM (
          SELECT public.profile_display_name(p.user_id) AS nm
          FROM public.video_session_participants p
          WHERE p.session_id = sess.id AND p.role = 'participant'
        ) x
        WHERE nm IS NOT NULL AND BTRIM(nm) <> '';
      ELSE
        v_counterpart := public.profile_display_name(sess.host_id);
      END IF;

      IF v_counterpart IS NULL OR BTRIM(v_counterpart) = '' THEN
        CONTINUE;
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

      v_data := jsonb_build_object(
        'type', 'video_session_' || v_kind,
        'video_session_id', sess.id,
        'scheduled_start', sess.scheduled_start,
        'host_id', sess.host_id,
        'counterpart_name', v_counterpart,
        'join_url', sess.join_url,
        'session_title', sess.title,
        'duration_minutes', sess.duration_minutes,
        'status', sess.status,
        'actions', jsonb_build_array('join', 'dismiss')
      );

      v_id := public._insert_video_session_notification(
        r.user_id, sess.id, v_kind, v_title, v_body, v_data
      );
      IF v_id IS NOT NULL THEN
        notification_id := v_id;
        recipient_user_id := r.user_id;
        push_title := v_title;
        push_body := v_body;
        payload := v_data;
        RETURN NEXT;
      END IF;
    END LOOP;

    UPDATE public.video_session_notification_jobs
    SET sent_at = NOW()
    WHERE id = job.id;
  END LOOP;
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

-- Realtime so the home Video Sessions red dot can refresh without a restart.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object THEN
  NULL;
WHEN undefined_object THEN
  NULL;
END $$;

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
