-- Video session notification category prefs + member avatars for list/detail.
-- Does not change Google Meet creation or attendance columns.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_video_sessions BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_video_session_reminders BOOLEAN NOT NULL DEFAULT true;

DROP FUNCTION IF EXISTS public.get_notification_push(uuid);

CREATE FUNCTION public.get_notification_push(p_user_id uuid)
RETURNS TABLE (
  notification_push boolean,
  notification_video_sessions boolean,
  notification_video_session_reminders boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(p.notification_push, true),
    COALESCE(p.notification_video_sessions, true),
    COALESCE(p.notification_video_session_reminders, true)
  FROM public.profiles p
  WHERE p.id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_notification_push(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_notification_push(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.video_session_notification_pref_allows(
  p_user_id UUID,
  p_type TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_type IN ('video_session_reminder_5m', 'video_session_starting') THEN
      COALESCE(
        (SELECT notification_video_session_reminders FROM public.profiles WHERE id = p_user_id),
        true
      )
    WHEN p_type LIKE 'video_session_%' THEN
      COALESCE(
        (SELECT notification_video_sessions FROM public.profiles WHERE id = p_user_id),
        true
      )
    ELSE true
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

  -- Claim idempotency even when the user opted out, so dispatch does not retry.
  IF NOT public.video_session_notification_pref_allows(p_user_id, v_type) THEN
    RETURN NULL;
  END IF;

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

-- People on sessions the caller can see (names + avatars via SECURITY DEFINER).
CREATE OR REPLACE FUNCTION public.list_my_video_session_people()
RETURNS TABLE (
  session_id UUID,
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  role TEXT
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
  SELECT
    p.session_id,
    p.user_id,
    COALESCE(
      NULLIF(BTRIM(pr.full_name), ''),
      NULLIF(BTRIM(pr.username), ''),
      ''
    ),
    pr.avatar_url,
    p.role
  FROM public.video_session_participants p
  JOIN public.video_sessions s ON s.id = p.session_id
  LEFT JOIN public.profiles pr ON pr.id = p.user_id
  WHERE s.host_id = v_me
     OR EXISTS (
       SELECT 1
       FROM public.video_session_participants mine
       WHERE mine.session_id = s.id
         AND mine.user_id = v_me
     );
END;
$$;

REVOKE ALL ON FUNCTION public.list_my_video_session_people() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_video_session_people() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._insert_video_session_notification(UUID, UUID, TEXT, TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.video_session_notification_pref_allows(UUID, TEXT) TO service_role;
