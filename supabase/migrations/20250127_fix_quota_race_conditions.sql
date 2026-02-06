-- =========================================
-- CRITICAL FIXES: Prevent quota bypass and duplicate conversations
-- =========================================

-- Prevent duplicate active leads per client/provider
create unique index if not exists leads_unique_active
on public.leads(client_id, provider_id)
where status in ('requested','accepted');

-- Prevent two conversations for one lead
-- Note: lead_id is already UNIQUE in table definition, so this is redundant
-- The unique constraint is enforced at table level, no need to add again

-- =========================================
-- RPC: create_lead_tx (atomic transaction)
-- =========================================
create or replace function public.create_lead_tx(
  p_provider_id uuid,
  p_message text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id uuid;
  v_client_role text;
  v_provider_type text;
  v_plan text;
  v_week_start date;
  v_requests_used int;
  v_nutritionist_requests_used int;
  v_requests_limit int;
  v_nutritionist_limit int;
  v_nutritionist_allowed boolean;
  v_new_lead_id uuid;
  v_remaining int;
begin
  -- Get current user
  v_client_id := auth.uid();
  if v_client_id is null then
    return jsonb_build_object('error', 'Unauthorized');
  end if;

  -- Verify client role
  select role into v_client_role
  from public.profiles
  where id = v_client_id;
  
  if v_client_role != 'client' then
    return jsonb_build_object('error', 'Only clients can create leads');
  end if;

  -- Get provider info
  select provider_type into v_provider_type
  from public.providers
  where user_id = p_provider_id;
  
  if v_provider_type is null then
    return jsonb_build_object('error', 'Provider not found');
  end if;

  -- Check for existing active lead
  if exists (
    select 1 from public.leads
    where client_id = v_client_id
      and provider_id = p_provider_id
      and status in ('requested', 'accepted')
  ) then
    return jsonb_build_object('error', 'Lead already exists');
  end if;

  -- Get subscription plan (coalesce handles NULL from subquery)
  select coalesce(
    (select plan from public.subscriptions where user_id = v_client_id limit 1),
    'free'
  ) into v_plan;

  -- Calculate week start (ISO Monday - deterministic formula)
  v_week_start := (current_date - ((extract(dow from current_date)::int + 6) % 7));

  -- Set limits based on plan
  case v_plan
    when 'free' then
      v_requests_limit := 3;
      v_nutritionist_allowed := false;
      v_nutritionist_limit := 0;
    when 'basic' then
      v_requests_limit := 15;
      v_nutritionist_allowed := true;
      v_nutritionist_limit := 3;
    when 'premium' then
      v_requests_limit := 30;
      v_nutritionist_allowed := true;
      v_nutritionist_limit := 30;
    else
      v_requests_limit := 3;
      v_nutritionist_allowed := false;
      v_nutritionist_limit := 0;
  end case;

  -- Check nutritionist restriction
  if v_provider_type = 'nutritionist' and not v_nutritionist_allowed then
    return jsonb_build_object('error', 'Nutritionist requests require Basic or Premium plan');
  end if;

  -- Insert weekly_usage row first (if doesn't exist) to ensure we can lock it
  insert into public.weekly_usage (
    user_id,
    week_start,
    requests_used,
    nutritionist_requests_used,
    video_sessions_used
  ) values (
    v_client_id,
    v_week_start,
    0,
    0,
    0
  )
  on conflict (user_id, week_start) do nothing;

  -- Lock and read current usage (FOR UPDATE prevents race conditions)
  -- Row now guaranteed to exist, so lock will work
  select 
    requests_used,
    nutritionist_requests_used
  into v_requests_used, v_nutritionist_requests_used
  from public.weekly_usage
  where user_id = v_client_id
    and week_start = v_week_start
  for update;

  -- Check limits (nutritionist requests count against both)
  if v_provider_type = 'nutritionist' then
    if v_nutritionist_requests_used >= v_nutritionist_limit then
      return jsonb_build_object(
        'error', 'Nutritionist request limit reached',
        'remaining', 0,
        'limit', v_nutritionist_limit
      );
    end if;
    if v_requests_used >= v_requests_limit then
      return jsonb_build_object(
        'error', 'Request limit reached',
        'remaining', 0,
        'limit', v_requests_limit
      );
    end if;
  else
    if v_requests_used >= v_requests_limit then
      return jsonb_build_object(
        'error', 'Request limit reached',
        'remaining', 0,
        'limit', v_requests_limit
      );
    end if;
  end if;

  -- Insert lead
  insert into public.leads (
    client_id,
    provider_id,
    provider_type,
    status,
    message
  ) values (
    v_client_id,
    p_provider_id,
    v_provider_type::public.provider_type,
    'requested',
    p_message
  ) returning id into v_new_lead_id;

  -- Update usage atomically (row already locked, safe to update)
  if v_provider_type = 'nutritionist' then
    update public.weekly_usage
    set
      requests_used = requests_used + 1,
      nutritionist_requests_used = nutritionist_requests_used + 1
    where user_id = v_client_id
      and week_start = v_week_start;
    
    v_remaining := least(
      v_requests_limit - (v_requests_used + 1),
      v_nutritionist_limit - (v_nutritionist_requests_used + 1)
    );
  else
    update public.weekly_usage
    set
      requests_used = requests_used + 1
    where user_id = v_client_id
      and week_start = v_week_start;
    
    v_remaining := v_requests_limit - (v_requests_used + 1);
  end if;

  return jsonb_build_object(
    'lead_id', v_new_lead_id,
    'status', 'requested',
    'remaining', greatest(0, v_remaining),
    'limit', case when v_provider_type = 'nutritionist' then v_nutritionist_limit else v_requests_limit end
  );
exception
  when unique_violation then
    return jsonb_build_object('error', 'Lead already exists');
  when others then
    return jsonb_build_object('error', 'Failed to create lead: ' || sqlerrm);
end;
$$;

revoke all on function public.create_lead_tx(uuid, text) from public;
grant execute on function public.create_lead_tx(uuid, text) to authenticated;

-- =========================================
-- RPC: update_lead_status_tx (atomic transaction)
-- =========================================
create or replace function public.update_lead_status_tx(
  p_lead_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_user_role text;
  v_lead_record record;
  v_conversation_id uuid;
begin
  -- Get current user
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('error', 'Unauthorized');
  end if;

  -- Validate status at top (before any other logic)
  if p_status not in ('accepted', 'declined', 'cancelled') then
    return jsonb_build_object('error', 'Invalid status');
  end if;

  -- Get user role
  select role into v_user_role
  from public.profiles
  where id = v_user_id;

  if v_user_role is null then
    return jsonb_build_object('error', 'Profile not found');
  end if;

  -- Get lead
  select * into v_lead_record
  from public.leads
  where id = p_lead_id;

  if v_lead_record is null then
    return jsonb_build_object('error', 'Lead not found');
  end if;

  -- Validate status transition (only 'requested' can be changed)
  if v_lead_record.status != 'requested' then
    return jsonb_build_object(
      'error', 'Lead already processed',
      'current_status', v_lead_record.status
    );
  end if;

  -- Validate actor permissions
  if p_status = 'cancelled' then
    if v_user_id != v_lead_record.client_id then
      return jsonb_build_object('error', 'Only client can cancel their own lead');
    end if;
  else
    if v_user_id != v_lead_record.provider_id then
      return jsonb_build_object('error', 'Only provider can accept/decline leads');
    end if;
  end if;

  -- Update lead status
  update public.leads
  set status = p_status::public.lead_status
  where id = p_lead_id;

  -- Create conversation if accepted
  if p_status = 'accepted' then
    insert into public.conversations (
      lead_id,
      client_id,
      provider_id
    ) values (
      p_lead_id,
      v_lead_record.client_id,
      v_lead_record.provider_id
    )
    on conflict (lead_id) do nothing
    returning id into v_conversation_id;

    -- If conflict, get existing conversation
    if v_conversation_id is null then
      select id into v_conversation_id
      from public.conversations
      where lead_id = p_lead_id;
    end if;
  end if;

  return jsonb_build_object(
    'lead_id', p_lead_id,
    'status', p_status,
    'conversation_id', v_conversation_id
  );
exception
  when unique_violation then
    -- Conversation already exists, get it
    select id into v_conversation_id
    from public.conversations
    where lead_id = p_lead_id;
    
    return jsonb_build_object(
      'lead_id', p_lead_id,
      'status', p_status,
      'conversation_id', v_conversation_id
    );
  when others then
    return jsonb_build_object('error', 'Failed to update lead: ' || sqlerrm);
end;
$$;

revoke all on function public.update_lead_status_tx(uuid, text) from public;
grant execute on function public.update_lead_status_tx(uuid, text) to authenticated;
