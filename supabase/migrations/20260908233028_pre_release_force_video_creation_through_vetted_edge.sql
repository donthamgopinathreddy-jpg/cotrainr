DROP POLICY IF EXISTS "Hosts can manage own sessions" ON public.video_sessions;

CREATE POLICY "Hosts can update own active sessions"
ON public.video_sessions FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = host_id AND public.is_account_active())
WITH CHECK ((SELECT auth.uid()) = host_id AND public.is_account_active());

CREATE POLICY "Hosts can delete own sessions"
ON public.video_sessions FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = host_id AND public.is_account_active());
