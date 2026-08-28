-- ---------------------------------------------------------------------------
-- Cotrainr — MANUAL production repair for chat attachments + mark-read.
--
-- Run this by hand in the Supabase SQL Editor. Do NOT `supabase db push`,
-- `db reset`, or `migration repair` — the migration history is unsafe.
--
-- Idempotent and additive. It creates nothing that is dropped, drops nothing
-- that holds data, and touches no notification/push object.
--
-- WHAT THIS CHANGES
--   Storage buckets   : creates/normalizes private bucket `chat-attachments`
--   Storage policies  : 4 policies on storage.objects, scoped to that bucket
--   Functions         : creates or replaces public.mark_conversation_messages_read
--   Grants            : EXECUTE on that function to authenticated
--   Columns           : none
--   Triggers          : none
--   Tables            : none
--
-- WHAT THIS DOES NOT TOUCH
--   trg_notify_on_new_message, the pg_net dispatcher, send-push-notification,
--   public.notifications, the `posts`/`avatars` buckets and their policies,
--   messages RLS for SELECT/INSERT, delete_message_for_everyone,
--   hide_message_for_me, conversations.last_message_at.
-- ---------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Private chat attachment bucket
--
-- Chat media previously reused the PUBLIC `posts` bucket. The app now uploads
-- to `chat-attachments`, which was never created in production — hence
-- "Bucket not found" (404). It is created private on purpose: the fix must not
-- be to make chat media publicly readable.
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  false,
  52428800,
  ARRAY[
    'image/jpeg','image/jpg','image/png','image/webp','image/gif',
    'video/mp4','video/quicktime',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain','text/csv','application/csv'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public             = false,
  file_size_limit    = 52428800,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 2) Storage policies — object path is {userId}/chat/{conversationId}/{file}
--
-- Upload: only into your own folder, and only for a conversation you are in.
-- Read:   any participant of that conversation (needed for signed URLs).
-- Update/Delete: owner only.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can upload chat attachments" ON storage.objects;
CREATE POLICY "Participants can upload chat attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND (storage.foldername(name))[2] = 'chat'
  AND EXISTS (
    SELECT 1
    FROM public.conversations c
    WHERE c.id::text = (storage.foldername(name))[3]
      AND (
        c.client_id = auth.uid()
        OR c.provider_id = auth.uid()
        OR c.other_user_id = auth.uid()
      )
  )
);

DROP POLICY IF EXISTS "Participants can read chat attachments" ON storage.objects;
CREATE POLICY "Participants can read chat attachments"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[2] = 'chat'
  AND EXISTS (
    SELECT 1
    FROM public.conversations c
    WHERE c.id::text = (storage.foldername(name))[3]
      AND (
        c.client_id = auth.uid()
        OR c.provider_id = auth.uid()
        OR c.other_user_id = auth.uid()
      )
  )
);

-- `upsert: true` on upload issues an UPDATE when the object already exists.
DROP POLICY IF EXISTS "Owners can update chat attachments" ON storage.objects;
CREATE POLICY "Owners can update chat attachments"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owners can delete chat attachments" ON storage.objects;
CREATE POLICY "Owners can delete chat attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------------------------------------------------------------------------
-- 3) mark_conversation_messages_read
--
-- The broad "Participants can mark messages read" UPDATE policy was dropped in
-- 20260825_messaging_release.sql and replaced by this SECURITY DEFINER RPC. If
-- that migration is missing or partially applied in production, there is no
-- path at all to persist read_at, and the unread badge returns after every
-- refresh. CREATE OR REPLACE below always replaces any existing definition.
--
-- Dependencies are asserted, never created. Both helpers are expected to be
-- present in production; guessing at a replacement definition is riskier than
-- aborting, so a missing one raises and rolls back the whole transaction.
-- to_regprocedure matches the exact signature, so a same-named function with
-- different arguments cannot satisfy the check.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF to_regprocedure(
    'public.is_mvp_provider_client_conversation(public.conversations)'
  ) IS NULL THEN
    RAISE EXCEPTION
      'Missing dependency: public.is_mvp_provider_client_conversation(public.conversations)';
  END IF;

  IF to_regprocedure(
    'public.user_is_conversation_participant(public.conversations, uuid)'
  ) IS NULL THEN
    RAISE EXCEPTION
      'Missing dependency: public.user_is_conversation_participant(public.conversations, uuid)';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.mark_conversation_messages_read(p_conversation_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

-- SECURITY DEFINER only bypasses the absent UPDATE policy on public.messages if
-- the owner also owns that table. Set it explicitly rather than depending on
-- which role happened to paste this script.
ALTER FUNCTION public.mark_conversation_messages_read(uuid)
OWNER TO postgres;

-- No service_role grant: the function derives everything from auth.uid(), which
-- is NULL under service_role, and no server-side code calls it.
REVOKE ALL ON FUNCTION public.mark_conversation_messages_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_conversation_messages_read(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_conversation_messages_read(uuid) IS
  'Sole path for setting messages.read_at. Clients have no UPDATE policy on public.messages.';

COMMIT;

-- ===========================================================================
-- VERIFICATION — read-only. Run each block after COMMIT and compare to the
-- stated expectation. These are SELECTs only; none of them writes.
-- ===========================================================================

-- A. Bucket exists, is private, capped at 50 MiB, with the expected allow-list.
--    Expect exactly one row:
--      chat-attachments | f | 52428800 | 17
SELECT
  id,
  public,
  file_size_limit,
  COALESCE(array_length(allowed_mime_types, 1), 0) AS mime_count
FROM storage.buckets
WHERE id = 'chat-attachments';

-- B. Exactly four policies affect chat-attachments, all for `authenticated`.
--    Expect exactly 4 rows — DELETE, INSERT, SELECT, UPDATE — each with
--    roles = {authenticated}. More than 4 means a stray policy also targets
--    this bucket; fewer means one failed to create.
SELECT
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (COALESCE(qual, '') || COALESCE(with_check, '')) LIKE '%chat-attachments%'
ORDER BY cmd;

-- C. Mark-read RPC: definer rights, correct owner, pinned search_path, and
--    executable by authenticated but not anon.
--    Expect exactly one row:
--      mark_conversation_messages_read | t | postgres
--        | {"search_path=public, pg_temp"} | t | f
SELECT
  p.proname,
  p.prosecdef                                              AS security_definer,
  pg_get_userbyid(p.proowner)                              AS owner,
  p.proconfig                                              AS settings,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_exec,
  has_function_privilege('anon', p.oid, 'EXECUTE')          AS anon_can_exec
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'mark_conversation_messages_read';

-- D. public.messages must have NO broad client UPDATE policy: read_at stays
--    RPC-only. Expect only SELECT and INSERT rows, and zero rows with
--    cmd = 'UPDATE'. An UPDATE row means clients can rewrite message rows.
SELECT
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'messages'
ORDER BY cmd, policyname;

-- E. Both messaging triggers survive untouched.
--    Expect exactly 2 rows, both with tgenabled = 'O' (enabled, origin):
--      trg_messages_touch_conversation | O
--      trg_notify_on_new_message       | O
--    Fewer than 2 means the push producer or the conversation-ordering
--    trigger is missing — investigate before shipping the client.
SELECT
  tgname,
  tgenabled
FROM pg_trigger
WHERE tgrelid = 'public.messages'::regclass
  AND NOT tgisinternal
  AND tgname IN ('trg_notify_on_new_message', 'trg_messages_touch_conversation')
ORDER BY tgname;

-- F. Columns the Flutter unread queries depend on.
--    Expect exactly 2 rows, both timestamp with time zone:
--      deleted_for_everyone_at | timestamp with time zone
--      read_at                 | timestamp with time zone
--    If deleted_for_everyone_at is absent, HOLD the app release: both unread
--    queries filter on it and fetchConversations rethrows, so the Chats list
--    would fail to load entirely.
SELECT
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'messages'
  AND column_name IN ('read_at', 'deleted_for_everyone_at')
ORDER BY column_name;

-- G. Optional end-to-end smoke test. Run as a real recipient session (not as
--    postgres) for a conversation that has unread inbound messages:
--
--      SELECT public.mark_conversation_messages_read('<conversation-uuid>'::uuid);
--
--    Expect a positive integer on the first call and 0 on an immediate second
--    call. A 0 on the FIRST call means a silent guard rejected it — most
--    likely the conversation is not provider-client shaped, or the caller is
--    not a participant — and the unread badge will still stick.
-- ===========================================================================
