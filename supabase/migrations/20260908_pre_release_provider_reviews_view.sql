-- Cotrainr pre-release hardening
-- P0/P1: provider_reviews must obey caller RLS instead of view-owner privileges.

ALTER VIEW public.provider_reviews SET (security_invoker = true);

REVOKE ALL ON TABLE public.provider_reviews FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.provider_reviews TO authenticated, service_role;
