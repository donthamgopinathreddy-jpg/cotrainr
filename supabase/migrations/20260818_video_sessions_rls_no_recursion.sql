-- Fix video_sessions list/detail failures caused by RLS policy recursion.
-- Symptom: PostgREST 42P17 "infinite recursion detected in policy for relation ..."
-- even for hosts with zero sessions (SELECT still evaluates all SELECT policies).
--
-- Cycle:
--   video_sessions SELECT  → EXISTS video_session_participants
--   video_session_participants SELECT → EXISTS video_sessions
--
-- Hardening (20260816) and provider_meta (20260817) added participants/meta
-- policies that query video_sessions; safe only if video_sessions never
-- queries participants under RLS (use SECURITY DEFINER helpers).
--
-- Non-destructive. Does not broaden access. Does not touch Google tokens.

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

-- video_sessions: non-recursive host/participant SELECT (no client_id column)
DROP POLICY IF EXISTS "Participants can view sessions they are in" ON public.video_sessions;
DROP POLICY IF EXISTS "Participants can view sessions" ON public.video_sessions;

CREATE POLICY "Participants can view sessions they are in"
  ON public.video_sessions
  FOR SELECT
  USING (
    auth.uid() = host_id
    OR public.is_participant_in_video_session(id, auth.uid())
  );

-- Ensure host manage policy exists (idempotent)
DROP POLICY IF EXISTS "Hosts can manage own sessions" ON public.video_sessions;
CREATE POLICY "Hosts can manage own sessions"
  ON public.video_sessions
  FOR ALL
  USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

-- video_session_participants: do not EXISTS into video_sessions under RLS
DROP POLICY IF EXISTS "Host can manage participants" ON public.video_session_participants;
DROP POLICY IF EXISTS "Host can view participants of own sessions"
  ON public.video_session_participants;
DROP POLICY IF EXISTS "Participants can view participants list"
  ON public.video_session_participants;

CREATE POLICY "Users can view relevant session participants"
  ON public.video_session_participants
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_host_of_video_session(session_id, auth.uid())
  );

-- Keep write denial for authenticated clients (Edge uses service_role)
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

-- video_session_provider_meta: host read via SECURITY DEFINER (no RLS cycle)
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

COMMENT ON FUNCTION public.is_host_of_video_session(uuid, uuid) IS
  'SECURITY DEFINER host check for video session RLS; breaks policy recursion.';
COMMENT ON FUNCTION public.is_participant_in_video_session(uuid, uuid) IS
  'SECURITY DEFINER participant check for video session RLS; breaks policy recursion.';
