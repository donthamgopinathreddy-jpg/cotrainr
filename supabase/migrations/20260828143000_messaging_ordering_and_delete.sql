-- Cotrainr — Messaging: server-authoritative conversation ordering + delete for everyone.
--
-- Problem 1 (ordering)
-- --------------------
-- The chats list orders by conversations.updated_at, which is only bumped by a
-- best-effort client UPDATE issued by the SENDER after each insert
-- (messages_repository.sendMessage). Two things break it:
--   * public.conversations has RLS enabled and NO UPDATE policy, so that write
--     matches zero rows and PostgREST reports success — the bump never lands.
--   * The receiver never issues it at all.
-- Result: the list is effectively ordered by row creation, and an incoming
-- message does not move its thread to the top.
-- Fix: a real last_message_at column maintained by an AFTER INSERT trigger on
-- public.messages, which runs SECURITY DEFINER and is therefore unaffected by
-- the missing UPDATE policy.
--
-- Problem 2 (delete for everyone)
-- -------------------------------
-- "Delete for everyone" only called _messages.removeAt(index) in Flutter. No
-- column, no RPC, no write. The other participant never stopped seeing the
-- message, and it reappeared for the deleter on the next refresh. Client
-- UPDATE/DELETE on public.messages is also forbidden (the mark-read UPDATE
-- policy was dropped in 20260825), so this must go through a SECURITY DEFINER
-- RPC, mirroring mark_conversation_messages_read.
--
-- Does NOT touch: the notifications INSERT → pg_net → send-push-notification
-- pipeline, trg_notify_on_new_message, RLS on messages/conversations SELECT or
-- INSERT, or any Edge Function.
--
-- Idempotent: safe to re-run.

BEGIN;

-- ===========================================================================
-- 1. Conversation ordering
-- ===========================================================================

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;

-- Without a default, a conversation created after this migration stays NULL
-- until its first message and sorts to the bottom of the chats list.
ALTER TABLE public.conversations
  ALTER COLUMN last_message_at SET DEFAULT NOW();

COMMENT ON COLUMN public.conversations.last_message_at IS
  'Timestamp of the most recent message. Maintained by '
  'trg_messages_touch_conversation. Authoritative sort key for the chats list; '
  'do not order by created_at or updated_at.';

-- Backfill from real message history; fall back to existing timestamps so no
-- conversation sorts as NULL.
UPDATE public.conversations c
SET last_message_at = COALESCE(
      (SELECT MAX(m.created_at) FROM public.messages m
        WHERE m.conversation_id = c.id),
      c.updated_at,
      c.created_at
    )
WHERE c.last_message_at IS NULL;

-- `id DESC` is the tiebreaker: without it, conversations sharing a timestamp
-- (backfilled rows that fell back to the same created_at) can swap positions
-- between refetches.
DROP INDEX IF EXISTS idx_conversations_last_message_at;
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at
  ON public.conversations (last_message_at DESC NULLS LAST, id DESC);

-- SECURITY DEFINER so it bypasses the (intentionally absent) UPDATE policy on
-- public.conversations. Never raises: a failure here must not roll back a
-- message send.
CREATE OR REPLACE FUNCTION public.touch_conversation_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = GREATEST(
        COALESCE(last_message_at, NEW.created_at),
        NEW.created_at
      )
  WHERE id = NEW.conversation_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- RAISE WARNING does not abort the transaction, so a broken ordering update
  -- still cannot roll back a successful message insert. Logs the conversation
  -- id and the error only, never message content.
  RAISE WARNING 'touch_conversation_last_message failed for conversation %: % (%)',
    NEW.conversation_id, SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_touch_conversation ON public.messages;
CREATE TRIGGER trg_messages_touch_conversation
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_conversation_last_message();

COMMENT ON FUNCTION public.touch_conversation_last_message() IS
  'Keeps conversations.last_message_at current so the chats list can be ordered '
  'server-side. Deliberately a separate trigger from the push writer.';

-- ===========================================================================
-- 2. Delete for everyone — columns
-- ===========================================================================

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS deleted_for_everyone_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.messages.deleted_for_everyone_at IS
  'Tombstone marker. When set, content/media columns are redacted and clients '
  'must render "This message was deleted" for BOTH participants.';

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON public.messages (conversation_id, created_at);

-- Original content is preserved here for audit/integrity. No client role can
-- read this table: RLS is enabled with no policies, which denies everything
-- except service_role (which bypasses RLS).
CREATE TABLE IF NOT EXISTS public.message_content_archive (
  message_id UUID PRIMARY KEY REFERENCES public.messages(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL,
  sender_id UUID NOT NULL,
  content TEXT,
  media_url TEXT,
  media_kind TEXT,
  media_file_name TEXT,
  media_mime_type TEXT,
  media_size_bytes BIGINT,
  deleted_by UUID,
  archived_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.message_content_archive ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.message_content_archive FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.message_content_archive IS
  'Pre-redaction copy of messages deleted for everyone. RLS enabled with no '
  'policies: unreadable by anon/authenticated, service_role only.';

-- ===========================================================================
-- 3. Delete for me — per-user hide (does NOT affect the other participant)
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.message_hidden (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  hidden_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, message_id)
);

ALTER TABLE public.message_hidden ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS message_hidden_select_own ON public.message_hidden;
CREATE POLICY message_hidden_select_own ON public.message_hidden
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS message_hidden_delete_own ON public.message_hidden;
CREATE POLICY message_hidden_delete_own ON public.message_hidden
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

REVOKE ALL ON public.message_hidden FROM PUBLIC, anon;
GRANT SELECT, DELETE ON public.message_hidden TO authenticated;

COMMENT ON TABLE public.message_hidden IS
  'Delete-for-me. Private per-user hide list; never visible to or affecting the '
  'other participant. Distinct from messages.deleted_for_everyone_at.';

-- ===========================================================================
-- 4. RPC: delete for everyone (sender only)
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.delete_message_for_everyone(p_message_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  m public.messages%ROWTYPE;
  c public.conversations%ROWTYPE;
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL OR p_message_id IS NULL THEN
    RETURN false;
  END IF;

  -- FOR UPDATE serialises concurrent deletes of the same message so two callers
  -- cannot both observe deleted_for_everyone_at IS NULL.
  SELECT * INTO m FROM public.messages WHERE id = p_message_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Product rule: only the sender may delete for everyone.
  IF m.sender_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_message_sender' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO c FROM public.conversations WHERE id = m.conversation_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT public.is_mvp_provider_client_conversation(c) THEN
    RAISE EXCEPTION 'unsupported_conversation' USING ERRCODE = '42501';
  END IF;

  IF NOT public.user_is_conversation_participant(c, v_uid) THEN
    RAISE EXCEPTION 'not_conversation_participant' USING ERRCODE = '42501';
  END IF;

  -- Already deleted: succeed idempotently without re-archiving.
  IF m.deleted_for_everyone_at IS NOT NULL THEN
    RETURN true;
  END IF;

  INSERT INTO public.message_content_archive (
    message_id, conversation_id, sender_id, content, media_url, media_kind,
    media_file_name, media_mime_type, media_size_bytes, deleted_by
  )
  VALUES (
    m.id, m.conversation_id, m.sender_id, m.content, m.media_url,
    m.media_kind::text, m.media_file_name, m.media_mime_type,
    m.media_size_bytes, v_uid
  )
  ON CONFLICT (message_id) DO NOTHING;

  -- Redact in place so the original cannot be recovered through normal client
  -- reads. content is NOT NULL, so it becomes '' rather than NULL.
  UPDATE public.messages
  SET content                 = '',
      media_url               = NULL,
      media_kind              = NULL,
      media_file_name         = NULL,
      media_mime_type         = NULL,
      media_size_bytes        = NULL,
      deleted_for_everyone_at = NOW(),
      deleted_by              = v_uid
  WHERE id = p_message_id;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_message_for_everyone(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_message_for_everyone(UUID) TO authenticated, service_role;

COMMENT ON FUNCTION public.delete_message_for_everyone(UUID) IS
  'Sender-only tombstone. Archives the original to message_content_archive, then '
  'redacts content and all media columns on the row so neither participant can '
  'read the original. Clients render "This message was deleted".';

-- ===========================================================================
-- 5. RPC: delete for me (any participant, private)
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.hide_message_for_me(p_message_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  m public.messages%ROWTYPE;
  c public.conversations%ROWTYPE;
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL OR p_message_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT * INTO m FROM public.messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  SELECT * INTO c FROM public.conversations WHERE id = m.conversation_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT public.user_is_conversation_participant(c, v_uid) THEN
    RAISE EXCEPTION 'not_conversation_participant' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.message_hidden (user_id, message_id)
  VALUES (v_uid, p_message_id)
  ON CONFLICT (user_id, message_id) DO NOTHING;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.hide_message_for_me(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hide_message_for_me(UUID) TO authenticated, service_role;

COMMENT ON FUNCTION public.hide_message_for_me(UUID) IS
  'Delete-for-me. Records a private per-user hide. Does not modify the message '
  'row and has no effect on the other participant.';

COMMIT;
