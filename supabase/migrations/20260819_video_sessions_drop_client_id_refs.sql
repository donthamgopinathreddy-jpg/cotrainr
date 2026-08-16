-- Align video_sessions RLS with canonical participant model.
-- Live schema has NO video_sessions.client_id; membership is only via
-- video_session_participants. Do not re-add client_id.
-- Uses SECURITY DEFINER helpers to avoid RLS recursion.

CREATE OR REPLACE FUNCTION public.is_participant_in_video_session(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.video_session_participants
    WHERE session_id = p_session_id AND user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_host_of_video_session(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.video_sessions
    WHERE id = p_session_id AND host_id = p_user_id
  );
$$;

REVOKE ALL ON FUNCTION public.is_participant_in_video_session(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_host_of_video_session(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_participant_in_video_session(uuid, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_host_of_video_session(uuid, uuid)
  TO authenticated, service_role;

-- Drop any SELECT policies that may reference obsolete client_id
DROP POLICY IF EXISTS "Participants can view sessions they are in" ON public.video_sessions;
DROP POLICY IF EXISTS "Participants can view sessions" ON public.video_sessions;

CREATE POLICY "Participants can view sessions they are in"
  ON public.video_sessions
  FOR SELECT
  USING (
    auth.uid() = host_id
    OR public.is_participant_in_video_session(id, auth.uid())
  );

DROP POLICY IF EXISTS "Hosts can manage own sessions" ON public.video_sessions;
CREATE POLICY "Hosts can manage own sessions"
  ON public.video_sessions
  FOR ALL
  USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

-- Participants table: no EXISTS into video_sessions under RLS
DROP POLICY IF EXISTS "Host can manage participants" ON public.video_session_participants;
DROP POLICY IF EXISTS "Host can view participants of own sessions"
  ON public.video_session_participants;
DROP POLICY IF EXISTS "Participants can view participants list"
  ON public.video_session_participants;
DROP POLICY IF EXISTS "Users can view relevant session participants"
  ON public.video_session_participants;

CREATE POLICY "Users can view relevant session participants"
  ON public.video_session_participants
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_host_of_video_session(session_id, auth.uid())
  );

DROP POLICY IF EXISTS "No client insert participants" ON public.video_session_participants;
DROP POLICY IF EXISTS "No client update participants" ON public.video_session_participants;
DROP POLICY IF EXISTS "No client delete participants" ON public.video_session_participants;

CREATE POLICY "No client insert participants"
  ON public.video_session_participants
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "No client update participants"
  ON public.video_session_participants
  FOR UPDATE
  USING (false);

CREATE POLICY "No client delete participants"
  ON public.video_session_participants
  FOR DELETE
  USING (false);

DO $$
BEGIN
  IF to_regclass('public.video_session_provider_meta') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Host can read provider meta"
      ON public.video_session_provider_meta;

    CREATE POLICY "Host can read provider meta"
      ON public.video_session_provider_meta
      FOR SELECT
      USING (public.is_host_of_video_session(session_id, auth.uid()));
  END IF;
END $$;
