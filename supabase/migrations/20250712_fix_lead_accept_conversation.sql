-- Fix approve flow: live DB may lack UNIQUE on conversations.lead_id, so
-- update_lead_status_tx ON CONFLICT (lead_id) fails.

-- 1) One conversation per lead (remove duplicates if any)
DELETE FROM public.conversations a
USING public.conversations b
WHERE a.lead_id = b.lead_id
  AND a.id > b.id;

-- 2) Ensure unique on lead_id (skip silently if already present)
DO $$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS conversations_lead_id_unique
    ON public.conversations (lead_id);
EXCEPTION
  WHEN duplicate_table THEN NULL;
  WHEN duplicate_object THEN NULL;
END $$;

-- 3) Harden RPC: select-then-insert (no ON CONFLICT dependency)
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

REVOKE ALL ON FUNCTION public.update_lead_status_tx(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_lead_status_tx(uuid, text) TO authenticated;
