-- =========================================
-- DIAGNOSTIC QUERIES FOR CATEGORY ERROR
-- =========================================
-- Run these in Supabase SQL Editor to find the exact issue
-- =========================================

-- A) List columns for relevant tables
SELECT 
  table_schema, 
  table_name, 
  column_name, 
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'quests',
    'user_quests',
    'profiles',
    'posts',
    'challenges',
    'leaderboard_points',
    'achievements',
    'quest_definitions',
    'user_achievements',
    'challenge_members',
    'challenge_progress'
  )
ORDER BY table_name, ordinal_position;

-- B) Find all views that reference 'category'
SELECT 
  schemaname,
  viewname,
  definition
FROM pg_views
WHERE schemaname = 'public'
  AND definition ILIKE '%category%'
ORDER BY viewname;

-- C) Find all functions that reference 'category'
SELECT 
  p.proname AS function_name,
  pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%category%'
ORDER BY p.proname;

-- D) Find all triggers that might reference category
SELECT 
  trigger_schema,
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND action_statement ILIKE '%category%'
ORDER BY event_object_table, trigger_name;

-- E) Check RPC functions specifically (these are most likely culprits)
SELECT 
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'FUNCTION'
  AND routine_definition ILIKE '%category%'
ORDER BY routine_name;

-- F) Check if quest_definitions table exists and has category
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = 'quest_definitions'
    ) THEN 'EXISTS'
    ELSE 'DOES NOT EXIST'
  END AS quest_definitions_table_status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quest_definitions' 
      AND column_name = 'category'
    ) THEN 'HAS category COLUMN'
    ELSE 'NO category COLUMN'
  END AS quest_definitions_category_status;

-- G) Check if quests table exists and has category
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = 'quests'
    ) THEN 'EXISTS'
    ELSE 'DOES NOT EXIST'
  END AS quests_table_status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'category'
    ) THEN 'HAS category COLUMN'
    ELSE 'NO category COLUMN'
  END AS quests_category_status;

-- H) List all tables that have 'category' column
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name = 'category'
ORDER BY table_name;

-- I) Check user_quests foreign key relationships
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  tc.constraint_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name = 'user_quests'
ORDER BY kcu.column_name;

-- J) Test query that might be failing (allocate_daily_quests)
-- This will show the exact error if the function exists
DO $$
BEGIN
  -- Try to call the function to see the error
  PERFORM public.allocate_daily_quests('00000000-0000-0000-0000-000000000000'::UUID);
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error in allocate_daily_quests: %', SQLERRM;
END $$;
