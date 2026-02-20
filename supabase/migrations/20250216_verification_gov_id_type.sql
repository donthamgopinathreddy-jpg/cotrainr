-- =========================================
-- VERIFICATION: Add gov_id_type column
-- =========================================
-- Idempotent patch for verification_submissions
-- =========================================

ALTER TABLE public.verification_submissions
  ADD COLUMN IF NOT EXISTS gov_id_type TEXT;

COMMENT ON COLUMN public.verification_submissions.gov_id_type IS 'Government ID type selected by provider (e.g. Aadhar Card, Passport)';

-- Backfill pending rows with NULL gov_id_type so CHECK constraint can be added safely
UPDATE public.verification_submissions
SET gov_id_type = 'Legacy'
WHERE status = 'pending' AND (gov_id_type IS NULL OR trim(gov_id_type) = '');

-- Optional: require gov_id_type for pending submissions (idempotent)
ALTER TABLE public.verification_submissions
  DROP CONSTRAINT IF EXISTS check_verification_pending_gov_id_type;

ALTER TABLE public.verification_submissions
  ADD CONSTRAINT check_verification_pending_gov_id_type
  CHECK (status <> 'pending' OR (gov_id_type IS NOT NULL AND length(trim(gov_id_type)) > 0));
