-- =============================================================================
-- Legal release: policy version bump, append-only acceptance history,
-- safe existing-user handling (no onboarding loop until re-accept is enabled).
-- Forward-only. Does not modify historical migrations.
-- =============================================================================

-- 1) Current in-app legal document versions (must match LegalDocumentMeta.version)
CREATE OR REPLACE FUNCTION public.current_legal_versions()
RETURNS TABLE(terms_version TEXT, privacy_version TEXT)
LANGUAGE sql
STABLE
AS $$
  SELECT '2026-08-28'::TEXT, '2026-08-28'::TEXT;
$$;

REVOKE ALL ON FUNCTION public.current_legal_versions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_legal_versions() TO anon, authenticated;

-- 2) Product flag: when true, get_onboarding_state requires the current versions.
--    Default false so bumping current_legal_versions does not trap existing users
--    in /auth/complete-profile. Flip to true when mandatory re-acceptance ships.
CREATE OR REPLACE FUNCTION public.require_legal_reacceptance()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT false;
$$;

REVOKE ALL ON FUNCTION public.require_legal_reacceptance() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.require_legal_reacceptance() TO authenticated;

COMMENT ON FUNCTION public.require_legal_reacceptance() IS
  'LEGAL/BUSINESS DECISION: set true when existing users must re-accept the current legal versions before continuing.';

-- 3) Append-only acceptance history (authoritative audit trail)
CREATE TABLE IF NOT EXISTS public.legal_acceptance_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  terms_version TEXT NOT NULL,
  privacy_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source TEXT NOT NULL DEFAULT 'rpc'
    CHECK (source IN ('rpc', 'signup', 'complete_profile', 'reaccept', 'trigger'))
);

CREATE INDEX IF NOT EXISTS legal_acceptance_events_user_accepted_at_idx
  ON public.legal_acceptance_events (user_id, accepted_at DESC);

ALTER TABLE public.legal_acceptance_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own legal acceptance events"
  ON public.legal_acceptance_events;
CREATE POLICY "Users read own legal acceptance events"
  ON public.legal_acceptance_events
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- No direct client writes — SECURITY DEFINER RPCs / triggers only
REVOKE ALL ON TABLE public.legal_acceptance_events FROM PUBLIC;
REVOKE ALL ON TABLE public.legal_acceptance_events FROM anon;
GRANT SELECT ON TABLE public.legal_acceptance_events TO authenticated;
GRANT ALL ON TABLE public.legal_acceptance_events TO service_role;

-- 4) Record acceptance: validate versions, upsert current row, append history.
--    Timestamps are server-generated (now()). auth.uid() binds the row.
CREATE OR REPLACE FUNCTION public.record_legal_acceptance(
  p_terms_version TEXT,
  p_privacy_version TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_terms TEXT;
  v_privacy TEXT;
  v_accepted_at TIMESTAMPTZ := now();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT terms_version, privacy_version INTO v_terms, v_privacy
  FROM public.current_legal_versions();

  IF COALESCE(p_terms_version, '') <> v_terms
     OR COALESCE(p_privacy_version, '') <> v_privacy THEN
    RAISE EXCEPTION 'Legal acceptance versions are outdated';
  END IF;

  INSERT INTO public.legal_acceptances (
    user_id, terms_version, privacy_version, accepted_at, updated_at
  )
  VALUES (v_uid, v_terms, v_privacy, v_accepted_at, v_accepted_at)
  ON CONFLICT (user_id) DO UPDATE SET
    terms_version = EXCLUDED.terms_version,
    privacy_version = EXCLUDED.privacy_version,
    accepted_at = EXCLUDED.accepted_at,
    updated_at = v_accepted_at;
  -- History row is appended by legal_acceptances_history_trg
END;
$$;

ALTER FUNCTION public.record_legal_acceptance(TEXT, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.record_legal_acceptance(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_legal_acceptance(TEXT, TEXT) TO authenticated;

-- 5) Onboarding completeness: avoid version-bump loops for existing acceptors
CREATE OR REPLACE FUNCTION public.get_onboarding_state()
RETURNS TABLE(is_complete BOOLEAN, missing TEXT[])
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_missing TEXT[] := ARRAY[]::TEXT[];
  v_role TEXT;
  v_username TEXT;
  v_dob DATE;
  v_gender TEXT;
  v_height INTEGER;
  v_weight NUMERIC;
  v_goals TEXT[];
  v_legal BOOLEAN := false;
  v_terms TEXT;
  v_privacy TEXT;
  v_specs TEXT[];
  v_legacy BOOLEAN := false;
  v_require_reaccept BOOLEAN := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT false, ARRAY['unauthenticated']::TEXT[];
    RETURN;
  END IF;

  SELECT
    p.username,
    p.role::TEXT,
    p.date_of_birth,
    p.gender,
    p.height_cm,
    p.weight_kg,
    p.fitness_goals
  INTO v_username, v_role, v_dob, v_gender, v_height, v_weight, v_goals
  FROM public.profiles p
  WHERE p.id = v_uid;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, ARRAY['profile']::TEXT[];
    RETURN;
  END IF;

  SELECT terms_version, privacy_version INTO v_terms, v_privacy
  FROM public.current_legal_versions();

  v_require_reaccept := public.require_legal_reacceptance();

  IF v_require_reaccept THEN
    SELECT EXISTS (
      SELECT 1 FROM public.legal_acceptances l
      WHERE l.user_id = v_uid
        AND l.terms_version = v_terms
        AND l.privacy_version = v_privacy
    ) INTO v_legal;
  ELSE
    -- Any prior acceptance satisfies the onboarding gate until re-accept is enabled.
    SELECT EXISTS (
      SELECT 1 FROM public.legal_acceptances l
      WHERE l.user_id = v_uid
    ) INTO v_legal;
  END IF;

  -- Pre-migration email users: body complete, fitness_goals never written.
  v_legacy := (v_goals IS NULL)
    AND v_username IS NOT NULL AND length(trim(v_username)) > 0
    AND v_dob IS NOT NULL
    AND v_height IS NOT NULL
    AND v_weight IS NOT NULL;

  IF v_username IS NULL OR length(trim(v_username)) = 0 THEN
    v_missing := array_append(v_missing, 'username');
  END IF;
  IF v_role IS NULL OR v_role NOT IN ('client', 'trainer', 'nutritionist') THEN
    v_missing := array_append(v_missing, 'role');
  END IF;
  IF v_dob IS NULL THEN
    v_missing := array_append(v_missing, 'dob');
  END IF;
  IF v_gender IS NULL OR length(trim(v_gender)) = 0 THEN
    v_missing := array_append(v_missing, 'gender');
  END IF;
  IF v_height IS NULL THEN
    v_missing := array_append(v_missing, 'height');
  END IF;
  IF v_weight IS NULL THEN
    v_missing := array_append(v_missing, 'weight');
  END IF;
  IF NOT v_legacy AND (
       v_goals IS NULL
       OR cardinality(v_goals) = 0
       OR NOT EXISTS (SELECT 1 FROM unnest(v_goals) g WHERE length(trim(g)) > 0)
     ) THEN
    v_missing := array_append(v_missing, 'goals');
  END IF;
  IF NOT v_legacy AND NOT v_legal THEN
    v_missing := array_append(v_missing, 'legal');
  END IF;

  IF v_role IN ('trainer', 'nutritionist') THEN
    SELECT pr.specialization INTO v_specs
    FROM public.providers pr
    WHERE pr.user_id = v_uid;
    IF v_specs IS NULL
       OR cardinality(v_specs) = 0
       OR NOT EXISTS (SELECT 1 FROM unnest(v_specs) s WHERE length(trim(s)) > 0) THEN
      v_missing := array_append(v_missing, 'specialties');
    END IF;
  END IF;

  RETURN QUERY SELECT (cardinality(v_missing) = 0), v_missing;
END;
$$;

ALTER FUNCTION public.get_onboarding_state() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_onboarding_state() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_onboarding_state() TO authenticated;

COMMENT ON TABLE public.legal_acceptance_events IS
  'Append-only history of Terms/Privacy acceptances. Current versions also live in legal_acceptances.';

-- 6) History for every write path (record_legal_acceptance, complete_cotrainr_profile, etc.)
CREATE OR REPLACE FUNCTION public.legal_acceptances_append_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  INSERT INTO public.legal_acceptance_events (
    user_id, terms_version, privacy_version, accepted_at, source
  )
  VALUES (
    NEW.user_id,
    NEW.terms_version,
    NEW.privacy_version,
    COALESCE(NEW.accepted_at, now()),
    'trigger'
  );
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.legal_acceptances_append_history() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.legal_acceptances_append_history() FROM PUBLIC;

DROP TRIGGER IF EXISTS legal_acceptances_history_trg ON public.legal_acceptances;
CREATE TRIGGER legal_acceptances_history_trg
  AFTER INSERT OR UPDATE OF terms_version, privacy_version, accepted_at
  ON public.legal_acceptances
  FOR EACH ROW
  EXECUTE FUNCTION public.legal_acceptances_append_history();
