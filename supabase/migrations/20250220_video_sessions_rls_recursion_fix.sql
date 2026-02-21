-- Fix infinite recursion in video_sessions RLS policies
-- video_sessions policy -> video_session_participants -> video_sessions (recursion)
-- Use SECURITY DEFINER function to break the cycle

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

-- Drop and recreate video_sessions SELECT policy to use the function (breaks recursion)
DROP POLICY IF EXISTS "Participants can view sessions they are in" ON public.video_sessions;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='video_sessions' AND column_name='client_id'
  ) THEN
    CREATE POLICY "Participants can view sessions they are in"
      ON public.video_sessions FOR SELECT
      USING (
        auth.uid() = host_id
        OR (client_id IS NOT NULL AND auth.uid() = client_id)
        OR public.is_participant_in_video_session(id, auth.uid())
      );
  ELSE
    CREATE POLICY "Participants can view sessions they are in"
      ON public.video_sessions FOR SELECT
      USING (
        auth.uid() = host_id
        OR public.is_participant_in_video_session(id, auth.uid())
      );
  END IF;
END $$;
