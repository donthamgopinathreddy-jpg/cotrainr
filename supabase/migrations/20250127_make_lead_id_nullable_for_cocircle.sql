-- =========================================
-- MAKE lead_id NULLABLE FOR COCIRCLE MESSAGING
-- =========================================
-- This migration allows cocircle users to message each other
-- without requiring a lead_id (which is only for client-provider conversations)

-- Make lead_id nullable in conversations table
DO $$ 
BEGIN
  -- Check if lead_id is currently NOT NULL
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'conversations' 
    AND column_name = 'lead_id'
    AND is_nullable = 'NO'
  ) THEN
    -- Remove the NOT NULL constraint
    ALTER TABLE public.conversations 
    ALTER COLUMN lead_id DROP NOT NULL;
    
    -- Remove the UNIQUE constraint if it exists (since we can have multiple conversations without leads)
    -- But keep it for conversations with leads
    -- We'll add a partial unique index instead
    DROP INDEX IF EXISTS conversations_lead_id_key;
    
    -- Create a partial unique index that only enforces uniqueness when lead_id is NOT NULL
    CREATE UNIQUE INDEX IF NOT EXISTS conversations_lead_id_unique 
    ON public.conversations(lead_id) 
    WHERE lead_id IS NOT NULL;
    
    RAISE NOTICE 'Made lead_id nullable in conversations table';
  ELSE
    RAISE NOTICE 'lead_id is already nullable or column does not exist';
  END IF;
END $$;

-- Add a comment explaining the change
COMMENT ON COLUMN public.conversations.lead_id IS 'Lead ID for client-provider conversations. NULL for cocircle user-to-user messaging.';
