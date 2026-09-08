-- Cotrainr pre-release security hardening
-- P0-01: privileged admin / verification RPC execution privileges
--
-- Canonical forward migration matching the verified live production state.
-- Historical migrations are intentionally left unchanged.
--
-- Desired state:
--   anon          -> NO EXECUTE
--   authenticated -> NO EXECUTE
--   service_role  -> EXECUTE

REVOKE EXECUTE ON FUNCTION public.admin_force_reverification(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_force_reverification(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_get_partner_application(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_grant_comp(uuid, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_grant_comp(uuid, timestamptz, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_list_audit_log(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_list_partner_applications(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_remove_comp(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_remove_comp(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_search_foods(text, integer, boolean) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_update_app_setting(text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_update_app_setting(text, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_update_partner_application_status(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.approve_verification(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.approve_verification_v2(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.list_pending_verifications(public.provider_type) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reject_verification(uuid, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reject_verification_v2(uuid, uuid, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.admin_force_reverification(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_force_reverification(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_partner_application(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_grant_comp(uuid, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_grant_comp(uuid, timestamptz, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_partner_applications(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_remove_comp(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_remove_comp(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_search_foods(text, integer, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(text, text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_partner_application_status(uuid, uuid, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.approve_verification(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.approve_verification_v2(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_pending_verifications(public.provider_type) TO service_role;
GRANT EXECUTE ON FUNCTION public.reject_verification(uuid, text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.reject_verification_v2(uuid, uuid, text) TO service_role;
