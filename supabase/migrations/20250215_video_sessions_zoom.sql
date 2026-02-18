-- Video Sessions Zoom Redesign
-- Replaces in-memory mock with Supabase + Zoom OAuth
-- host_start_url stored separately; participants never see it

-- Drop old video_sessions (different schema)
DROP TABLE IF EXISTS public.video_session_participants CASCADE;
DROP TABLE IF EXISTS public.video_session_host_meta CASCADE;
DROP TABLE IF EXISTS public.video_sessions CASCADE;

-- Zoom integration tokens (server-side only, Edge Functions write)
CREATE TABLE public.user_integrations_zoom (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  zoom_account_email TEXT,
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Video sessions (participants see join_url only)
CREATE TABLE public.video_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'zoom' CHECK (provider IN ('zoom', 'meet', 'jitsi')),
  title TEXT NOT NULL DEFAULT 'Video Session',
  description TEXT,
  scheduled_start TIMESTAMPTZ NOT NULL,
  duration_minutes INT NOT NULL DEFAULT 30,
  max_participants INT NOT NULL DEFAULT 5,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'cancelled', 'ended')),
  join_url TEXT NOT NULL,
  provider_meeting_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Host-only metadata: host_start_url NEVER exposed to participants
CREATE TABLE public.video_session_host_meta (
  session_id UUID PRIMARY KEY REFERENCES public.video_sessions(id) ON DELETE CASCADE,
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  host_start_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Participants (optional MVP - for RLS "who can see this session")
CREATE TABLE public.video_session_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.video_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'participant' CHECK (role IN ('host', 'participant')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, user_id)
);

-- Indexes
CREATE INDEX idx_video_sessions_host_id ON public.video_sessions(host_id);
CREATE INDEX idx_video_sessions_scheduled_start ON public.video_sessions(scheduled_start);
CREATE INDEX idx_video_sessions_status ON public.video_sessions(status);
CREATE INDEX idx_video_session_participants_session ON public.video_session_participants(session_id);
CREATE INDEX idx_video_session_participants_user ON public.video_session_participants(user_id);

-- RLS
ALTER TABLE public.user_integrations_zoom ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_session_host_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_session_participants ENABLE ROW LEVEL SECURITY;

-- user_integrations_zoom: only own row
CREATE POLICY "Users can read own zoom integration"
  ON public.user_integrations_zoom FOR SELECT
  USING (auth.uid() = user_id);

-- video_sessions: host CRUD own; participants SELECT where in participants table
CREATE POLICY "Hosts can manage own sessions"
  ON public.video_sessions FOR ALL
  USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Participants can view sessions they are in"
  ON public.video_sessions FOR SELECT
  USING (
    auth.uid() = host_id
    OR EXISTS (
      SELECT 1 FROM public.video_session_participants p
      WHERE p.session_id = video_sessions.id AND p.user_id = auth.uid()
    )
  );

-- video_session_host_meta: ONLY host can read (participants never see host_start_url)
CREATE POLICY "Only host can read host meta"
  ON public.video_session_host_meta FOR SELECT
  USING (auth.uid() = host_id);

-- No INSERT/UPDATE by client - Edge Functions use service role
CREATE POLICY "No client writes to host meta"
  ON public.video_session_host_meta FOR INSERT
  WITH CHECK (false);
CREATE POLICY "No client updates to host meta"
  ON public.video_session_host_meta FOR UPDATE
  USING (false);

-- video_session_participants: host can manage; participants can read
CREATE POLICY "Host can manage participants"
  ON public.video_session_participants FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.video_sessions s
      WHERE s.id = session_id AND s.host_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.video_sessions s
      WHERE s.id = session_id AND s.host_id = auth.uid()
    )
  );

CREATE POLICY "Participants can view participants list"
  ON public.video_session_participants FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.video_sessions s
      WHERE s.id = session_id AND s.host_id = auth.uid()
    )
  );

-- Grant service role for Edge Functions (by default service_role bypasses RLS)
-- No extra grants needed; Edge uses service_role key

COMMENT ON TABLE public.video_sessions IS 'Video sessions (Zoom/Meet/Jitsi); join_url for participants';
COMMENT ON TABLE public.video_session_host_meta IS 'Host-only start URL; never exposed to participants';
COMMENT ON TABLE public.user_integrations_zoom IS 'Zoom OAuth tokens; Edge Functions only write';
