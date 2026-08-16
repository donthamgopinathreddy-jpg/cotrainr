-- Video sessions MVP hardening (Zoom OAuth retired from client path).
-- Non-destructive: no DROP TABLE. Tightens RLS so:
-- 1) Clients cannot SELECT Zoom tokens.
-- 2) Clients cannot INSERT/UPDATE/DELETE video_session_participants
--    (Edge Functions use service_role and still can).

-- 1) user_integrations_zoom: deny client reads of secrets
DROP POLICY IF EXISTS "Users can read own zoom integration"
  ON public.user_integrations_zoom;

-- No authenticated SELECT policies → clients cannot read tokens.
-- Service role (Edge) continues to bypass RLS.

COMMENT ON TABLE public.user_integrations_zoom IS
  'Zoom OAuth tokens (dormant for MVP). Edge/service_role only; no client SELECT.';

-- 2) Participants: hosts may SELECT; writes only via service_role
DROP POLICY IF EXISTS "Host can manage participants"
  ON public.video_session_participants;

CREATE POLICY "Host can view participants of own sessions"
  ON public.video_session_participants
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.video_sessions s
      WHERE s.id = session_id AND s.host_id = auth.uid()
    )
    OR user_id = auth.uid()
  );

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
