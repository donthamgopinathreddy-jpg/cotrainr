-- =========================================
-- Video Sessions MVP Enhancement
-- =========================================
-- Supplemental to 20250215_video_sessions_zoom.sql
-- Adds: client_id for direct client link, manual provider support
-- Idempotent: safe to run if columns already exist
-- =========================================

-- 1) Add client_id (nullable) - links session to specific client for RLS
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'video_sessions' AND column_name = 'client_id'
  ) THEN
    ALTER TABLE public.video_sessions
      ADD COLUMN client_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_video_sessions_client_id ON public.video_sessions(client_id);
  END IF;
END $$;

-- 2) Extend provider CHECK to allow 'manual' (trainer pastes own Zoom link)
DO $$
DECLARE
  cn text;
BEGIN
  SELECT conname INTO cn FROM pg_constraint
  WHERE conrelid = 'public.video_sessions'::regclass AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%provider%'
  LIMIT 1;
  IF cn IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.video_sessions DROP CONSTRAINT %I', cn);
  END IF;
  ALTER TABLE public.video_sessions ADD CONSTRAINT video_sessions_provider_check
    CHECK (provider IN ('zoom', 'meet', 'jitsi', 'manual'));
END $$;

-- 3) RLS: clients can SELECT sessions where they are client_id or in participants
DROP POLICY IF EXISTS "Participants can view sessions they are in" ON public.video_sessions;
CREATE POLICY "Participants can view sessions they are in"
  ON public.video_sessions FOR SELECT
  USING (
    auth.uid() = host_id
    OR auth.uid() = client_id
    OR EXISTS (
      SELECT 1 FROM public.video_session_participants p
      WHERE p.session_id = video_sessions.id AND p.user_id = auth.uid()
    )
  );

COMMENT ON COLUMN public.video_sessions.client_id IS 'Optional: direct client link for trainer-client sessions';
