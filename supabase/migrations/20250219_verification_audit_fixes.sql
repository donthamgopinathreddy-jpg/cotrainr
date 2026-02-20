-- =========================================
-- VERIFICATION AUDIT FIXES
-- =========================================
-- Idempotent patches from verification audit
-- 1) Add storage UPDATE policy for verification-docs (required for upsert)
-- 2) Add gov_id_type to list_pending_verifications RPC
-- =========================================

-- 1) Storage: UPDATE policy for verification-docs (upsert requires it)
DROP POLICY IF EXISTS "Providers can update own verification docs" ON storage.objects;
CREATE POLICY "Providers can update own verification docs"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 2) list_pending_verifications: add gov_id_type for Retool admin
-- Must DROP first: return type changes (gov_id_type added) - CREATE OR REPLACE cannot change it
DROP FUNCTION IF EXISTS public.list_pending_verifications(public.provider_type) CASCADE;

CREATE FUNCTION public.list_pending_verifications(p_provider_type public.provider_type DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  provider_type public.provider_type,
  status TEXT,
  certificate_path TEXT,
  gov_id_path TEXT,
  gov_id_type TEXT,
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
    vs.gov_id_type,
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

-- Harden: re-apply permissions and ownership (CREATE OR REPLACE can reset)
REVOKE ALL ON FUNCTION public.list_pending_verifications(public.provider_type) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_pending_verifications(public.provider_type) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.list_pending_verifications(public.provider_type) TO service_role;
ALTER FUNCTION public.list_pending_verifications(public.provider_type) OWNER TO postgres;

-- Harden approve/reject RPCs (ensure service_role-only after any schema changes)
REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_verification(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification(UUID, UUID) TO service_role;
ALTER FUNCTION public.approve_verification(UUID, UUID) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_verification(UUID, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification(UUID, TEXT, UUID) TO service_role;
ALTER FUNCTION public.reject_verification(UUID, TEXT, UUID) OWNER TO postgres;

-- Verify UPDATE policy exists
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname='storage' AND tablename='objects'
--     AND policyname = 'Providers can update own verification docs';

-- Verify list_pending_verifications returns gov_id_type
--   SELECT * FROM public.list_pending_verifications('trainer') LIMIT 1;
