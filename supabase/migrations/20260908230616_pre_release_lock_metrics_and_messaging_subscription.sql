-- Production migration 20260908230616
-- Lock metrics writes to the owner and enforce active client subscription on message sends.

drop policy if exists "Active accounts can insert metrics" on public.metrics_daily;
drop policy if exists "Active accounts can update metrics" on public.metrics_daily;
drop policy if exists "Active accounts can delete metrics" on public.metrics_daily;
drop policy if exists "Users can manage own metrics" on public.metrics_daily;
create policy "Users can select own metrics" on public.metrics_daily for select to authenticated using (auth.uid() = user_id);
create policy "Active users can insert own metrics" on public.metrics_daily for insert to authenticated with check (auth.uid() = user_id and public.is_account_active());
create policy "Active users can update own metrics" on public.metrics_daily for update to authenticated using (auth.uid() = user_id and public.is_account_active()) with check (auth.uid() = user_id and public.is_account_active());
create policy "Active users can delete own metrics" on public.metrics_daily for delete to authenticated using (auth.uid() = user_id and public.is_account_active());

create or replace function public.can_send_message_in_conversation(p_conversation_id uuid, p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  c public.conversations%rowtype;
  v_other_user_id uuid;
begin
  if p_user_id is null or p_conversation_id is null then return false; end if;
  if auth.uid() is null or auth.uid() <> p_user_id then return false; end if;

  select * into c from public.conversations where id = p_conversation_id;
  if not found then return false; end if;
  if not public.is_mvp_provider_client_conversation(c) then return false; end if;
  if not public.user_is_conversation_participant(c, p_user_id) then return false; end if;

  if c.client_id = p_user_id then
    v_other_user_id := c.provider_id;
  elsif c.provider_id = p_user_id then
    v_other_user_id := c.client_id;
  else
    return false;
  end if;
  if v_other_user_id is null then return false; end if;

  if public.effective_account_status(p_user_id) is distinct from 'active'
     or public.effective_account_status(v_other_user_id) is distinct from 'active' then
    return false;
  end if;

  if exists (select 1 from public.user_blocks ub where ub.is_active = true and ub.user_id in (p_user_id, v_other_user_id)) then
    return false;
  end if;

  if not public.conversation_has_accepted_lead(c.client_id, c.provider_id) then
    return false;
  end if;

  if not exists (
    select 1 from public.subscriptions s
    where s.user_id = c.client_id
      and s.status::text = 'active'
      and (s.expires_at is null or s.expires_at > now())
  ) then
    return false;
  end if;

  return true;
end;
$$;
