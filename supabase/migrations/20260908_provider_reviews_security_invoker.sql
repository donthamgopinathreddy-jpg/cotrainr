-- Pre-release hardening: provider_reviews must use the caller's privileges/RLS.
-- Live production was verified before this forward-only migration was recorded.
-- Do not rewrite historical migrations; this file represents the intended final state.

ALTER VIEW public.provider_reviews SET (security_invoker = true);
