-- ===========================================================================
-- Cotrainr — video session privilege hardening (MANUAL)
--
-- Run this by pasting it into the Supabase SQL Editor. Do NOT run it through
-- `supabase db push`: the repository migration history is not safe to replay.
--
-- What this does:
--   1. Removes client (anon/authenticated) EXECUTE on
--      public.profile_display_name(uuid).
--   2. Removes client table privileges on the Google credential / OAuth state /
--      create-request tables.
--   3. Prints read-only verification output.
--
-- What this deliberately does NOT do:
--   - No table, column, index, trigger or policy is created, altered or
--     dropped.
--   - No function body is changed.
--   - No RLS policy is added or removed.
--   - No token or credential value is read, logged or returned.
--
-- Idempotent: every statement is a REVOKE or a read-only SELECT, so running it
-- twice is a no-op.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. public.profile_display_name(uuid)
--
-- Rationale: the function is SECURITY DEFINER, SET search_path = public, and
-- reads public.profiles with no actor check, so it deliberately bypasses
-- profiles RLS. It was created with CREATE OR REPLACE FUNCTION and never had
-- privileges revoked, so it still carries the default EXECUTE TO PUBLIC. That
-- lets any client resolve the display name for an arbitrary user id.
--
-- Every caller is a SECURITY DEFINER function owned by the same role
-- (list_my_video_sessions, get_my_video_session, the video-session notify /
-- reminder producers, respond_to_video_session). Those execute as the function
-- owner, so they do not consult the caller's EXECUTE privilege. No Flutter code
-- calls it: the app only ever reads the resolved counterpart_name /
-- participant_names columns those wrappers return.
--
-- Therefore `authenticated` does not need direct EXECUTE, and removing it does
-- not affect video sessions. service_role is granted explicitly so server-side
-- (Edge Function) code keeps a supported path.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.profile_display_name(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.profile_display_name(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.profile_display_name(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.profile_display_name(uuid) TO service_role;

COMMENT ON FUNCTION public.profile_display_name(uuid) IS
  'Internal name resolver. SECURITY DEFINER and bypasses profiles RLS, so it is '
  'server-only: clients must read names through list_my_video_sessions / '
  'get_my_video_session, which scope rows to the caller.';

-- ---------------------------------------------------------------------------
-- 2. Credential and OAuth state tables
--
-- These hold Google refresh/access tokens, PKCE verifiers and pending OAuth
-- state. They are written and read exclusively by Edge Functions using the
-- service role. No client query path exists or should exist, so direct table
-- privileges are removed rather than relying on RLS alone (defence in depth:
-- with zero privileges, a policy mistake is not exploitable).
--
-- video_session_create_requests is the idempotency ledger for
-- create-video-session and is likewise service-role only.
--
-- service_role and the table owner are untouched. No policies are changed.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.user_integrations_google FROM anon, authenticated;
REVOKE ALL ON TABLE public.oauth_pending_states FROM anon, authenticated;
REVOKE ALL ON TABLE public.video_session_create_requests FROM anon, authenticated;

GRANT ALL ON TABLE public.user_integrations_google TO service_role;
GRANT ALL ON TABLE public.oauth_pending_states TO service_role;
GRANT ALL ON TABLE public.video_session_create_requests TO service_role;

COMMIT;

-- ===========================================================================
-- VERIFICATION (read-only — safe to re-run at any time)
-- ===========================================================================

-- A. profile_display_name must expose no anon/authenticated EXECUTE.
--    Expect: exactly one row, service_role.
SELECT
  p.proname,
  p.prosecdef                              AS security_definer,
  pg_get_userbyid(p.proowner)              AS owner,
  a.grantee
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN LATERAL (
  SELECT (aclexplode(p.proacl)).grantee::regrole::text AS grantee
) a ON TRUE
WHERE n.nspname = 'public'
  AND p.proname = 'profile_display_name';

-- B. No client privileges remain on the credential/state/request tables.
--    Expect: zero rows.
SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
    'user_integrations_google',
    'oauth_pending_states',
    'video_session_create_requests'
  )
  AND grantee IN ('anon', 'authenticated')
ORDER BY table_name, grantee, privilege_type;

-- C. The client-facing video session RPCs still work for authenticated users.
--    Expect: both rows present with grantee 'authenticated'.
SELECT
  p.proname,
  (SELECT (aclexplode(p.proacl)).grantee::regrole::text) IS NOT NULL AS has_acl,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('list_my_video_sessions', 'get_my_video_session')
ORDER BY p.proname;

-- D. RLS remains enabled on the session tables (this file must not change it).
--    Expect: relrowsecurity = true for both.
SELECT c.relname, c.relrowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('video_sessions', 'video_session_participants')
ORDER BY c.relname;

-- E. Smoke test as a real client: this must now fail with "permission denied
--    for function profile_display_name". Run it in a session where the role is
--    authenticated, then ROLLBACK.
--
--    BEGIN;
--      SET LOCAL ROLE authenticated;
--      SELECT public.profile_display_name('00000000-0000-0000-0000-000000000000');
--    ROLLBACK;

-- ===========================================================================
-- OPTIONAL — per-participant attendance response in the people list
--
-- NOT REQUIRED. The app is correct without this: when the people RPC does not
-- return response_status, Cotrainr shows no response state for participants
-- whose answer it does not know, instead of guessing.
--
-- Running this makes the group "2 accepted · 1 declined" summary and the
-- per-participant Accepted/Declined chips exact, because it projects each
-- participant's own response instead of leaving the client to infer it from
-- counterpart_response_status (which is a single arbitrary participant's row).
--
-- This needs DROP + CREATE because CREATE OR REPLACE cannot add a column to an
-- existing function's return type. It re-grants exactly the privileges the
-- current function has. Review the live definition first:
--
--   SELECT pg_get_functiondef('public.list_my_video_session_people()'::regprocedure);
--
-- Then, only if the live body matches the repository version, run the DROP /
-- CREATE / GRANT block from that definition with `p.response_status` added to
-- both the RETURNS TABLE list and the SELECT list, and re-apply:
--
--   REVOKE ALL ON FUNCTION public.list_my_video_session_people() FROM PUBLIC;
--   GRANT EXECUTE ON FUNCTION public.list_my_video_session_people()
--     TO authenticated, service_role;
--
-- Do not hand-write the body from memory; copy it from pg_get_functiondef so
-- the deployed row-visibility rules are preserved verbatim.
-- ===========================================================================
