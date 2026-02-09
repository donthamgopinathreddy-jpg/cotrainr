-- =========================================
-- INSPECTION QUERIES FOR QUEST SYSTEM
-- =========================================
-- Run these queries in Supabase SQL Editor to inspect current schema
-- =========================================

-- 1. Table definitions (columns, types, defaults)
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'profiles',
    'user_profiles',
    'user_quests',
    'user_quest_settings',
    'user_quest_refills',
    'leaderboard_points',
    'notifications'
  )
ORDER BY table_name, ordinal_position;

-- 2. Indexes
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'user_profiles',
    'user_quests',
    'user_quest_settings',
    'user_quest_refills',
    'leaderboard_points',
    'notifications'
  )
ORDER BY tablename, indexname;

-- 3. Triggers
SELECT 
  trigger_name,
  event_object_table,
  action_statement,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN (
    'profiles',
    'user_profiles',
    'user_quests',
    'user_quest_settings',
    'user_quest_refills',
    'leaderboard_points',
    'notifications'
  )
ORDER BY event_object_table, trigger_name;

-- 4. RLS status
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'user_profiles',
    'user_quests',
    'user_quest_settings',
    'user_quest_refills',
    'leaderboard_points',
    'notifications'
  )
ORDER BY tablename;

-- 5. RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'user_profiles',
    'user_quests',
    'user_quest_settings',
    'user_quest_refills',
    'leaderboard_points',
    'notifications'
  )
ORDER BY tablename, policyname;

-- 6. Foreign key constraints
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
  AND tc.table_name IN (
    'profiles',
    'user_profiles',
    'user_quests',
    'user_quest_settings',
    'user_quest_refills',
    'leaderboard_points',
    'notifications'
  )
ORDER BY tc.table_name, kcu.column_name;
