-- COCIRCLE DIRECT CONVERSATIONS
-- Allows user-to-user messaging in Cocircle (without requiring lead/provider)
-- Self-contained: handles lead_id and provider_id nullable

-- 1. Make lead_id nullable (for cocircle, no lead required)
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'conversations' 
    AND column_name = 'lead_id' AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.conversations ALTER COLUMN lead_id DROP NOT NULL;
    -- Drop the UNIQUE constraint (not index - constraint creates backing index)
    ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_lead_id_key;
    CREATE UNIQUE INDEX IF NOT EXISTS conversations_lead_id_unique 
      ON public.conversations(lead_id) WHERE lead_id IS NOT NULL;
  END IF;
END $$;

-- 2. Make provider_id nullable for cocircle (user-to-user) conversations
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'conversations' 
    AND column_name = 'provider_id' AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.conversations ALTER COLUMN provider_id DROP NOT NULL;
  END IF;
END $$;

-- 3. Add other_user_id for cocircle DMs (when provider_id is null)
ALTER TABLE public.conversations 
  ADD COLUMN IF NOT EXISTS other_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Ensure we have at least one "other" participant
ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_has_other_participant;
ALTER TABLE public.conversations 
  ADD CONSTRAINT conversations_has_other_participant 
  CHECK (provider_id IS NOT NULL OR other_user_id IS NOT NULL);

-- Index for cocircle lookups
CREATE INDEX IF NOT EXISTS idx_conversations_other_user_id 
  ON public.conversations(other_user_id) 
  WHERE other_user_id IS NOT NULL;

-- Update RLS: allow participants to view when they are other_user_id (cocircle)
DROP POLICY IF EXISTS "Participants can view conversations" ON public.conversations;
CREATE POLICY "Participants can view conversations" ON public.conversations
  FOR SELECT USING (
    auth.uid() = client_id 
    OR auth.uid() = provider_id 
    OR auth.uid() = other_user_id
  );

-- Allow INSERT for cocircle (client creates with other_user_id, no provider)
-- Existing policies may block; ensure we can insert
DROP POLICY IF EXISTS "Participants can insert conversations" ON public.conversations;
CREATE POLICY "Participants can insert conversations" ON public.conversations
  FOR INSERT WITH CHECK (
    auth.uid() = client_id 
    AND (provider_id IS NOT NULL OR other_user_id IS NOT NULL)
  );

COMMENT ON COLUMN public.conversations.other_user_id IS 'For cocircle user-to-user DMs. When set, provider_id is null.';

-- Update messages policies to include other_user_id (cocircle participants)
DROP POLICY IF EXISTS "Participants can view messages" ON public.messages;
CREATE POLICY "Participants can view messages" ON public.messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = conversation_id
      AND (c.client_id = auth.uid() OR c.provider_id = auth.uid() OR c.other_user_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;
CREATE POLICY "Participants can send messages" ON public.messages
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = conversation_id
      AND (c.client_id = auth.uid() OR c.provider_id = auth.uid() OR c.other_user_id = auth.uid())
  )
  AND sender_id = auth.uid()
);

-- Realtime: Add messages table to publication for live chat
-- RLS policies above control who can receive changes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;
