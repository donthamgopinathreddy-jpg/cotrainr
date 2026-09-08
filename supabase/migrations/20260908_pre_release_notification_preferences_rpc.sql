-- Cotrainr pre-release hardening
-- P1: notification preference RPC must be server-only.
--
-- get_notification_push(uuid) accepts an arbitrary user id and is used by
-- trusted server-side push dispatch. Client roles do not need direct EXECUTE.

REVOKE ALL ON FUNCTION public.get_notification_push(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_notification_push(uuid)
TO service_role;
