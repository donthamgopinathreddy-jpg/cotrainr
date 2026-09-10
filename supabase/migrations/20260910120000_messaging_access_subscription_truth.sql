-- Wave 2: messaging entitlement truthfulness
-- Align create/find + CTA probe with can_send_message_in_conversation's
-- accepted-lead + active client subscription rule.
-- Does NOT change Model B or weaken RLS.

-- ---------------------------------------------------------------------------
-- 1) Record live (uuid, uuid) accepted-lead helper with auth.uid() binding
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.conversation_has_accepted_lead(
  p_client_id uuid,
  p_provider_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_client_id IS NULL OR p_provider_id IS NULL THEN
    RETURN false;
  END IF;
  IF auth.uid() IS NULL
     OR (auth.uid() IS DISTINCT FROM p_client_id
         AND auth.uid() IS DISTINCT FROM p_provider_id) THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.leads l
    WHERE l.status = 'accepted'
      AND l.client_id = p_client_id
      AND l.provider_id = p_provider_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.conversation_has_accepted_lead(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.conversation_has_accepted_lead(uuid, uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2) Shared client subscription predicate (same as can_send)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.client_has_active_messaging_subscription(
  p_client_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.subscriptions s
    WHERE s.user_id = p_client_id
      AND s.status::text = 'active'
      AND (s.expires_at IS NULL OR s.expires_at > now())
  );
$$;

REVOKE ALL ON FUNCTION public.client_has_active_messaging_subscription(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_has_active_messaging_subscription(uuid)
  TO service_role;

-- ---------------------------------------------------------------------------
-- 3) CTA / open probe — returns machine code, never invents a second model
--    allowed | no_accepted_lead | subscription_required | users_blocked
--    | unsupported_pairing | messaging_disabled | invalid_participants
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.provider_client_messaging_access(
  p_other_user_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_my_role text;
  v_other_role text;
  v_client uuid;
  v_provider uuid;
BEGIN
  IF v_uid IS NULL OR p_other_user_id IS NULL OR v_uid = p_other_user_id THEN
    RETURN 'invalid_participants';
  END IF;

  SELECT role INTO v_my_role FROM public.profiles WHERE id = v_uid;
  SELECT role INTO v_other_role FROM public.profiles WHERE id = p_other_user_id;

  IF v_my_role IS NULL OR v_other_role IS NULL THEN
    RETURN 'invalid_participants';
  END IF;

  IF v_my_role IN ('trainer', 'nutritionist')
     AND v_other_role NOT IN ('trainer', 'nutritionist') THEN
    v_provider := v_uid;
    v_client := p_other_user_id;
  ELSIF v_my_role NOT IN ('trainer', 'nutritionist')
        AND v_other_role IN ('trainer', 'nutritionist') THEN
    v_client := v_uid;
    v_provider := p_other_user_id;
  ELSE
    RETURN 'unsupported_pairing';
  END IF;

  -- Match live can_send_message_in_conversation moderation probe.
  IF EXISTS (
    SELECT 1
    FROM public.user_blocks ub
    WHERE ub.is_active = true
      AND ub.user_id IN (v_client, v_provider)
  ) THEN
    RETURN 'users_blocked';
  END IF;

  -- Match live can_send: both accounts must be effectively active.
  IF public.effective_account_status(v_uid)
       IS DISTINCT FROM 'active'
     OR public.effective_account_status(p_other_user_id)
       IS DISTINCT FROM 'active' THEN
    RETURN 'messaging_disabled';
  END IF;

  IF NOT public.conversation_has_accepted_lead(v_client, v_provider) THEN
    RETURN 'no_accepted_lead';
  END IF;

  IF NOT public.client_has_active_messaging_subscription(v_client) THEN
    RETURN 'subscription_required';
  END IF;

  RETURN 'allowed';
END;
$$;

REVOKE ALL ON FUNCTION public.provider_client_messaging_access(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_client_messaging_access(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 4) create_or_find: reuse existing history without subscription, but block
--    NEW conversation creation when the client subscription gate fails.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_or_find_provider_client_conversation(
  p_other_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_my_role text;
  v_other_role text;
  v_client uuid;
  v_provider uuid;
  v_lead_id uuid;
  v_id uuid;
BEGIN
  IF v_uid IS NULL OR p_other_user_id IS NULL OR v_uid = p_other_user_id THEN
    RAISE EXCEPTION 'invalid_participants';
  END IF;

  SELECT role INTO v_my_role FROM public.profiles WHERE id = v_uid;
  SELECT role INTO v_other_role FROM public.profiles WHERE id = p_other_user_id;

  IF v_my_role IS NULL OR v_other_role IS NULL THEN
    RAISE EXCEPTION 'invalid_participants';
  END IF;

  IF v_my_role IN ('trainer', 'nutritionist')
     AND v_other_role NOT IN ('trainer', 'nutritionist') THEN
    v_provider := v_uid;
    v_client := p_other_user_id;
  ELSIF v_my_role NOT IN ('trainer', 'nutritionist')
        AND v_other_role IN ('trainer', 'nutritionist') THEN
    v_client := v_uid;
    v_provider := p_other_user_id;
  ELSE
    RAISE EXCEPTION 'unsupported_pairing';
  END IF;

  -- Match live can_send_message_in_conversation moderation probe.
  IF EXISTS (
    SELECT 1
    FROM public.user_blocks ub
    WHERE ub.is_active = true
      AND ub.user_id IN (v_client, v_provider)
  ) THEN
    RAISE EXCEPTION 'users_blocked';
  END IF;

  -- Match live can_send: both accounts must be effectively active.
  IF public.effective_account_status(v_uid)
       IS DISTINCT FROM 'active'
     OR public.effective_account_status(p_other_user_id)
       IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'messaging_disabled';
  END IF;

  SELECT l.id INTO v_lead_id
  FROM public.leads l
  WHERE l.client_id = v_client
    AND l.provider_id = v_provider
    AND l.status = 'accepted'
  ORDER BY
    l.accepted_at DESC NULLS LAST,
    l.created_at DESC,
    l.id DESC
  LIMIT 1;

  IF v_lead_id IS NULL THEN
    RAISE EXCEPTION 'no_accepted_lead';
  END IF;

  SELECT c.id INTO v_id
  FROM public.conversations c
  WHERE c.client_id = v_client
    AND c.provider_id = v_provider
    AND c.other_user_id IS NULL
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE public.conversations
    SET lead_id = v_lead_id
    WHERE id = v_id
      AND (lead_id IS DISTINCT FROM v_lead_id);
    RETURN v_id;
  END IF;

  -- New thread requires the same client subscription gate as send.
  IF NOT public.client_has_active_messaging_subscription(v_client) THEN
    RAISE EXCEPTION 'subscription_required';
  END IF;

  IF v_uid <> v_client THEN
    RAISE EXCEPTION 'provider_cannot_create';
  END IF;

  BEGIN
    INSERT INTO public.conversations (client_id, provider_id, lead_id, other_user_id)
    VALUES (v_client, v_provider, v_lead_id, NULL)
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      SELECT c.id INTO v_id
      FROM public.conversations c
      WHERE c.client_id = v_client
        AND c.provider_id = v_provider
        AND c.other_user_id IS NULL
      LIMIT 1;
      IF v_id IS NOT NULL THEN
        UPDATE public.conversations
        SET lead_id = v_lead_id
        WHERE id = v_id
          AND lead_id IS DISTINCT FROM v_lead_id;
      END IF;
  END;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'conversation_unavailable';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_or_find_provider_client_conversation(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_or_find_provider_client_conversation(uuid)
  TO authenticated;
