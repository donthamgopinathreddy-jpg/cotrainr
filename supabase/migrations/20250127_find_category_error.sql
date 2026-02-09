-- =========================================
-- FIND EXACT CATEGORY ERROR SOURCE
-- =========================================
-- Run this in Supabase SQL Editor
-- Paste the FULL output here
-- =========================================

-- STEP 1: Check which tables have category column
SELECT 
  'Tables with category column:' AS check_type,
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name = 'category'
ORDER BY table_name;

-- STEP 2: Check user_quests structure
SELECT 
  'user_quests columns:' AS check_type,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_quests'
ORDER BY ordinal_position;

-- STEP 3: Check quests table structure  
SELECT 
  'quests columns:' AS check_type,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'quests'
ORDER BY ordinal_position;

-- STEP 4: List ALL RPC functions and check for category references
SELECT 
  'RPC Functions:' AS check_type,
  routine_name,
  CASE 
    WHEN routine_definition ILIKE '%category%' THEN 'REFERENCES category'
    ELSE 'No category reference'
  END AS category_usage
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- STEP 5: Get full definition of functions that use category
SELECT 
  'Function Definition:' AS check_type,
  p.proname AS function_name,
  pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%category%'
ORDER BY p.proname;

-- STEP 6: Test if allocate_daily_quests function exists and what it references
SELECT 
  'Function Test:' AS check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'allocate_daily_quests'
    ) THEN 'EXISTS'
    ELSE 'DOES NOT EXIST'
  END AS allocate_daily_quests_status;

-- STEP 7: Check for any views using category
SELECT 
  'Views:' AS check_type,
  schemaname,
  viewname,
  CASE 
    WHEN definition ILIKE '%category%' THEN definition
    ELSE 'No category reference'
  END AS view_definition
FROM pg_views
WHERE schemaname = 'public'
ORDER BY viewname;

-- STEP 8: Check if there are any materialized views
SELECT 
  'Materialized Views:' AS check_type,
  schemaname,
  matviewname,
  definition
FROM pg_matviews
WHERE schemaname = 'public'
  AND definition ILIKE '%category%'
ORDER BY matviewname;

-- STEP 9: Check user_quests foreign keys to see what it references
SELECT 
  'Foreign Keys:' AS check_type,
  tc.table_name,
  kcu.column_name AS local_column,
  ccu.table_name AS referenced_table,
  ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name = 'user_quests';

-- STEP 10: Try to manually test the INSERT that might be failing
-- This will show the exact error
DO $$
DECLARE
  test_user_id UUID := '00000000-0000-0000-0000-000000000000';
  test_quest_id TEXT := 'test_quest';
BEGIN
  -- Try the INSERT pattern used in allocate_daily_quests
  BEGIN
    INSERT INTO public.user_quests (
      user_id,
      quest_definition_id,
      type,
      category,
      difficulty,
      status,
      progress_target,
      reward_xp,
      reward_coins,
      assigned_at,
      expires_at
    ) VALUES (
      test_user_id,
      test_quest_id,
      'daily',
      'steps',  -- category value
      'easy',   -- difficulty value
      'available',
      100.0,
      50,
      0,
      NOW(),
      NOW() + INTERVAL '1 day'
    );
    RAISE NOTICE 'INSERT succeeded - user_quests.category column exists';
    ROLLBACK;  -- Don't actually insert
  EXCEPTION
    WHEN undefined_column THEN
      RAISE NOTICE 'ERROR: user_quests.category column does NOT exist';
      RAISE;
    WHEN OTHERS THEN
      RAISE NOTICE 'Other error: %', SQLERRM;
      RAISE;
  END;
END $$;
