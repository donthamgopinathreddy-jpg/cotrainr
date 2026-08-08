-- Allow conversation participants to mark others' messages as read (read_at).
-- Without this UPDATE policy, markMessagesAsRead no-ops under RLS and badges stay sticky.

DROP POLICY IF EXISTS "Participants can mark messages read" ON public.messages;
CREATE POLICY "Participants can mark messages read"
ON public.messages
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM public.conversations c
    WHERE c.id = conversation_id
      AND (
        c.client_id = auth.uid()
        OR c.provider_id = auth.uid()
        OR c.other_user_id = auth.uid()
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.conversations c
    WHERE c.id = conversation_id
      AND (
        c.client_id = auth.uid()
        OR c.provider_id = auth.uid()
        OR c.other_user_id = auth.uid()
      )
  )
);
