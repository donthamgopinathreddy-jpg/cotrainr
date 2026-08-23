-- Messaging release: server send hardening, mark-read RPC, conversation uniqueness,
-- message → notifications push writer, message notification preference.

-- ---------------------------------------------------------------------------
-- 1) Message notification preference
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_messages BOOLEAN NOT NULL DEFAULT true;

DROP FUNCTION IF EXISTS public.get_notification_push(uuid);

CREATE FUNCTION public.get_notification_push(p_user_id uuid)
RETURNS TABLE (
  notification_push boolean,
  notification_video_sessions boolean,
  notification_video_session_reminders boolean,
  notification_messages boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(p.notification_push, true),
    COALESCE(p.notification_video_sessions, true),
    COALESCE(p.notification_video_session_reminders, true),
    COALESCE(p.notification_messages, true)
  FROM public.profiles p
  WHERE p.id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_notification_push(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_notification_push(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 2) Helpers: MVP provider–client conversation + accepted lead + send gate
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_mvp_provider_client_conversation(c public.conversations)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT c.provider_id IS NOT NULL
     AND c.client_id IS NOT NULL
     AND c.other_user_id IS NULL;
$$;

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
      AND (c.lead_id IS NULL OR l.id = c.lead_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.user_is_conversation_participant(
  c public.conversations,
  p_user_id uuid
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT p_user_id IS NOT NULL
     AND (
       c.client_id = p_user_id
       OR c.provider_id = p_user_id
       OR c.other_user_id = p_user_id
     );
$$;

CREATE OR REPLACE FUNCTION public.can_send_message_in_conversation(
  p_conversation_id uuid,
  p_user_id uuid
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c public.conversations%ROWTYPE;
  v_other uuid;
BEGIN
  IF p_user_id IS NULL OR p_conversation_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT * INTO c FROM public.conversations WHERE id = p_conversation_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Shipping MVP: provider–client only (hide CoCircle / community shape).
  IF NOT public.is_mvp_provider_client_conversation(c) THEN
    RETURN false;
  END IF;

  IF NOT public.user_is_conversation_participant(c, p_user_id) THEN
    RETURN false;
  END IF;

  IF NOT public.account_may_use_messaging(p_user_id) THEN
    RETURN false;
  END IF;

  v_other := CASE
    WHEN c.client_id = p_user_id THEN c.provider_id
    ELSE c.client_id
  END;

  IF public.users_are_blocked(p_user_id, v_other) THEN
    RETURN false;
  END IF;

  IF NOT public.conversation_has_accepted_lead(c) THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.can_send_message_in_conversation(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_send_message_in_conversation(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_send_message_in_conversation(uuid, uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 3) Message INSERT RLS (restore weak monthly-quota policy)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;
CREATE POLICY "Participants can send messages"
ON public.messages
FOR INSERT
WITH CHECK (
  sender_id = auth.uid()
  AND public.can_send_message_in_conversation(conversation_id, auth.uid())
);

-- ---------------------------------------------------------------------------
-- 4) Safe mark-read RPC; drop broad UPDATE policy
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can mark messages read" ON public.messages;

CREATE OR REPLACE FUNCTION public.mark_conversation_messages_read(p_conversation_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c public.conversations%ROWTYPE;
  v_uid uuid := auth.uid();
  v_count integer := 0;
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT * INTO c FROM public.conversations WHERE id = p_conversation_id;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- MVP shape only; participant required.
  IF NOT public.is_mvp_provider_client_conversation(c) THEN
    RETURN 0;
  END IF;
  IF NOT public.user_is_conversation_participant(c, v_uid) THEN
    RETURN 0;
  END IF;

  UPDATE public.messages m
  SET read_at = NOW()
  WHERE m.conversation_id = p_conversation_id
    AND m.sender_id IS DISTINCT FROM v_uid
    AND m.read_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_conversation_messages_read(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_conversation_messages_read(uuid) TO authenticated;

-- No client UPDATE on messages (prevent content/sender rewrite).
-- Service role / SECURITY DEFINER RPCs still work.

-- ---------------------------------------------------------------------------
-- 5) Conversation uniqueness + create RPC
-- ---------------------------------------------------------------------------
-- Collapse duplicate provider–client rows: keep earliest, move messages, drop extras.
DO $$
DECLARE
  r RECORD;
  keep_id uuid;
  dup_id uuid;
BEGIN
  FOR r IN
    SELECT client_id, provider_id
    FROM public.conversations
    WHERE provider_id IS NOT NULL
      AND other_user_id IS NULL
    GROUP BY client_id, provider_id
    HAVING COUNT(*) > 1
  LOOP
    SELECT id INTO keep_id
    FROM public.conversations
    WHERE client_id = r.client_id
      AND provider_id = r.provider_id
      AND other_user_id IS NULL
    ORDER BY created_at ASC NULLS FIRST, id ASC
    LIMIT 1;

    FOR dup_id IN
      SELECT id
      FROM public.conversations
      WHERE client_id = r.client_id
        AND provider_id = r.provider_id
        AND other_user_id IS NULL
        AND id <> keep_id
    LOOP
      UPDATE public.messages
      SET conversation_id = keep_id
      WHERE conversation_id = dup_id;
      DELETE FROM public.conversations WHERE id = dup_id;
    END LOOP;
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_unique_client_provider_mvp
  ON public.conversations (client_id, provider_id)
  WHERE provider_id IS NOT NULL AND other_user_id IS NULL;

DROP POLICY IF EXISTS "Participants can insert conversations" ON public.conversations;
CREATE POLICY "Participants can insert conversations"
ON public.conversations
FOR INSERT
WITH CHECK (
  auth.uid() = client_id
  AND provider_id IS NOT NULL
  AND other_user_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.leads l
    WHERE l.status = 'accepted'
      AND l.client_id = client_id
      AND l.provider_id = provider_id
  )
);

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
  END;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_or_find_provider_client_conversation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_or_find_provider_client_conversation(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Message INSERT → notifications writer (webhook → FCM)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c public.conversations%ROWTYPE;
  v_recipient uuid;
  v_sender_name text;
  v_title text;
  v_body text;
  v_kind text;
  v_preview text;
BEGIN
  SELECT * INTO c FROM public.conversations WHERE id = NEW.conversation_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- Only MVP provider–client threads generate shipping message push.
  IF NOT public.is_mvp_provider_client_conversation(c) THEN
    RETURN NEW;
  END IF;

  v_recipient := CASE
    WHEN NEW.sender_id = c.client_id THEN c.provider_id
    WHEN NEW.sender_id = c.provider_id THEN c.client_id
    ELSE NULL
  END;

  IF v_recipient IS NULL OR v_recipient = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  -- Preference: master push + message category.
  IF EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_recipient
      AND (
        COALESCE(p.notification_push, true) = false
        OR COALESCE(p.notification_messages, true) = false
      )
  ) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
           NULLIF(BTRIM(p.full_name), ''),
           NULLIF(BTRIM(p.username), ''),
           'Cotrainr'
         )
    INTO v_sender_name
  FROM public.profiles p
  WHERE p.id = NEW.sender_id;

  v_kind := COALESCE(NEW.media_kind, '');
  IF v_kind = 'image' THEN
    v_body := 'Sent you a photo';
  ELSIF v_kind = 'document' THEN
    v_body := 'Sent you a document';
  ELSIF v_kind = 'video' THEN
    v_body := 'Sent you a message';
  ELSE
    v_preview := COALESCE(NEW.content, '');
    v_preview := regexp_replace(v_preview, '\s+', ' ', 'g');
    v_preview := BTRIM(v_preview);
    IF char_length(v_preview) > 120 THEN
      v_preview := left(v_preview, 117) || '...';
    END IF;
    IF v_preview = '' THEN
      v_body := 'Sent you a message';
    ELSE
      v_body := v_preview;
    END IF;
  END IF;

  v_title := COALESCE(v_sender_name, 'Cotrainr');

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_recipient,
    'message',
    v_title,
    v_body,
    jsonb_build_object(
      'type', 'message',
      'notification_type', 'message',
      'conversation_id', NEW.conversation_id,
      'message_id', NEW.id,
      'sender_id', NEW.sender_id,
      'action', 'open_conversation'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_new_message ON public.messages;
CREATE TRIGGER trg_notify_on_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_message();

COMMENT ON FUNCTION public.notify_on_new_message() IS
  'Authoritative message push: INSERT notifications → webhook send-push-notification → FCM. Never notifies sender.';
