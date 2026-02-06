# Migration Fix: client_id Column Error

## Error
```
ERROR: 42703: column "client_id" does not exist
```

## Cause
The `leads` or `conversations` table may have been created in a previous migration attempt without the `client_id` column. When using `CREATE TABLE IF NOT EXISTS`, PostgreSQL won't add missing columns to an existing table.

## Fix Applied
Added checks after table creation to ensure the `client_id` column exists for both `leads` and `conversations` tables.

## If Error Persists

### Option 1: Drop and Recreate (if safe - will lose data)
```sql
-- Drop tables that depend on leads first
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.video_sessions CASCADE;

-- Drop leads table
DROP TABLE IF EXISTS public.leads CASCADE;

-- Then re-run the migration
```

### Option 2: Manually Add Column (if table is empty)
```sql
-- Check if table exists and is empty
SELECT COUNT(*) FROM public.leads;

-- If count is 0, add the column
ALTER TABLE public.leads 
ADD COLUMN client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

-- Same for conversations
SELECT COUNT(*) FROM public.conversations;
ALTER TABLE public.conversations 
ADD COLUMN client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
```

### Option 3: Check All Required Columns
Run this to see what columns are missing:
```sql
-- Check leads table
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'leads'
ORDER BY column_name;

-- Check conversations table
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'conversations'
ORDER BY column_name;
```

## Required Columns for leads
- `id` (UUID, PRIMARY KEY)
- `client_id` (UUID, NOT NULL, FK to auth.users)
- `provider_id` (UUID, NOT NULL, FK to auth.users)
- `provider_type` (provider_type enum, NOT NULL)
- `status` (lead_status enum, NOT NULL, DEFAULT 'requested')
- `message` (TEXT, nullable)
- `created_at` (TIMESTAMPTZ, NOT NULL)
- `updated_at` (TIMESTAMPTZ, NOT NULL)

## Required Columns for conversations
- `id` (UUID, PRIMARY KEY)
- `lead_id` (UUID, NOT NULL, UNIQUE, FK to leads)
- `client_id` (UUID, NOT NULL, FK to auth.users)
- `provider_id` (UUID, NOT NULL, FK to auth.users)
- `created_at` (TIMESTAMPTZ, NOT NULL)
- `updated_at` (TIMESTAMPTZ, NOT NULL)
