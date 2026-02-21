-- =============================================================================
-- Video Sessions Migration Verification
-- Run AFTER applying 20250215_video_sessions_participants_and_external.sql
--
-- Prerequisite: Run verify_video_sessions_prereqs.sql first. If any result is
-- false, run 20250215_video_sessions_zoom.sql first (creates the Zoom schema).
-- =============================================================================

-- a) Duplicates check (PASS: 0 rows)
SELECT session_id, user_id, COUNT(*)
FROM public.video_session_participants
GROUP BY 1,2 HAVING COUNT(*) > 1;

-- b) Index existence (PASS: 1 row) - requires video_session_participants
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname='public'
  AND tablename='video_session_participants'
  AND indexname='uq_video_session_participants_session_user';

-- c) Provider constraint (PASS: 1 row, definition includes 'external') - requires video_sessions + provider column
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid='public.video_sessions'::regclass
  AND conname='video_sessions_provider_check';

-- d) Column existence (optional; PASS: 2 rows) - requires video_session_participants
SELECT column_name
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name='video_session_participants'
  AND column_name IN ('role','created_at');

-- e) Provider distribution (PASS: all provider in allowed set) - requires video_sessions + provider column
SELECT provider, COUNT(*)
FROM public.video_sessions
GROUP BY 1 ORDER BY 2 DESC;

-- f) Role distribution (optional) - requires video_session_participants
SELECT role, COUNT(*)
FROM public.video_session_participants
GROUP BY 1;
