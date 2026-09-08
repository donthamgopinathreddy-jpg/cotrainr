-- Cotrainr pre-release security hardening
-- RPC-03: keep the internal composite connection helper off the client Data API.
-- The authenticated app uses the separate (client_id, provider_id) overload,
-- which binds the supplied pair to auth.uid().

REVOKE EXECUTE ON FUNCTION public.conversation_has_accepted_lead(public.conversations)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.conversation_has_accepted_lead(public.conversations)
TO service_role;
