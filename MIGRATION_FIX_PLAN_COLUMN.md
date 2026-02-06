# Migration Fix: Plan Column Error

## Error
```
ERROR: 42703: column "plan" does not exist
```

## Cause
The `subscriptions` table may have been created in a previous migration attempt without the `plan` column. When using `CREATE TABLE IF NOT EXISTS`, PostgreSQL won't add missing columns to an existing table.

## Fix Applied
Added a check after table creation to ensure the `plan` column exists:

```sql
-- Ensure plan column exists (in case table was created without it)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'subscriptions' 
    AND column_name = 'plan'
  ) THEN
    ALTER TABLE public.subscriptions 
    ADD COLUMN plan subscription_plan NOT NULL DEFAULT 'free';
  END IF;
END $$;
```

## Alternative Solution (if error persists)

If you still get the error, you can manually fix it:

1. **Check if table exists without column:**
   ```sql
   SELECT column_name 
   FROM information_schema.columns 
   WHERE table_schema = 'public' 
   AND table_name = 'subscriptions';
   ```

2. **If `plan` column is missing, add it:**
   ```sql
   ALTER TABLE public.subscriptions 
   ADD COLUMN plan subscription_plan NOT NULL DEFAULT 'free';
   ```

3. **Or drop and recreate (if safe - will lose data):**
   ```sql
   DROP TABLE IF EXISTS public.subscriptions CASCADE;
   -- Then re-run the migration
   ```

## Verification

After running the migration, verify the column exists:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'subscriptions' 
AND column_name = 'plan';
```

Should return:
```
column_name | data_type
------------|----------
plan        | USER-DEFINED
```
