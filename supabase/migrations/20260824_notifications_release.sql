-- Notifications release: single push authority, reminder dispatch authority, app version config.

-- ---------------------------------------------------------------------------
-- Push delivery policy (encoded — not operational memory)
-- EVENT → notifications INSERT → webhook send-push-notification → FCM ONLY.
-- Edge Functions must NOT call deliverNotificationRows after INSERT.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.system_config (key, value)
VALUES (
  'push_delivery_authority',
  'notifications_insert_webhook_send_push_notification'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = NOW();

COMMENT ON TABLE public.system_config IS
  'Release-critical config. push_delivery_authority = webhook-only FCM path.';

-- ---------------------------------------------------------------------------
-- Reminder dispatch: Edge Function dispatch-video-session-reminders (1/min).
-- pg_cron must NOT also poll dispatch_video_session_notification_jobs.
-- Job rows are still created by schedule_video_session_notification_jobs on
-- session create/reschedule; only the Edge Function polls due jobs.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.unschedule('cotrainr-video-session-reminders');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

INSERT INTO public.system_config (key, value)
VALUES (
  'video_reminder_dispatch_authority',
  'edge_function_dispatch_video_session_reminders'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = NOW();

-- ---------------------------------------------------------------------------
-- App version config (read-only for clients; writes via service role / dashboard)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_version_config (
  platform TEXT PRIMARY KEY CHECK (platform IN ('android', 'ios')),
  minimum_version TEXT NOT NULL DEFAULT '1.0.0',
  recommended_version TEXT NOT NULL DEFAULT '1.0.0',
  store_url TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_version_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_version_config_read ON public.app_version_config;
CREATE POLICY app_version_config_read ON public.app_version_config
  FOR SELECT TO authenticated, anon
  USING (true);

REVOKE ALL ON public.app_version_config FROM PUBLIC;
GRANT SELECT ON public.app_version_config TO authenticated, anon;

INSERT INTO public.app_version_config (platform, minimum_version, recommended_version, store_url)
VALUES
  (
    'android',
    '1.0.0',
    '1.0.0',
    'https://play.google.com/store/apps/details?id=com.cotrainr.app'
  ),
  (
    'ios',
    '1.0.0',
    '1.0.0',
    NULL
  )
ON CONFLICT (platform) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_app_version_config()
RETURNS TABLE (
  platform TEXT,
  minimum_version TEXT,
  recommended_version TEXT,
  store_url TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT platform, minimum_version, recommended_version, store_url
  FROM public.app_version_config;
$$;

REVOKE ALL ON FUNCTION public.get_app_version_config() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_version_config() TO authenticated, anon;
