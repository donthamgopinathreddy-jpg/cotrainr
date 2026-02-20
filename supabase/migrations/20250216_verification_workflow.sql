-- =========================================
-- VERIFICATION WORKFLOW
-- =========================================
-- Idempotent migration for trainer/nutritionist verification
-- Creates: verification-docs bucket, verification_submissions table,
-- RLS, storage policies, approval RPCs, providers.verified trigger
-- =========================================

-- 1) Ensure provider_type enum exists (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'provider_type') THEN
    CREATE TYPE public.provider_type AS ENUM ('trainer', 'nutritionist');
  END IF;
END $$;

-- 2) Create verification-docs storage bucket (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'verification-docs',
  'verification-docs',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- 3) Create verification_submissions table
CREATE TABLE IF NOT EXISTS public.verification_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_type public.provider_type NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  certificate_path TEXT,
  gov_id_path TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewer_id UUID REFERENCES auth.users(id),
  rejection_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique: one active pending per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_verification_submissions_one_pending_per_user
  ON public.verification_submissions (user_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_verification_submissions_user_id ON public.verification_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_submissions_status ON public.verification_submissions(status);
CREATE INDEX IF NOT EXISTS idx_verification_submissions_provider_type ON public.verification_submissions(provider_type);

-- 4) updated_at trigger (table-specific to avoid overriding global helpers)
CREATE OR REPLACE FUNCTION public.set_verification_submissions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_verification_submissions_updated_at ON public.verification_submissions;
CREATE TRIGGER trg_verification_submissions_updated_at
  BEFORE UPDATE ON public.verification_submissions
  FOR EACH ROW EXECUTE FUNCTION public.set_verification_submissions_updated_at();

-- 5) RLS on verification_submissions
ALTER TABLE public.verification_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Providers can select own submissions" ON public.verification_submissions;
CREATE POLICY "Providers can select own submissions"
  ON public.verification_submissions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Providers can insert own pending" ON public.verification_submissions;
CREATE POLICY "Providers can insert own pending"
  ON public.verification_submissions FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND COALESCE(status, 'pending') = 'pending'
  );

-- No UPDATE policy for providers - approval/rejection via RPC only

-- 6) Storage policies for verification-docs
DROP POLICY IF EXISTS "Providers can upload own verification docs" ON storage.objects;
CREATE POLICY "Providers can upload own verification docs"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Providers can read own verification docs" ON storage.objects;
CREATE POLICY "Providers can read own verification docs"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Providers can delete own verification docs" ON storage.objects;
CREATE POLICY "Providers can delete own verification docs"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Service role bypasses RLS by default; no explicit admin policy needed for storage.
-- Retool/Edge Functions using service_role can read all objects.

-- 7) Ensure providers.verified column exists
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS verified boolean NOT NULL DEFAULT false;

-- 8) Trigger: Prevent providers from updating providers.verified
-- Only allow verified update when app.allow_verified_update = 'true' (set by RPC)
CREATE OR REPLACE FUNCTION public.protect_providers_verified()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.verified IS DISTINCT FROM NEW.verified THEN
    IF current_setting('app.allow_verified_update', true) IS DISTINCT FROM 'true' THEN
      NEW.verified := OLD.verified;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_providers_verified ON public.providers;
CREATE TRIGGER trg_protect_providers_verified
  BEFORE UPDATE ON public.providers
  FOR EACH ROW EXECUTE FUNCTION public.protect_providers_verified();

-- 9) Approval RPC - SECURITY DEFINER, service_role only
-- p_reviewer_id: pass from Retool (admin user id) since auth.uid() is NULL with service key
CREATE OR REPLACE FUNCTION public.approve_verification(p_submission_id UUID, p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_provider_type public.provider_type;
  v_row RECORD;
BEGIN
  SELECT user_id, status, provider_type INTO v_row
  FROM public.verification_submissions
  WHERE id = p_submission_id;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission not found');
  END IF;

  IF v_row.status != 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission is not pending');
  END IF;

  v_user_id := v_row.user_id;
  v_provider_type := v_row.provider_type;

  PERFORM set_config('app.allow_verified_update', 'true', true);

  BEGIN
    UPDATE public.verification_submissions
    SET status = 'approved',
        reviewed_at = now(),
        reviewer_id = p_reviewer_id
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, true)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- 10) Rejection RPC - SECURITY DEFINER, service_role only
-- p_reviewer_id: pass from Retool (admin user id) since auth.uid() is NULL with service key
CREATE OR REPLACE FUNCTION public.reject_verification(p_submission_id UUID, p_notes TEXT DEFAULT '', p_reviewer_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_provider_type public.provider_type;
  v_row RECORD;
BEGIN
  SELECT user_id, status, provider_type INTO v_row
  FROM public.verification_submissions
  WHERE id = p_submission_id;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission not found');
  END IF;

  IF v_row.status != 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Submission is not pending');
  END IF;

  v_user_id := v_row.user_id;
  v_provider_type := v_row.provider_type;

  PERFORM set_config('app.allow_verified_update', 'true', true);

  BEGIN
    UPDATE public.verification_submissions
    SET status = 'rejected',
        reviewed_at = now(),
        reviewer_id = p_reviewer_id,
        rejection_notes = NULLIF(TRIM(COALESCE(p_notes, '')), '')
    WHERE id = p_submission_id;

    INSERT INTO public.providers (user_id, provider_type, verified)
    VALUES (v_user_id, v_provider_type, false)
    ON CONFLICT (user_id) DO UPDATE SET verified = EXCLUDED.verified;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_verified_update', '', true);
    RAISE;
  END;

  PERFORM set_config('app.allow_verified_update', '', true);
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- RPC to get signed URLs for admin (service_role) - for Retool/Edge Functions
-- Retool will use service_role; storage.from().createSignedUrl() works with service client.
-- No extra RPC needed - Retool can call storage API directly with service key.

-- 11) Grant execute to service_role only (revoke from authenticated)
REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification(UUID, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification(UUID, TEXT, UUID) TO service_role;

-- 12) RPC for admin to list pending submissions (service_role for Retool)
CREATE OR REPLACE FUNCTION public.list_pending_verifications(p_provider_type public.provider_type DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  provider_type public.provider_type,
  status TEXT,
  certificate_path TEXT,
  gov_id_path TEXT,
  submitted_at TIMESTAMPTZ,
  full_name TEXT,
  email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    vs.id,
    vs.user_id,
    vs.provider_type,
    vs.status,
    vs.certificate_path,
    vs.gov_id_path,
    vs.submitted_at,
    p.full_name,
    au.email
  FROM public.verification_submissions vs
  LEFT JOIN public.profiles p ON p.id = vs.user_id
  LEFT JOIN auth.users au ON au.id = vs.user_id
  WHERE vs.status = 'pending'
    AND (p_provider_type IS NULL OR vs.provider_type = p_provider_type)
  ORDER BY vs.submitted_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_pending_verifications(public.provider_type) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_pending_verifications(public.provider_type) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.list_pending_verifications(public.provider_type) TO service_role;

COMMENT ON TABLE public.verification_submissions IS 'Trainer/nutritionist verification document submissions';
COMMENT ON FUNCTION public.approve_verification(UUID, UUID) IS 'Admin-only: approve verification and set providers.verified=true. p_reviewer_id: admin user id from Retool (auth.uid() is NULL with service key).';
COMMENT ON FUNCTION public.reject_verification(UUID, TEXT, UUID) IS 'Admin-only: reject verification with optional notes. p_reviewer_id: admin user id from Retool.';
