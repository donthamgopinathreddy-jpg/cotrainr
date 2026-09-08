-- Cotrainr pre-release security hardening
-- AUTH-01: self-declared signup role must never grant provider authority.
-- Provider authority is gated by public.providers.verified at the DB boundary.

create or replace function public.enforce_verified_provider_on_accepted_lead()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if new.status = 'accepted'::public.lead_status then
    if not exists (
      select 1
      from public.providers p
      where p.user_id = new.provider_id
        and p.verified is true
        and p.provider_type in (
          'trainer'::public.provider_type,
          'nutritionist'::public.provider_type
        )
    ) then
      raise exception 'Provider must be verified before accepting connections'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_leads_require_verified_provider on public.leads;
create trigger trg_leads_require_verified_provider
before insert or update of status, provider_id on public.leads
for each row
execute function public.enforce_verified_provider_on_accepted_lead();

create or replace function public.enforce_verified_video_session_host()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if not exists (
    select 1
    from public.providers p
    where p.user_id = new.host_id
      and p.verified is true
      and p.provider_type in (
        'trainer'::public.provider_type,
        'nutritionist'::public.provider_type
      )
  ) then
    raise exception 'Video session host must be a verified provider'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_video_sessions_require_verified_host on public.video_sessions;
create trigger trg_video_sessions_require_verified_host
before insert or update of host_id on public.video_sessions
for each row
execute function public.enforce_verified_video_session_host();

revoke execute on function public.enforce_verified_provider_on_accepted_lead()
  from public, anon, authenticated;
revoke execute on function public.enforce_verified_video_session_host()
  from public, anon, authenticated;
