CREATE OR REPLACE FUNCTION public.create_lead_tx(p_provider_id uuid, p_message text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_client_id uuid;
  v_client_role text;
  v_client_name text;
  v_provider_type text;
  v_provider_verified boolean := false;
  v_plan text := 'free';
  v_nutritionist_allowed boolean := false;
  v_new_lead_id uuid;
BEGIN
  v_client_id := auth.uid();

  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'NOT_AUTHENTICATED', 'message', 'Authentication required');
  END IF;

  IF NOT public.is_account_active() THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'ACCOUNT_RESTRICTED', 'message', 'Account is restricted');
  END IF;

  SELECT p.role::text INTO v_client_role
  FROM public.profiles p
  WHERE p.id = v_client_id;

  IF v_client_role IS DISTINCT FROM 'client' THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'INVALID_ROLE', 'message', 'Only members can create connection requests');
  END IF;

  IF p_provider_id = v_client_id THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'INVALID_PROVIDER', 'message', 'Invalid provider');
  END IF;

  SELECT pr.provider_type::text, pr.verified
  INTO v_provider_type, v_provider_verified
  FROM public.providers pr
  WHERE pr.user_id = p_provider_id;

  IF v_provider_type IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'NOT_FOUND', 'message', 'Provider not found');
  END IF;

  IF v_provider_verified IS DISTINCT FROM true THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'PROVIDER_NOT_VERIFIED', 'message', 'Provider is not verified');
  END IF;

  IF public.effective_account_status(p_provider_id) IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'PROVIDER_UNAVAILABLE', 'message', 'Provider unavailable');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.leads l
    WHERE l.client_id = v_client_id
      AND l.provider_id = p_provider_id
      AND l.status IN ('requested', 'accepted')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'ACTIVE_RELATIONSHIP_EXISTS', 'message', 'Connection request or relationship already exists');
  END IF;

  SELECT CASE
    WHEN s.status::text = 'active' AND (s.expires_at IS NULL OR s.expires_at > now()) THEN s.plan::text
    ELSE 'free'
  END
  INTO v_plan
  FROM public.subscriptions s
  WHERE s.user_id = v_client_id
  LIMIT 1;

  IF NOT FOUND THEN
    v_plan := 'free';
  END IF;

  SELECT pcl.nutritionist_allowed
  INTO v_nutritionist_allowed
  FROM public.plan_connection_limits(v_plan) pcl;

  IF v_provider_type = 'nutritionist' AND NOT v_nutritionist_allowed THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'NUTRITIONIST_NOT_ALLOWED', 'message', 'Nutritionist connections require Basic or Premium');
  END IF;

  BEGIN
    INSERT INTO public.leads (client_id, provider_id, provider_type, status, message)
    VALUES (v_client_id, p_provider_id, v_provider_type::public.provider_type, 'requested', p_message)
    RETURNING id INTO v_new_lead_id;
  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object('ok', false, 'error_code', 'ACTIVE_RELATIONSHIP_EXISTS', 'message', 'Connection request or relationship already exists');
  END;

  SELECT coalesce(nullif(trim(p.full_name), ''), p.username, 'A member')
  INTO v_client_name
  FROM public.profiles p
  WHERE p.id = v_client_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    p_provider_id,
    'lead_request',
    'New connection request',
    coalesce(v_client_name, 'A member') || ' wants to connect with you',
    jsonb_build_object(
      'lead_id', v_new_lead_id,
      'client_id', v_client_id,
      'provider_id', p_provider_id,
      'provider_type', v_provider_type,
      'actor_id', v_client_id,
      'action', 'open_pending_requests'
    )
  );

  RETURN jsonb_build_object('ok', true, 'lead_id', v_new_lead_id, 'status', 'requested', 'allowance_consumed', false);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'CREATE_FAILED', 'message', 'Failed to create connection request');
END;
$function$;

REVOKE ALL ON FUNCTION public.create_lead_tx(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_lead_tx(uuid, text) TO authenticated, service_role;
