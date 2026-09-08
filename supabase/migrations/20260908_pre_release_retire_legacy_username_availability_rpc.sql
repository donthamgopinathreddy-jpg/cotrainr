-- Cotrainr pre-release security hardening
-- RPC-01: signup uses is_username_available. This older duplicate has no app caller.

revoke execute on function public.check_user_id_availability(text)
  from public, anon, authenticated;
grant execute on function public.check_user_id_availability(text)
  to service_role;
