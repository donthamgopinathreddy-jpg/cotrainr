-- Google Meet integration for Video Sessions (OAuth tokens server-side only).
-- Non-destructive. Extends provider check for google_meet.
-- Apply manually if migration version history has duplicates.

-- 1) Google OAuth tokens (service_role / Edge only)
CREATE TABLE IF NOT EXISTS public.user_integrations_google (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  google_account_id TEXT,
  google_email TEXT,
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  access_token_expires_at TIMESTAMPTZ NOT NULL,
  scopes TEXT NOT NULL DEFAULT '',
  reconnect_required BOOLEAN NOT NULL DEFAULT false,
  connected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  disconnected_at TIMESTAMPTZ
);

ALTER TABLE public.user_integrations_google ENABLE ROW LEVEL SECURITY;

-- No authenticated policies → clients cannot SELECT tokens.
COMMENT ON TABLE public.user_integrations_google IS
  'Google Meet OAuth tokens. Edge/service_role only; no client SELECT.';

-- 2) OAuth CSRF/PKCE pending states (service_role only)
CREATE TABLE IF NOT EXISTS public.oauth_pending_states (
  state TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('google_meet')),
  code_verifier TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_oauth_pending_states_expires
  ON public.oauth_pending_states(expires_at);

ALTER TABLE public.oauth_pending_states ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.oauth_pending_states IS
  'Short-lived OAuth state + PKCE verifier. Edge/service_role only.';

-- 3) Provider-neutral session metadata (Meet space id, etc.)
CREATE TABLE IF NOT EXISTS public.video_session_provider_meta (
  session_id UUID PRIMARY KEY REFERENCES public.video_sessions(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  external_space_id TEXT,
  meeting_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.video_session_provider_meta ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Host can read provider meta"
  ON public.video_session_provider_meta
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.video_sessions s
      WHERE s.id = session_id AND s.host_id = auth.uid()
    )
  );

CREATE POLICY "No client write provider meta"
  ON public.video_session_provider_meta
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "No client update provider meta"
  ON public.video_session_provider_meta
  FOR UPDATE
  USING (false);

CREATE POLICY "No client delete provider meta"
  ON public.video_session_provider_meta
  FOR DELETE
  USING (false);

-- 4) Idempotency for create-video-session
CREATE TABLE IF NOT EXISTS public.video_session_create_requests (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_request_id TEXT NOT NULL,
  session_id UUID REFERENCES public.video_sessions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, client_request_id)
);

ALTER TABLE public.video_session_create_requests ENABLE ROW LEVEL SECURITY;

-- 5) Allow provider = google_meet on video_sessions
DO $$
DECLARE
  has_provider boolean;
BEGIN
  IF to_regclass('public.video_sessions') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='video_sessions' AND column_name='provider'
    ) INTO has_provider;

    IF has_provider THEN
      ALTER TABLE public.video_sessions DROP CONSTRAINT IF EXISTS video_sessions_provider_check;
      ALTER TABLE public.video_sessions ADD CONSTRAINT video_sessions_provider_check
        CHECK (provider IN ('zoom','meet','jitsi','manual','external','google_meet'));
    END IF;
  END IF;
END $$;
