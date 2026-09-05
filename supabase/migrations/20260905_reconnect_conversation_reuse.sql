-- Reconnection: durable Member↔Provider conversation reuse
--
-- Product: one conversation per (client_id, provider_id). Multiple leads may
-- exist over time; acceptance of a NEW lead must REUSE the existing conversation
-- and rebind conversations.lead_id — never create a second MVP thread.
--
-- Does NOT change Model B allowance rules.
-- Does NOT delete messages, conversations, or historical leads.
--
-- Apply via normal migration process after live DB review.
-- Do NOT run supabase db push / db reset from this task.

-- ---------------------------------------------------------------------------
-- 1) Send gate: any CURRENT accepted lead for the pair unlocks the thread
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.conversation_has_accepted_lead(c public.conversations)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.leads l
    WHERE l.status = 'accepted'
      AND l.client_id = c.client_id
      AND l.provider_id = c.provider_id
  );
$$;

-- ---------------------------------------------------------------------------
-- 2) create_or_find: reuse pair row and rebind lead_id to current accepted lead
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

  IF v_my_role IN ('trainer', 'nutritionist')
     AND COALESCE(v_other_role, '') NOT IN ('trainer', 'nutritionist') THEN
    v_provider := v_uid;
    v_client := p_other_user_id;
  ELSIF COALESCE(v_my_role, '') NOT IN ('trainer', 'nutritionist')
        AND v_other_role IN ('trainer', 'nutritionist') THEN
    v_client := v_uid;
    v_provider := p_other_user_id;
  ELSE
    RAISE EXCEPTION 'unsupported_pairing';
  END IF;

  IF public.users_are_blocked(v_client, v_provider) THEN
    RAISE EXCEPTION 'users_blocked';
  END IF;

  IF NOT public.account_may_use_messaging(v_uid) THEN
    RAISE EXCEPTION 'messaging_disabled';
  END IF;

  SELECT l.id INTO v_lead_id
  FROM public.leads l
  WHERE l.client_id = v_client
    AND l.provider_id = v_provider
    AND l.status = 'accepted'
  ORDER BY l.created_at DESC
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
          AND (lead_id IS DISTINCT FROM v_lead_id);
      END IF;
  END;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_or_find_provider_client_conversation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_or_find_provider_client_conversation(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Accept: reuse existing pair conversation; never insert a duplicate thread
-- ---------------------------------------------------------------------------
-- Based on 20250712_fix_lead_accept_conversation.sql (latest repo definition).
-- If live DB added out-of-band allowance logic to this RPC, reconcile before apply.
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
    -- Prefer existing durable pair conversation (MVP shape).
    SELECT id INTO v_conversation_id
    FROM public.conversations
    WHERE client_id = v_lead_record.client_id
      AND provider_id = v_lead_record.provider_id
      AND other_user_id IS NULL
    LIMIT 1;

    IF v_conversation_id IS NOT NULL THEN
      UPDATE public.conversations
      SET lead_id = p_lead_id
      WHERE id = v_conversation_id;
    ELSE
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
          -- Pair unique index or lead_id unique: recover by pair, then lead_id.
          SELECT id INTO v_conversation_id
          FROM public.conversations
          WHERE client_id = v_lead_record.client_id
            AND provider_id = v_lead_record.provider_id
            AND other_user_id IS NULL
          LIMIT 1;

          IF v_conversation_id IS NULL THEN
            SELECT id INTO v_conversation_id
            FROM public.conversations
            WHERE lead_id = p_lead_id
            LIMIT 1;
          END IF;

          IF v_conversation_id IS NOT NULL THEN
            UPDATE public.conversations
            SET lead_id = p_lead_id
            WHERE id = v_conversation_id;
          END IF;
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

REVOKE ALL ON FUNCTION public.update_lead_status_tx(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_lead_status_tx(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.conversation_has_accepted_lead(public.conversations) IS
  'True when the client/provider pair has any currently accepted lead (durable conversation).';

COMMENT ON FUNCTION public.create_or_find_provider_client_conversation(uuid) IS
  'Finds or creates the single MVP conversation for a member/provider pair; rebinds lead_id on reuse.';
