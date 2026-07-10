-- Notify providers when clients create leads, and clients when providers accept/decline.
-- Extends create_lead_tx and update_lead_status_tx in the same transaction as lead changes.

CREATE OR REPLACE FUNCTION public.create_lead_tx(
  p_provider_id uuid,
  p_message text default null
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id uuid;
  v_client_role text;
  v_client_name text;
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
BEGIN
  v_client_id := auth.uid();
  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  SELECT role INTO v_client_role
  FROM public.profiles
  WHERE id = v_client_id;

  IF v_client_role != 'client' THEN
    RETURN jsonb_build_object('error', 'Only clients can create leads');
  END IF;

  SELECT provider_type INTO v_provider_type
  FROM public.providers
  WHERE user_id = p_provider_id;

  IF v_provider_type IS NULL THEN
    RETURN jsonb_build_object('error', 'Provider not found');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.leads
    WHERE client_id = v_client_id
      AND provider_id = p_provider_id
      AND status IN ('requested', 'accepted')
  ) THEN
    RETURN jsonb_build_object('error', 'Lead already exists');
  END IF;

  SELECT coalesce(
    (SELECT plan FROM public.subscriptions WHERE user_id = v_client_id LIMIT 1),
    'free'
  ) INTO v_plan;

  v_week_start := (current_date - ((extract(dow from current_date)::int + 6) % 7));

  CASE v_plan
    WHEN 'free' THEN
      v_requests_limit := 3;
      v_nutritionist_allowed := false;
      v_nutritionist_limit := 0;
    WHEN 'basic' THEN
      v_requests_limit := 15;
      v_nutritionist_allowed := true;
      v_nutritionist_limit := 3;
    WHEN 'premium' THEN
      v_requests_limit := 30;
      v_nutritionist_allowed := true;
      v_nutritionist_limit := 30;
    ELSE
      v_requests_limit := 3;
      v_nutritionist_allowed := false;
      v_nutritionist_limit := 0;
  END CASE;

  IF v_provider_type = 'nutritionist' AND NOT v_nutritionist_allowed THEN
    RETURN jsonb_build_object('error', 'Nutritionist requests require Basic or Premium plan');
  END IF;

  INSERT INTO public.weekly_usage (
    user_id,
    week_start,
    requests_used,
    nutritionist_requests_used,
    video_sessions_used
  ) VALUES (
    v_client_id,
    v_week_start,
    0,
    0,
    0
  )
  ON CONFLICT (user_id, week_start) DO NOTHING;

  SELECT
    requests_used,
    nutritionist_requests_used
  INTO v_requests_used, v_nutritionist_requests_used
  FROM public.weekly_usage
  WHERE user_id = v_client_id
    AND week_start = v_week_start
  FOR UPDATE;

  IF v_provider_type = 'nutritionist' THEN
    IF v_nutritionist_requests_used >= v_nutritionist_limit THEN
      RETURN jsonb_build_object(
        'error', 'Nutritionist request limit reached',
        'remaining', 0,
        'limit', v_nutritionist_limit
      );
    END IF;
    IF v_requests_used >= v_requests_limit THEN
      RETURN jsonb_build_object(
        'error', 'Request limit reached',
        'remaining', 0,
        'limit', v_requests_limit
      );
    END IF;
  ELSE
    IF v_requests_used >= v_requests_limit THEN
      RETURN jsonb_build_object(
        'error', 'Request limit reached',
        'remaining', 0,
        'limit', v_requests_limit
      );
    END IF;
  END IF;

  INSERT INTO public.leads (
    client_id,
    provider_id,
    provider_type,
    status,
    message
  ) VALUES (
    v_client_id,
    p_provider_id,
    v_provider_type::public.provider_type,
    'requested',
    p_message
  ) RETURNING id INTO v_new_lead_id;

  IF v_provider_type = 'nutritionist' THEN
    UPDATE public.weekly_usage
    SET
      requests_used = requests_used + 1,
      nutritionist_requests_used = nutritionist_requests_used + 1
    WHERE user_id = v_client_id
      AND week_start = v_week_start;

    v_remaining := least(
      v_requests_limit - (v_requests_used + 1),
      v_nutritionist_limit - (v_nutritionist_requests_used + 1)
    );
  ELSE
    UPDATE public.weekly_usage
    SET requests_used = requests_used + 1
    WHERE user_id = v_client_id
      AND week_start = v_week_start;

    v_remaining := v_requests_limit - (v_requests_used + 1);
  END IF;

  SELECT coalesce(nullif(trim(full_name), ''), username, 'A client')
  INTO v_client_name
  FROM public.profiles
  WHERE id = v_client_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    p_provider_id,
    'lead_request',
    'New client request',
    v_client_name || ' sent you a coaching request.',
    jsonb_build_object(
      'lead_id', v_new_lead_id,
      'client_id', v_client_id,
      'provider_id', p_provider_id,
      'actor_id', v_client_id,
      'action', 'open_pending_requests'
    )
  );

  RETURN jsonb_build_object(
    'lead_id', v_new_lead_id,
    'status', 'requested',
    'remaining', greatest(0, v_remaining),
    'limit', CASE WHEN v_provider_type = 'nutritionist' THEN v_nutritionist_limit ELSE v_requests_limit END
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('error', 'Lead already exists');
  WHEN OTHERS THEN
    RETURN jsonb_build_object('error', 'Failed to create lead: ' || sqlerrm);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_lead_status_tx(
  p_lead_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_role text;
  v_lead_record record;
  v_conversation_id uuid;
  v_actor_name text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  IF p_status NOT IN ('accepted', 'declined', 'cancelled') THEN
    RETURN jsonb_build_object('error', 'Invalid status');
  END IF;

  SELECT role INTO v_user_role
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_user_role IS NULL THEN
    RETURN jsonb_build_object('error', 'Profile not found');
  END IF;

  SELECT * INTO v_lead_record
  FROM public.leads
  WHERE id = p_lead_id;

  IF v_lead_record IS NULL THEN
    RETURN jsonb_build_object('error', 'Lead not found');
  END IF;

  IF v_lead_record.status != 'requested' THEN
    RETURN jsonb_build_object(
      'error', 'Lead already processed',
      'current_status', v_lead_record.status
    );
  END IF;

  IF p_status = 'cancelled' THEN
    IF v_user_id != v_lead_record.client_id THEN
      RETURN jsonb_build_object('error', 'Only client can cancel their own lead');
    END IF;
  ELSE
    IF v_user_id != v_lead_record.provider_id THEN
      RETURN jsonb_build_object('error', 'Only provider can accept/decline leads');
    END IF;
  END IF;

  UPDATE public.leads
  SET status = p_status::public.lead_status
  WHERE id = p_lead_id;

  IF p_status = 'accepted' THEN
    SELECT id INTO v_conversation_id
    FROM public.conversations
    WHERE lead_id = p_lead_id
    LIMIT 1;

    IF v_conversation_id IS NULL THEN
      BEGIN
        INSERT INTO public.conversations (
          lead_id,
          client_id,
          provider_id
        ) VALUES (
          p_lead_id,
          v_lead_record.client_id,
          v_lead_record.provider_id
        )
        RETURNING id INTO v_conversation_id;
      EXCEPTION
        WHEN unique_violation THEN
          SELECT id INTO v_conversation_id
          FROM public.conversations
          WHERE lead_id = p_lead_id
          LIMIT 1;
      END;
    END IF;

    SELECT coalesce(nullif(trim(full_name), ''), username, 'Your provider')
    INTO v_actor_name
    FROM public.profiles
    WHERE id = v_lead_record.provider_id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_lead_record.client_id,
      'lead_accepted',
      'Request accepted',
      v_actor_name || ' accepted your coaching request.',
      jsonb_build_object(
        'lead_id', p_lead_id,
        'client_id', v_lead_record.client_id,
        'provider_id', v_lead_record.provider_id,
        'actor_id', v_lead_record.provider_id,
        'conversation_id', v_conversation_id,
        'action', 'open_messaging'
      )
    );
  ELSIF p_status = 'declined' THEN
    SELECT coalesce(nullif(trim(full_name), ''), username, 'Your provider')
    INTO v_actor_name
    FROM public.profiles
    WHERE id = v_lead_record.provider_id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_lead_record.client_id,
      'lead_declined',
      'Request declined',
      v_actor_name || ' declined your coaching request.',
      jsonb_build_object(
        'lead_id', p_lead_id,
        'client_id', v_lead_record.client_id,
        'provider_id', v_lead_record.provider_id,
        'actor_id', v_lead_record.provider_id,
        'action', 'open_discover'
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'lead_id', p_lead_id,
    'status', p_status,
    'conversation_id', v_conversation_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('error', 'Failed to update lead: ' || sqlerrm);
END;
$$;

REVOKE ALL ON FUNCTION public.create_lead_tx(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_lead_tx(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.update_lead_status_tx(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_lead_status_tx(uuid, text) TO authenticated;
