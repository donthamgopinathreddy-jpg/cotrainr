-- Video Sessions: participants unique index + provider 'external'
-- Idempotent. Run after 20250215_video_sessions_zoom.sql

-- 1a) Dedupe: deterministic, ctid-based delete. Handles created_at ties/NULLs, missing created_at.
-- Optional: prefer role='host' when deduplicating (if role column exists).
DO $$
DECLARE
  has_created_at boolean;
  has_role boolean;
BEGIN
  IF to_regclass('public.video_session_participants') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='video_session_participants' AND column_name='created_at'
    ) INTO has_created_at;
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='video_session_participants' AND column_name='role'
    ) INTO has_role;

    IF has_role AND has_created_at THEN
      -- Prefer host, then created_at ASC NULLS LAST, ctid tie-breaker
      WITH ranked AS (
        SELECT ctid,
               row_number() OVER (
                 PARTITION BY session_id, user_id
                 ORDER BY (CASE WHEN role = 'host' THEN 0 ELSE 1 END) ASC,
                          created_at ASC NULLS LAST, ctid ASC
               ) rn
        FROM public.video_session_participants
      )
      DELETE FROM public.video_session_participants v
      USING ranked r
      WHERE v.ctid = r.ctid AND r.rn > 1;
    ELSIF has_role THEN
      WITH ranked AS (
        SELECT ctid,
               row_number() OVER (
                 PARTITION BY session_id, user_id
                 ORDER BY (CASE WHEN role = 'host' THEN 0 ELSE 1 END) ASC, ctid ASC
               ) rn
        FROM public.video_session_participants
      )
      DELETE FROM public.video_session_participants v
      USING ranked r
      WHERE v.ctid = r.ctid AND r.rn > 1;
    ELSIF has_created_at THEN
      WITH ranked AS (
        SELECT ctid,
               row_number() OVER (
                 PARTITION BY session_id, user_id
                 ORDER BY created_at ASC NULLS LAST, ctid ASC
               ) rn
        FROM public.video_session_participants
      )
      DELETE FROM public.video_session_participants v
      USING ranked r
      WHERE v.ctid = r.ctid AND r.rn > 1;
    ELSE
      WITH ranked AS (
        SELECT ctid,
               row_number() OVER (PARTITION BY session_id, user_id ORDER BY ctid ASC) rn
        FROM public.video_session_participants
      )
      DELETE FROM public.video_session_participants v
      USING ranked r
      WHERE v.ctid = r.ctid AND r.rn > 1;
    END IF;
  END IF;
END $$;

-- 1b) Ensure unique (session_id, user_id)
DO $$
BEGIN
  IF to_regclass('public.video_session_participants') IS NOT NULL THEN
    CREATE UNIQUE INDEX IF NOT EXISTS uq_video_session_participants_session_user
      ON public.video_session_participants(session_id, user_id);
  END IF;
END $$;

-- 2) Extend provider CHECK to allow 'external' (paste Zoom link)
-- Only runs if video_sessions has a provider column (20250215_video_sessions_zoom schema).
DO $$
DECLARE
  has_provider boolean;
BEGIN
  IF to_regclass('public.video_sessions') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='video_sessions' AND column_name='provider'
    ) INTO has_provider;

    IF has_provider THEN
      ALTER TABLE public.video_sessions DROP CONSTRAINT IF EXISTS video_sessions_provider_check;
      ALTER TABLE public.video_sessions ADD CONSTRAINT video_sessions_provider_check
        CHECK (provider IN ('zoom','meet','jitsi','manual','external'));
    END IF;
  END IF;
END $$;

/*
-- Verification queries (run manually after migration):

-- Check duplicates (should return 0 rows):
SELECT session_id, user_id, COUNT(*) FROM public.video_session_participants GROUP BY 1,2 HAVING COUNT(*)>1;

-- Check unique index exists:
SELECT indexname FROM pg_indexes WHERE tablename='video_session_participants' AND indexname='uq_video_session_participants_session_user';

-- Check provider constraint exists:
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.video_sessions'::regclass AND conname='video_sessions_provider_check';
*/
