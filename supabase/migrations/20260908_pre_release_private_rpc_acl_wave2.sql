-- Cotrainr pre-release security hardening
-- RPC-01 wave 2: additional authenticated-only SECURITY DEFINER RPCs.

revoke execute on function public.can_send_message_in_conversation(uuid, uuid)
  from public, anon;
revoke execute on function public.get_my_video_session(uuid)
  from public, anon;
revoke execute on function public.get_cocircle_feed(integer, timestamptz, uuid)
  from public, anon;

grant execute on function public.can_send_message_in_conversation(uuid, uuid)
  to authenticated;
grant execute on function public.get_my_video_session(uuid)
  to authenticated;
grant execute on function public.get_cocircle_feed(integer, timestamptz, uuid)
  to authenticated;
