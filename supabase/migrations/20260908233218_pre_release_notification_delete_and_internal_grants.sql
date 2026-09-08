DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
ON public.notifications FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON TABLE public.oauth_pending_states FROM anon, authenticated;
REVOKE ALL ON TABLE public.user_integrations_google FROM anon, authenticated;
REVOKE ALL ON TABLE public.user_integrations_zoom FROM anon, authenticated;
REVOKE ALL ON TABLE public.video_session_create_requests FROM anon, authenticated;
REVOKE ALL ON TABLE public.video_session_notification_jobs FROM anon, authenticated;
REVOKE ALL ON TABLE public.video_session_notification_log FROM anon, authenticated;
REVOKE ALL ON TABLE public.partner_member_claims FROM anon, authenticated;
REVOKE ALL ON TABLE public.partner_offer_redemptions FROM anon, authenticated;
REVOKE ALL ON TABLE public.partner_audit_log FROM anon, authenticated;
REVOKE ALL ON TABLE public.admin_users FROM anon, authenticated;
REVOKE ALL ON TABLE public.center_partner_users FROM anon, authenticated;
REVOKE ALL ON TABLE public.message_content_archive FROM anon, authenticated;

REVOKE INSERT ON TABLE public.video_sessions FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.video_session_participants FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.video_session_provider_meta FROM anon, authenticated;
