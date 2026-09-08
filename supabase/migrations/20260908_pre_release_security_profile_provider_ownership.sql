-- Cotrainr pre-release security hardening
-- AUTH-01: close cross-user profile/provider mutation and provider verification bypass.
--
-- Live Supabase is production truth. This forward migration records the
-- verified production fix without replaying historical migrations.

-- Profiles: remove cross-user update path and require active ownership.
drop policy if exists "Active accounts can update profiles" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

create policy "Users can update own active profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id and public.is_account_active())
with check ((select auth.uid()) = id and public.is_account_active());

-- Providers: remove broad active-account insert/update paths.
drop policy if exists "Active accounts can insert provider profiles" on public.providers;
drop policy if exists "Active accounts can update provider profiles" on public.providers;
drop policy if exists "Providers can insert own provider" on public.providers;
drop policy if exists "Providers can update own provider" on public.providers;

create policy "Providers can insert own active provider"
on public.providers
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and public.is_account_active()
  and verified is false
  and coalesce(rating, 0) = 0
  and coalesce(total_reviews, 0) = 0
);

create policy "Providers can update own active provider"
on public.providers
for update
to authenticated
using ((select auth.uid()) = user_id and public.is_account_active())
with check ((select auth.uid()) = user_id and public.is_account_active());

-- Anonymous callers do not need direct provider-table access.
revoke all on table public.providers from anon;

-- Authenticated callers may read providers, but may only write app-owned
-- professional fields. Server/admin-controlled verification and aggregate
-- fields are intentionally excluded.
revoke insert, update, delete, truncate, references, trigger
  on table public.providers from authenticated;

grant select on table public.providers to authenticated;

grant insert (
  user_id,
  provider_type,
  specialization,
  experience_years,
  hourly_rate,
  bio,
  discoverable,
  professional_headline,
  session_modes,
  languages,
  accepting_new_clients
) on public.providers to authenticated;

grant update (
  provider_type,
  specialization,
  experience_years,
  hourly_rate,
  bio,
  discoverable,
  professional_headline,
  session_modes,
  languages,
  accepting_new_clients
) on public.providers to authenticated;
