-- Participant attendance responses + actionable 5m/start reminders.
-- Does NOT cancel the session when one member rejects.
-- Canonical membership remains video_session_participants (no client_id).

-- ---------------------------------------------------------------------------
-- Attendance on the existing participant row (no extra table)
-- ---------------------------------------------------------------------------
ALTER TABLE public.video_session_participants
  ADD COLUMN IF NOT EXISTS response_status TEXT NOT NULL DEFAULT 'pending';

ALTER TABLE public.video_session_participants
  DROP CONSTRAINT IF EXISTS video_session_participants_response_status_check;

ALTER TABLE public.video_session_participants
  ADD CONSTRAINT video_session_participants_response_status_check
  CHECK (response_status IN ('pending', 'accepted', 'rejected'));

ALTER TABLE public.video_session_participants
  ADD COLUMN IF NOT EXISTS response_reason TEXT;

ALTER TABLE public.video_session_participants
  ADD COLUMN IF NOT EXISTS response_reason_code TEXT;

ALTER TABLE public.video_session_participants
  ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;

-- Clients cannot UPDATE participants under RLS; mutations go through RPC.

-- ---------------------------------------------------------------------------
-- List/detail RPCs: include my + counterpart attendance
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_my_video_session(UUID);
DROP FUNCTION IF EXISTS public.list_my_video_sessions();

CREATE FUNCTION public.list_my_video_sessions()
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
  name_resolution_status TEXT,
  my_response_status TEXT,
  my_response_reason TEXT,
  my_responded_at TIMESTAMPTZ,
  counterpart_response_status TEXT,
  counterpart_response_reason TEXT
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
    names.name_resolution_status,
    COALESCE(mine.response_status, 'pending'),
    COALESCE(mine.response_reason, NULL),
    mine.responded_at,
    CASE
      WHEN v.host_id = v_me THEN otherp.response_status
      ELSE hostp.response_status
    END,
    CASE
      WHEN v.host_id = v_me THEN otherp.response_reason
      ELSE hostp.response_reason
    END
  FROM visible v
  JOIN member_ids m ON m.session_id = v.id
  LEFT JOIN public.video_session_participants mine
    ON mine.session_id = v.id AND mine.user_id = v_me
  LEFT JOIN public.video_session_participants hostp
    ON hostp.session_id = v.id AND hostp.user_id = v.host_id
  LEFT JOIN LATERAL (
    SELECT p.response_status, p.response_reason
    FROM public.video_session_participants p
    WHERE p.session_id = v.id
      AND p.role = 'participant'
      AND p.user_id IS DISTINCT FROM v.host_id
    ORDER BY p.created_at
    LIMIT 1
  ) otherp ON TRUE
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

CREATE FUNCTION public.get_my_video_session(p_session_id UUID)
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
  name_resolution_status TEXT,
  my_response_status TEXT,
  my_response_reason TEXT,
  my_responded_at TIMESTAMPTZ,
  counterpart_response_status TEXT,
  counterpart_response_reason TEXT
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
-- Reason label helper
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.video_session_reject_reason_label(
  p_reason_code TEXT,
  p_reason_text TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_reason_code
    WHEN 'cant_attend' THEN 'Can''t attend'
    WHEN 'running_late' THEN 'Running late'
    WHEN 'need_to_reschedule' THEN 'Need to reschedule'
    WHEN 'emergency' THEN 'Emergency'
    WHEN 'other' THEN COALESCE(NULLIF(BTRIM(p_reason_text), ''), 'Other')
    ELSE COALESCE(NULLIF(BTRIM(p_reason_text), ''), 'Can''t attend')
  END;
$$;

-- ---------------------------------------------------------------------------
-- Reminders: skip rejected members; keep job idempotency (sent_at + log PK)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_video_session_notification_jobs()
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
      SELECT p.user_id, p.role, COALESCE(p.response_status, 'pending') AS response_status
      FROM public.video_session_participants p
      WHERE p.session_id = sess.id
    LOOP
      IF r.response_status = 'rejected' THEN
        CONTINUE;
      END IF;

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
        v_counterpart := CASE
          WHEN r.role = 'host' OR r.user_id = sess.host_id THEN 'your client'
          ELSE 'your trainer'
        END;
      END IF;

      IF job.kind = 'reminder_5m' THEN
        v_kind := 'reminder_5m';
        v_title := 'Video session in 5 minutes';
        v_body := 'Your session with ' || v_counterpart || ' starts at ' || v_when || '.';
      ELSE
        v_kind := 'starting';
        v_title := 'Video session starting now';
        v_body := 'Your session with ' || v_counterpart || ' is ready.';
      END IF;

      v_data := jsonb_build_object(
        'type', 'video_session_' || v_kind,
        'notification_type', 'video_session_' || v_kind,
        'video_session_id', sess.id,
        'scheduled_start', sess.scheduled_start,
        'host_id', sess.host_id,
        'counterpart_name', v_counterpart,
        'join_url', sess.join_url,
        'session_title', sess.title,
        'duration_minutes', sess.duration_minutes,
        'status', sess.status,
        'actions', jsonb_build_array('join', 'reject')
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

-- Map rejected* log keys to type video_session_rejected (change-response uniques).
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
  v_type TEXT;
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

  v_type := 'video_session_' || CASE
    WHEN p_kind LIKE 'rejected%' THEN 'rejected'
    WHEN p_kind = 'reminder_5m' THEN 'reminder_5m'
    WHEN p_kind = 'starting' THEN 'starting'
    ELSE p_kind
  END;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, v_type, p_title, p_body, p_data)
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

-- ---------------------------------------------------------------------------
-- Reject / attendance response (auth.uid() is the only actor)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_video_session(
  p_session_id UUID,
  p_response_status TEXT,
  p_reason_code TEXT DEFAULT NULL,
  p_reason_text TEXT DEFAULT NULL
)
RETURNS TABLE (
  notification_id UUID,
  recipient_user_id UUID,
  push_title TEXT,
  push_body TEXT,
  payload JSONB,
  snackbar_role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_role TEXT;
  v_prev_status TEXT;
  v_prev_code TEXT;
  v_prev_text TEXT;
  sess RECORD;
  v_actor_name TEXT;
  v_reason_label TEXT;
  v_reason_text TEXT;
  v_id UUID;
  r RECORD;
  v_log_kind TEXT;
  v_title TEXT;
  v_body TEXT;
  v_data JSONB;
  v_snack TEXT;
  v_notified BOOLEAN := FALSE;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_response_status IS DISTINCT FROM 'rejected' THEN
    RAISE EXCEPTION 'invalid_response_status' USING ERRCODE = '22023';
  END IF;

  IF p_reason_code IS NULL OR p_reason_code NOT IN (
    'cant_attend', 'running_late', 'need_to_reschedule', 'emergency', 'other'
  ) THEN
    RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
  END IF;

  v_reason_text := NULLIF(BTRIM(COALESCE(p_reason_text, '')), '');
  IF p_reason_code = 'other' AND v_reason_text IS NOT NULL THEN
    v_reason_text := left(v_reason_text, 200);
  ELSIF p_reason_code <> 'other' THEN
    v_reason_text := NULL;
  END IF;

  SELECT s.id, s.host_id, s.scheduled_start, s.status, s.join_url, s.title, s.duration_minutes
    INTO sess
  FROM public.video_sessions s
  WHERE s.id = p_session_id;

  IF sess.id IS NULL THEN
    RAISE EXCEPTION 'session_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF sess.status IS DISTINCT FROM 'scheduled' THEN
    RAISE EXCEPTION 'session_not_scheduled' USING ERRCODE = '22023';
  END IF;

  SELECT p.role, COALESCE(p.response_status, 'pending'), p.response_reason_code, p.response_reason
    INTO v_role, v_prev_status, v_prev_code, v_prev_text
  FROM public.video_session_participants p
  WHERE p.session_id = p_session_id
    AND p.user_id = v_me;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'not_a_participant' USING ERRCODE = '42501';
  END IF;

  -- Duplicate identical submit: no extra notification.
  IF v_prev_status = 'rejected'
     AND v_prev_code IS NOT DISTINCT FROM p_reason_code
     AND v_prev_text IS NOT DISTINCT FROM v_reason_text THEN
    RETURN;
  END IF;

  UPDATE public.video_session_participants
  SET response_status = 'rejected',
      response_reason_code = p_reason_code,
      response_reason = public.video_session_reject_reason_label(p_reason_code, v_reason_text),
      responded_at = NOW()
  WHERE session_id = p_session_id
    AND user_id = v_me;

  v_actor_name := COALESCE(public.profile_display_name(v_me), 'Someone');
  v_reason_label := public.video_session_reject_reason_label(p_reason_code, v_reason_text);
  v_snack := CASE WHEN v_role = 'host' OR v_me = sess.host_id THEN 'client' ELSE 'trainer' END;

  IF v_prev_status = 'rejected' THEN
    v_log_kind := 'rejected:' || p_reason_code || ':' || floor(extract(epoch FROM clock_timestamp()))::text;
  ELSE
    v_log_kind := 'rejected';
  END IF;

  v_title := v_actor_name || ' can''t attend';
  v_body := 'Reason: ' || v_reason_label;
  v_data := jsonb_build_object(
    'type', 'video_session_rejected',
    'notification_type', 'video_session_rejected',
    'video_session_id', sess.id,
    'scheduled_start', sess.scheduled_start,
    'host_id', sess.host_id,
    'actor_id', v_me,
    'actor_name', v_actor_name,
    'counterpart_name', v_actor_name,
    'reason_code', p_reason_code,
    'reason_label', v_reason_label,
    'session_title', sess.title,
    'join_url', sess.join_url,
    'status', sess.status
  );

  FOR r IN
    SELECT p.user_id
    FROM public.video_session_participants p
    WHERE p.session_id = p_session_id
      AND p.user_id <> v_me
  LOOP
    v_id := public._insert_video_session_notification(
      r.user_id,
      p_session_id,
      v_log_kind,
      v_title,
      v_body,
      v_data
    );
    IF v_id IS NOT NULL THEN
      v_notified := TRUE;
      notification_id := v_id;
      recipient_user_id := r.user_id;
      push_title := v_title;
      push_body := v_body;
      payload := v_data;
      snackbar_role := v_snack;
      RETURN NEXT;
    END IF;
  END LOOP;

  IF NOT v_notified THEN
    snackbar_role := v_snack;
    RETURN NEXT;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.respond_to_video_session(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_to_video_session(UUID, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_video_session_notification_jobs() TO service_role;
GRANT EXECUTE ON FUNCTION public._insert_video_session_notification(UUID, UUID, TEXT, TEXT, TEXT, JSONB) TO service_role;
