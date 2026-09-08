-- Cotrainr pre-release security hardening
-- P0-02: lock down partner operational tables.
--
-- These tables are operational/admin data. The mobile app does not access
-- them directly. Partner/admin tooling must use the trusted service-role path.
-- Historical migrations are intentionally left unchanged.

alter table public.center_partner_users enable row level security;
alter table public.partner_audit_log enable row level security;
alter table public.partner_member_claims enable row level security;
alter table public.partner_offer_redemptions enable row level security;

revoke all on table public.center_partner_users from anon, authenticated;
revoke all on table public.partner_audit_log from anon, authenticated;
revoke all on table public.partner_member_claims from anon, authenticated;
revoke all on table public.partner_offer_redemptions from anon, authenticated;

grant all on table public.center_partner_users to service_role;
grant all on table public.partner_audit_log to service_role;
grant all on table public.partner_member_claims to service_role;
grant all on table public.partner_offer_redemptions to service_role;
