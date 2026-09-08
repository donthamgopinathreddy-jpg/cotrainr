CREATE OR REPLACE FUNCTION public.update_my_notification_preferences(
  p_push boolean,
  p_community boolean,
  p_reminders boolean,
  p_achievements boolean,
  p_video_sessions boolean DEFAULT NULL,
  p_video_session_reminders boolean DEFAULT NULL,
  p_messages boolean DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='public','pg_catalog'
AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated' USING ERRCODE='42501'; END IF;
  IF NOT public.is_account_active() THEN RAISE EXCEPTION 'account_restricted' USING ERRCODE='42501'; END IF;
  UPDATE public.profiles SET
    notification_push=p_push,
    notification_community=p_community,
    notification_reminders=p_reminders,
    notification_achievements=p_achievements,
    notification_video_sessions=COALESCE(p_video_sessions,notification_video_sessions),
    notification_video_session_reminders=COALESCE(p_video_session_reminders,notification_video_session_reminders),
    notification_messages=COALESCE(p_messages,notification_messages),
    updated_at=now()
  WHERE id=v_uid;
END;
$$;
REVOKE ALL ON FUNCTION public.update_my_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean) TO authenticated;
