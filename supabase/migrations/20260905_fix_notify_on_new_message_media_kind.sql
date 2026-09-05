-- Fix: text messages (media_kind NULL) failed INSERT with:
--   22P02 invalid input value for enum media_kind: ""
--
-- Cause: notify_on_new_message coalesced the media_kind enum with an empty
-- string literal, so Postgres cast '' into enum media_kind (22P02) when NULL.
-- Fix: cast to text first: NEW.media_kind::text before coalesce.
--
-- No schema / enum / RLS changes. Function body only.

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

  -- Cast enum → text BEFORE coalescing so NULL does not become enum ''.
  v_kind := COALESCE(NEW.media_kind::text, '');
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

COMMENT ON FUNCTION public.notify_on_new_message() IS
  'Authoritative message push: INSERT notifications → webhook → FCM. media_kind NULL-safe.';
