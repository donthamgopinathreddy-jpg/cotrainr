-- Legacy nearby_entities exposed raw profiles.lat/lng for provider rows and is
-- not used by the current Flutter app or other public functions. Keep it only
-- for service-role compatibility; current Discover uses nearby_providers,
-- which enforces verified/discoverable providers and private-home geo masking.

REVOKE EXECUTE ON FUNCTION public.nearby_entities(
  double precision,
  double precision,
  integer,
  text
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.nearby_entities(
  double precision,
  double precision,
  integer,
  text
) TO service_role;
