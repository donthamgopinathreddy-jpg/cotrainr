-- Inspection queries for database audit
-- Run these in Supabase SQL Editor to get row counts and write activity

-- 1. Row counts for all public tables
SELECT schemaname, relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- 2. Recent write activity (inserts + updates + deletes)
SELECT relname AS table_name,
       n_tup_ins AS inserts,
       n_tup_upd AS updates,
       n_tup_del AS deletes,
       n_tup_ins + n_tup_upd + n_tup_del AS total_writes
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY total_writes DESC;

-- 3. All triggers on public tables
SELECT tgname AS trigger_name, relname AS table_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' AND NOT t.tgisinternal
ORDER BY relname, tgname;

-- 4. All RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename;

-- 5. Foreign key dependencies (what references each table)
SELECT
  tc.table_name AS child_table,
  kcu.column_name AS child_column,
  ccu.table_name AS parent_table,
  ccu.column_name AS parent_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
