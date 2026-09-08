-- Cotrainr pre-release security hardening
-- RPC-01 wave 3: protected app surfaces do not require anonymous EXECUTE.
-- Pre-auth login/username helpers are intentionally left unchanged.
-- PostGIS-owned st_estimatedextent functions are left to extension-specific handling.

revoke execute on function public.discover_providers(public.provider_type[], numeric, text[], integer) from public, anon;
revoke execute on function public.get_leaderboard(text, date, integer, integer, uuid) from public, anon;
revoke execute on function public.get_provider_accepted_client_count(uuid) from public, anon;
revoke execute on function public.get_public_profile(uuid) from public, anon;
revoke execute on function public.get_public_profiles(uuid[]) from public, anon;
revoke execute on function public.get_public_provider_profile(uuid) from public, anon;
revoke execute on function public.list_partner_centers_for_discover() from public, anon;
revoke execute on function public.list_provider_reviews(uuid, integer) from public, anon;
revoke execute on function public.nearby_entities(double precision, double precision, integer, text) from public, anon;
revoke execute on function public.nearby_providers(double precision, double precision, double precision, public.provider_type[], public.location_type[], numeric, text[]) from public, anon;
revoke execute on function public.search_public_profiles(text, integer) from public, anon;

grant execute on function public.discover_providers(public.provider_type[], numeric, text[], integer) to authenticated;
grant execute on function public.get_leaderboard(text, date, integer, integer, uuid) to authenticated;
grant execute on function public.get_provider_accepted_client_count(uuid) to authenticated;
grant execute on function public.get_public_profile(uuid) to authenticated;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;
grant execute on function public.get_public_provider_profile(uuid) to authenticated;
grant execute on function public.list_partner_centers_for_discover() to authenticated;
grant execute on function public.list_provider_reviews(uuid, integer) to authenticated;
grant execute on function public.nearby_entities(double precision, double precision, integer, text) to authenticated;
grant execute on function public.nearby_providers(double precision, double precision, double precision, public.provider_type[], public.location_type[], numeric, text[]) to authenticated;
grant execute on function public.search_public_profiles(text, integer) to authenticated;
