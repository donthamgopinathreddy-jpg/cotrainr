-- =============================================================================
-- Video Sessions: Prerequisite Check
-- Run this FIRST. If any column is false, run 20250215_video_sessions_zoom.sql
-- before the hardening migration and verification.
-- =============================================================================

SELECT
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='video_session_participants') AS "video_session_participants exists",
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='video_sessions') AS "video_sessions exists",
  EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='video_sessions' AND column_name='provider') AS "video_sessions.provider exists";
