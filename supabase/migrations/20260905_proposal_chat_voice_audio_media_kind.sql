-- PROPOSAL ONLY — do NOT apply via supabase db push / reset.
-- Apply manually in the live SQL editor after review.
--
-- Current media_kind enum (repo): image | video | document
-- No audio/voice value exists. Voice messages REQUIRE this change.
--
-- Changes:
-- 1) ADD VALUE 'audio' to media_kind
-- 2) Allow audio MIME types on private chat-attachments bucket
-- 3) notify_on_new_message: "Sent you a voice message" for audio
--
-- No RLS weakening. No conversation/lead changes.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'media_kind'
      AND e.enumlabel = 'audio'
  ) THEN
    ALTER TYPE public.media_kind ADD VALUE 'audio';
  END IF;
END $$;

UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'video/mp4',
  'video/quicktime',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/csv',
  'audio/mp4',
  'audio/m4a',
  'audio/aac',
  'audio/mpeg',
  'audio/x-m4a'
]
WHERE id = 'chat-attachments';

-- Refresh notify body for audio (keeps prior NULL-safe media_kind::text cast).
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

  v_kind := COALESCE(NEW.media_kind::text, '');
  IF v_kind = 'image' THEN
    v_body := 'Sent you a photo';
  ELSIF v_kind = 'document' THEN
    v_body := 'Sent you a document';
  ELSIF v_kind = 'audio' THEN
    v_body := 'Sent you a voice message';
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
