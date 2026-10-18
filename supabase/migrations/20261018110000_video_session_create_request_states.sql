-- Video-session create ledger states.
-- NOT APPLIED. Do not include this file in supabase db push until remote
-- migration history is reconciled with the repository.
--
-- Existing grants stay service-role only. This migration does not add
-- policies or EXECUTE grants. RLS remains enabled from 20260817.

ALTER TABLE public.video_session_create_requests
  ADD COLUMN IF NOT EXISTS status text,
  ADD COLUMN IF NOT EXISTS external_space_id text,
  ADD COLUMN IF NOT EXISTS join_url text,
  ADD COLUMN IF NOT EXISTS failure_code text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS request_fingerprint text,
  ADD COLUMN IF NOT EXISTS claim_generation bigint,
  ADD COLUMN IF NOT EXISTS meet_attempt text;

-- A stored session_id proves the old writer finished the insert.
-- A null session_id does not: it is either a deleted session (ON DELETE
-- SET NULL) or an unknown prior row. Do not call that completed.
UPDATE public.video_session_create_requests
SET status = 'completed',
    meet_attempt = COALESCE(meet_attempt, 'none'),
    claim_generation = COALESCE(claim_generation, 0),
    updated_at = COALESCE(updated_at, created_at, now())
WHERE status IS NULL
  AND session_id IS NOT NULL;

UPDATE public.video_session_create_requests
SET status = 'uncertain',
    meet_attempt = COALESCE(meet_attempt, 'none'),
    claim_generation = COALESCE(claim_generation, 0),
    updated_at = COALESCE(updated_at, created_at, now())
WHERE status IS NULL
  AND session_id IS NULL;

ALTER TABLE public.video_session_create_requests
  ALTER COLUMN status SET DEFAULT 'pending',
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN updated_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET NOT NULL,
  ALTER COLUMN claim_generation SET DEFAULT 1,
  ALTER COLUMN claim_generation SET NOT NULL,
  ALTER COLUMN meet_attempt SET DEFAULT 'none',
  ALTER COLUMN meet_attempt SET NOT NULL;

ALTER TABLE public.video_session_create_requests
  DROP CONSTRAINT IF EXISTS video_session_create_requests_status_check;

ALTER TABLE public.video_session_create_requests
  ADD CONSTRAINT video_session_create_requests_status_check
  CHECK (status IN ('pending', 'completed', 'failed', 'uncertain'));

ALTER TABLE public.video_session_create_requests
  DROP CONSTRAINT IF EXISTS video_session_create_requests_meet_attempt_check;

ALTER TABLE public.video_session_create_requests
  ADD CONSTRAINT video_session_create_requests_meet_attempt_check
  CHECK (meet_attempt IN ('none', 'ambiguous', 'confirmed_absent'));

ALTER TABLE public.video_session_create_requests
  DROP CONSTRAINT IF EXISTS video_session_create_requests_generation_positive;

ALTER TABLE public.video_session_create_requests
  ADD CONSTRAINT video_session_create_requests_generation_positive
  CHECK (claim_generation >= 0);

REVOKE ALL ON TABLE public.video_session_create_requests FROM PUBLIC, anon, authenticated;

COMMENT ON COLUMN public.video_session_create_requests.status IS
  'pending: one fenced owner. completed: session was saved; do not create or notify again. failed: Meet was confirmed not to have created a space. uncertain: historical session_id was null and must not be retried automatically.';

COMMENT ON COLUMN public.video_session_create_requests.request_fingerprint IS
  'SHA-256 of host, sorted participants, UTC start, duration, title, and provider. Null only on rows written before this column. A different fingerprint for the same client_request_id is a conflict.';

COMMENT ON COLUMN public.video_session_create_requests.claim_generation IS
  'Fencing token. Writers must update WHERE claim_generation matches the generation they observed. Takeover and failed-retry increment it.';

COMMENT ON COLUMN public.video_session_create_requests.meet_attempt IS
  'none: Meet has not been called. ambiguous: the HTTP call started or its result was unreadable; do not create another space. confirmed_absent: Meet rejected the create.';

COMMENT ON COLUMN public.video_session_create_requests.external_space_id IS
  'Google Meet space name saved before video_sessions insert. A retry must reuse it. Meet spaces.create has no idempotency key.';
