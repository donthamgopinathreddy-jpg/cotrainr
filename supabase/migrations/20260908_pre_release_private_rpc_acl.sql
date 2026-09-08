-- Cotrainr pre-release security hardening
-- RPC-01: remove anonymous access from authenticated/self SECURITY DEFINER RPCs.
-- Live Supabase was fixed first; this forward migration records production truth.

revoke execute on function public.get_my_profile() from public, anon;
revoke execute on function public.get_onboarding_state() from public, anon;
revoke execute on function public.list_my_video_sessions() from public, anon;
revoke execute on function public.list_my_video_session_people() from public, anon;
revoke execute on function public.create_or_find_provider_client_conversation(uuid) from public, anon;
revoke execute on function public.coach_can_view_client_meals(uuid) from public, anon;
revoke execute on function public.coach_can_view_client_metrics(uuid) from public, anon;
revoke execute on function public.coach_client_access_status(uuid) from public, anon;
revoke execute on function public.conversation_has_accepted_lead(public.conversations) from public, anon;

grant execute on function public.get_my_profile() to authenticated;
grant execute on function public.get_onboarding_state() to authenticated;
grant execute on function public.list_my_video_sessions() to authenticated;
grant execute on function public.list_my_video_session_people() to authenticated;
grant execute on function public.create_or_find_provider_client_conversation(uuid) to authenticated;
grant execute on function public.coach_can_view_client_meals(uuid) to authenticated;
grant execute on function public.coach_can_view_client_metrics(uuid) to authenticated;
grant execute on function public.coach_client_access_status(uuid) to authenticated;
