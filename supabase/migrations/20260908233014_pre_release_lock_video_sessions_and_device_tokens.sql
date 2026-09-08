-- Production-forward pre-release hardening.
DROP POLICY IF EXISTS "Active accounts can insert video sessions" ON public.video_sessions;
DROP POLICY IF EXISTS "Active accounts can update video sessions" ON public.video_sessions;
DROP POLICY IF EXISTS "Active accounts can delete video sessions" ON public.video_sessions;

DROP POLICY IF EXISTS "Active accounts can insert device tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Active accounts can update device tokens" ON public.device_tokens;

DROP POLICY IF EXISTS "Users can insert own device tokens" ON public.device_tokens;
CREATE POLICY "Users can insert own active device tokens"
ON public.device_tokens FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = user_id AND public.is_account_active());

DROP POLICY IF EXISTS "Users can update own device tokens" ON public.device_tokens;
CREATE POLICY "Users can update own active device tokens"
ON public.device_tokens FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = user_id AND public.is_account_active())
WITH CHECK ((SELECT auth.uid()) = user_id AND public.is_account_active());

DROP POLICY IF EXISTS "Users can delete own device tokens" ON public.device_tokens;
CREATE POLICY "Users can delete own device tokens"
ON public.device_tokens FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can read own device tokens" ON public.device_tokens;
CREATE POLICY "Users can read own device tokens"
ON public.device_tokens FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);
