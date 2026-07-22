-- =========================================
-- Minimal professional provider profile upgrade
-- =========================================
-- Reuses providers.user_id as canonical provider id.
-- Adds headline/session_modes/languages/accepting_new_clients,
-- provider_certifications, specialty id normalisation,
-- and bio backfill profiles.bio <- providers.bio when empty.
-- =========================================

-- 1) New provider professional columns
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS professional_headline TEXT;

ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS session_modes TEXT[] NOT NULL DEFAULT '{}';

ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS languages TEXT[] NOT NULL DEFAULT '{}';

ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS accepting_new_clients BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.providers.professional_headline IS
  'Short public headline, e.g. Calisthenics and Strength Coach';
COMMENT ON COLUMN public.providers.session_modes IS
  'How the provider works: online, provider_location, client_location, outdoor, group_session';
COMMENT ON COLUMN public.providers.languages IS
  'Languages the provider can coach in';
COMMENT ON COLUMN public.providers.accepting_new_clients IS
  'When false, profile remains public but requests should be discouraged';

-- 2) Specialty label → canonical id mapping for existing TEXT[] values
CREATE OR REPLACE FUNCTION public.normalize_provider_specialty(raw TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v TEXT;
BEGIN
  v := lower(trim(COALESCE(raw, '')));
  IF v = '' THEN
    RETURN NULL;
  END IF;

  RETURN CASE v
    WHEN 'gym' THEN 'personal_training'
    WHEN 'personal trainer' THEN 'personal_training'
    WHEN 'personal training' THEN 'personal_training'
    WHEN 'strength' THEN 'strength_training'
    WHEN 'strength training' THEN 'strength_training'
    WHEN 'cardio' THEN 'cardio_fitness'
    WHEN 'hiit' THEN 'hiit'
    WHEN 'boxing' THEN 'boxing'
    WHEN 'yoga' THEN 'yoga'
    WHEN 'pilates' THEN 'pilates'
    WHEN 'zumba' THEN 'zumba'
    WHEN 'calisthenics' THEN 'calisthenics'
    WHEN 'weight loss' THEN 'weight_management'
    WHEN 'sports nutrition' THEN 'sports_nutrition'
    WHEN 'clinical' THEN 'clinical_nutrition'
    WHEN 'plant-based' THEN 'plant_based_nutrition'
    WHEN 'plant based' THEN 'plant_based_nutrition'
    WHEN 'lifestyle' THEN 'lifestyle_nutrition'
    WHEN 'meal planning' THEN 'meal_planning'
    WHEN 'diabetes care' THEN 'diabetes_nutrition'
    ELSE
      -- Already-canonical ids contain underscores and no spaces
      CASE
        WHEN v ~ '^[a-z0-9_]+$' THEN v
        ELSE raw  -- preserve unknown custom labels as-is
      END
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.normalize_provider_specialization_array(arr TEXT[])
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  item TEXT;
  mapped TEXT;
  out_arr TEXT[] := '{}';
BEGIN
  IF arr IS NULL THEN
    RETURN '{}';
  END IF;
  FOREACH item IN ARRAY arr LOOP
    mapped := public.normalize_provider_specialty(item);
    IF mapped IS NOT NULL AND NOT (mapped = ANY (out_arr)) THEN
      out_arr := array_append(out_arr, mapped);
    END IF;
  END LOOP;
  RETURN out_arr;
END;
$$;

UPDATE public.providers
SET specialization = public.normalize_provider_specialization_array(specialization)
WHERE specialization IS NOT NULL
  AND cardinality(specialization) > 0;

-- 3) Bio: prefer profiles.bio; backfill from providers.bio when profile bio empty
UPDATE public.profiles pr
SET bio = NULLIF(trim(p.bio), '')
FROM public.providers p
WHERE pr.id = p.user_id
  AND (pr.bio IS NULL OR trim(pr.bio) = '')
  AND p.bio IS NOT NULL
  AND trim(p.bio) <> '';

-- 4) Certifications metadata (public summaries; no private file paths)
CREATE TABLE IF NOT EXISTS public.provider_certifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.providers(user_id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  issuing_organization TEXT,
  issue_year INTEGER,
  expiry_year INTEGER,
  credential_id TEXT,
  verification_status TEXT NOT NULL DEFAULT 'unverified'
    CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected')),
  is_public BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT provider_certifications_name_len CHECK (char_length(trim(name)) > 0),
  CONSTRAINT provider_certifications_years_ok CHECK (
    (issue_year IS NULL OR (issue_year >= 1950 AND issue_year <= 2100))
    AND (expiry_year IS NULL OR (expiry_year >= 1950 AND expiry_year <= 2100))
    AND (issue_year IS NULL OR expiry_year IS NULL OR expiry_year >= issue_year)
  )
);

CREATE INDEX IF NOT EXISTS idx_provider_certifications_provider
  ON public.provider_certifications (provider_id);

CREATE INDEX IF NOT EXISTS idx_provider_certifications_public
  ON public.provider_certifications (provider_id)
  WHERE is_public = true;

DROP TRIGGER IF EXISTS trg_provider_certifications_updated_at
  ON public.provider_certifications;
CREATE TRIGGER trg_provider_certifications_updated_at
  BEFORE UPDATE ON public.provider_certifications
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.provider_certifications ENABLE ROW LEVEL SECURITY;

-- Providers manage own metadata; cannot self-set verified
DROP POLICY IF EXISTS "Providers manage own certifications" ON public.provider_certifications;
CREATE POLICY "Providers manage own certifications"
  ON public.provider_certifications
  FOR ALL
  TO authenticated
  USING (auth.uid() = provider_id)
  WITH CHECK (
    auth.uid() = provider_id
    AND verification_status = 'unverified'
  );

-- Clients read only public summaries for discoverable verified providers
DROP POLICY IF EXISTS "Clients read public certifications" ON public.provider_certifications;
CREATE POLICY "Clients read public certifications"
  ON public.provider_certifications
  FOR SELECT
  TO authenticated
  USING (
    is_public = true
    AND (
      auth.uid() = provider_id
      OR EXISTS (
        SELECT 1
        FROM public.providers p
        WHERE p.user_id = provider_certifications.provider_id
          AND p.verified IS TRUE
          AND p.discoverable IS TRUE
      )
    )
  );

-- Block providers from updating verification_status to verified via direct UPDATE
CREATE OR REPLACE FUNCTION public.protect_certification_verification_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.verification_status IS DISTINCT FROM NEW.verification_status
     AND current_setting('app.allow_cert_verification_update', true) IS DISTINCT FROM 'true'
  THEN
    -- Providers may only keep unverified / pending-request style values set by themselves
    IF NEW.verification_status = 'verified' THEN
      RAISE EXCEPTION 'Providers cannot self-verify certifications';
    END IF;
    IF auth.uid() = NEW.provider_id AND NEW.verification_status NOT IN ('unverified', 'pending') THEN
      RAISE EXCEPTION 'Invalid certification verification_status for provider update';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_certification_verification_status
  ON public.provider_certifications;
CREATE TRIGGER trg_protect_certification_verification_status
  BEFORE UPDATE ON public.provider_certifications
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_certification_verification_status();

-- Providers may update own rows but RLS WITH CHECK forces verification_status=unverified on write.
-- Allow providers to edit metadata while preserving existing verification_status via trigger:
CREATE OR REPLACE FUNCTION public.preserve_cert_verification_on_provider_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('app.allow_cert_verification_update', true) IS DISTINCT FROM 'true' THEN
    IF auth.uid() = NEW.provider_id THEN
      NEW.verification_status := OLD.verification_status;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_preserve_cert_verification_on_provider_update
  ON public.provider_certifications;
CREATE TRIGGER trg_preserve_cert_verification_on_provider_update
  BEFORE UPDATE ON public.provider_certifications
  FOR EACH ROW
  EXECUTE FUNCTION public.preserve_cert_verification_on_provider_update();

-- Fix RLS: providers need UPDATE with preserved status. Replace FOR ALL with split policies.
DROP POLICY IF EXISTS "Providers manage own certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers select own certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers insert own certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers update own certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers delete own certifications" ON public.provider_certifications;

CREATE POLICY "Providers select own certifications"
  ON public.provider_certifications FOR SELECT TO authenticated
  USING (auth.uid() = provider_id);

CREATE POLICY "Providers insert own certifications"
  ON public.provider_certifications FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = provider_id
    AND verification_status IN ('unverified', 'pending')
  );

CREATE POLICY "Providers update own certifications"
  ON public.provider_certifications FOR UPDATE TO authenticated
  USING (auth.uid() = provider_id)
  WITH CHECK (auth.uid() = provider_id);

CREATE POLICY "Providers delete own certifications"
  ON public.provider_certifications FOR DELETE TO authenticated
  USING (auth.uid() = provider_id);

-- Service role / admin bypasses RLS for Retool verification of certs.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.provider_certifications TO authenticated;
GRANT ALL ON public.provider_certifications TO service_role;

-- 5) Providers professional field update policy
-- Ensure providers can update own professional columns (not verified/discoverable).
DROP POLICY IF EXISTS "Providers can update own provider" ON public.providers;
CREATE POLICY "Providers can update own provider"
  ON public.providers
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Protect verified/discoverable from provider self-update (existing verified trigger covers verified).
CREATE OR REPLACE FUNCTION public.protect_providers_discoverable()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.discoverable IS DISTINCT FROM NEW.discoverable THEN
    IF current_setting('app.allow_verified_update', true) IS DISTINCT FROM 'true' THEN
      NEW.discoverable := OLD.discoverable;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_providers_discoverable ON public.providers;
CREATE TRIGGER trg_protect_providers_discoverable
  BEFORE UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_providers_discoverable();

-- Authenticated clients can read provider professional public fields
-- (existing "Anyone can view providers" SELECT policy already allows this).

-- 6) Extend discover RPCs with headline + session_modes for card indicators
-- Recreate nearby_providers / discover_providers return columns via replace in next statements
-- (keep eligibility logic from 20260722_nearby_providers_discover_fix.sql).

-- Drop before recreate: return type changed (added headline/session_modes/accepting).
DROP FUNCTION IF EXISTS public.nearby_providers(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]
);
DROP FUNCTION IF EXISTS public.discover_providers(
  provider_type[], NUMERIC, TEXT[], INTEGER
);

CREATE OR REPLACE FUNCTION public.nearby_providers(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance_km DOUBLE PRECISION DEFAULT 50.0,
  provider_types provider_type[] DEFAULT NULL,
  location_types location_type[] DEFAULT NULL,
  min_rating NUMERIC DEFAULT NULL,
  specializations TEXT[] DEFAULT NULL
)
RETURNS TABLE (
  provider_id UUID,
  location_id UUID,
  location_type location_type,
  display_name TEXT,
  geo GEOGRAPHY,
  radius_km NUMERIC,
  distance_km DOUBLE PRECISION,
  is_distance_approx BOOLEAN,
  coverage_km NUMERIC,
  is_primary BOOLEAN,
  provider_type provider_type,
  specialization TEXT[],
  experience_years INTEGER,
  rating NUMERIC,
  total_reviews INTEGER,
  full_name TEXT,
  avatar_url TEXT,
  verified BOOLEAN,
  professional_headline TEXT,
  session_modes TEXT[],
  accepting_new_clients BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_point GEOGRAPHY;
  norm_specs TEXT[];
BEGIN
  user_point := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;
  norm_specs := public.normalize_provider_specialization_array(specializations);

  RETURN QUERY
  WITH eligible AS (
    SELECT
      p.user_id,
      p.provider_type,
      p.specialization,
      p.experience_years,
      p.rating,
      p.total_reviews,
      p.verified,
      p.professional_headline,
      p.session_modes,
      p.accepting_new_clients,
      pr.full_name,
      pr.avatar_url
    FROM public.providers p
    JOIN public.profiles pr ON pr.id = p.user_id
    WHERE
      p.verified IS TRUE
      AND p.discoverable IS TRUE
      AND (
        provider_types IS NULL
        OR cardinality(provider_types) = 0
        OR p.provider_type = ANY(provider_types)
      )
      AND (min_rating IS NULL OR p.rating >= min_rating)
      AND (
        norm_specs IS NULL
        OR cardinality(norm_specs) = 0
        OR p.specialization && norm_specs
      )
  ),
  located AS (
    SELECT DISTINCT ON (pl.provider_id)
      pl.provider_id,
      pl.id AS loc_id,
      pl.location_type,
      pl.display_name,
      pl.geo,
      pl.radius_km,
      pl.is_primary,
      e.provider_type,
      e.specialization,
      e.experience_years,
      e.rating,
      e.total_reviews,
      e.full_name,
      e.avatar_url,
      e.verified,
      e.professional_headline,
      e.session_modes,
      e.accepting_new_clients,
      (ST_Distance(pl.geo::geography, user_point) / 1000.0)::DOUBLE PRECISION AS raw_distance,
      (pl.location_type = 'home'::location_type AND pl.is_public_exact = false) AS is_private_home
    FROM public.provider_locations pl
    JOIN eligible e ON e.user_id = pl.provider_id
    WHERE
      pl.is_active = true
      AND pl.geo IS NOT NULL
      AND (
        location_types IS NULL
        OR cardinality(location_types) = 0
        OR pl.location_type = ANY(location_types)
      )
      AND ST_DWithin(
        pl.geo::geography,
        user_point,
        (max_distance_km * 1000.0)::DOUBLE PRECISION
      )
    ORDER BY
      pl.provider_id,
      ST_Distance(pl.geo::geography, user_point) ASC,
      pl.is_primary DESC NULLS LAST
  ),
  unlocated AS (
    SELECT
      e.user_id AS provider_id,
      NULL::UUID AS loc_id,
      NULL::location_type AS location_type,
      NULL::TEXT AS display_name,
      NULL::geography AS geo,
      NULL::NUMERIC AS radius_km,
      NULL::BOOLEAN AS is_primary,
      e.provider_type,
      e.specialization,
      e.experience_years,
      e.rating,
      e.total_reviews,
      e.full_name,
      e.avatar_url,
      e.verified,
      e.professional_headline,
      e.session_modes,
      e.accepting_new_clients,
      NULL::DOUBLE PRECISION AS raw_distance,
      false AS is_private_home
    FROM eligible e
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.provider_locations pl
      WHERE pl.provider_id = e.user_id
        AND pl.is_active = true
        AND pl.geo IS NOT NULL
    )
  ),
  combined AS (
    SELECT * FROM located
    UNION ALL
    SELECT * FROM unlocated
  )
  SELECT
    c.provider_id,
    c.loc_id AS location_id,
    c.location_type,
    c.display_name,
    CASE WHEN c.is_private_home THEN NULL::geography ELSE c.geo END AS geo,
    c.radius_km,
    CASE
      WHEN c.raw_distance IS NULL THEN NULL::DOUBLE PRECISION
      WHEN c.is_private_home THEN (ROUND(c.raw_distance * 2.0) / 2.0)::DOUBLE PRECISION
      ELSE c.raw_distance
    END AS distance_km,
    c.is_private_home AS is_distance_approx,
    c.radius_km AS coverage_km,
    COALESCE(c.is_primary, false) AS is_primary,
    c.provider_type,
    c.specialization,
    c.experience_years,
    c.rating,
    c.total_reviews,
    c.full_name,
    c.avatar_url,
    c.verified,
    c.professional_headline,
    c.session_modes,
    COALESCE(c.accepting_new_clients, true) AS accepting_new_clients
  FROM combined c
  ORDER BY distance_km ASC NULLS LAST, full_name ASC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.discover_providers(
  provider_types provider_type[] DEFAULT NULL,
  min_rating NUMERIC DEFAULT NULL,
  specializations TEXT[] DEFAULT NULL,
  result_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  provider_id UUID,
  location_id UUID,
  location_type location_type,
  display_name TEXT,
  geo GEOGRAPHY,
  radius_km NUMERIC,
  distance_km DOUBLE PRECISION,
  is_distance_approx BOOLEAN,
  coverage_km NUMERIC,
  is_primary BOOLEAN,
  provider_type provider_type,
  specialization TEXT[],
  experience_years INTEGER,
  rating NUMERIC,
  total_reviews INTEGER,
  full_name TEXT,
  avatar_url TEXT,
  verified BOOLEAN,
  professional_headline TEXT,
  session_modes TEXT[],
  accepting_new_clients BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  norm_specs TEXT[];
BEGIN
  norm_specs := public.normalize_provider_specialization_array(specializations);

  RETURN QUERY
  WITH eligible AS (
    SELECT
      p.user_id,
      p.provider_type,
      p.specialization,
      p.experience_years,
      p.rating,
      p.total_reviews,
      p.verified,
      p.professional_headline,
      p.session_modes,
      p.accepting_new_clients,
      pr.full_name,
      pr.avatar_url
    FROM public.providers p
    JOIN public.profiles pr ON pr.id = p.user_id
    WHERE
      p.verified IS TRUE
      AND p.discoverable IS TRUE
      AND (
        provider_types IS NULL
        OR cardinality(provider_types) = 0
        OR p.provider_type = ANY(provider_types)
      )
      AND (min_rating IS NULL OR p.rating >= min_rating)
      AND (
        norm_specs IS NULL
        OR cardinality(norm_specs) = 0
        OR p.specialization && norm_specs
      )
    ORDER BY p.rating DESC NULLS LAST, pr.full_name ASC NULLS LAST
    LIMIT GREATEST(COALESCE(result_limit, 50), 1)
  ),
  primary_loc AS (
    SELECT DISTINCT ON (pl.provider_id)
      pl.provider_id,
      pl.id AS loc_id,
      pl.location_type,
      pl.display_name,
      pl.geo,
      pl.radius_km,
      pl.is_primary,
      (pl.location_type = 'home'::location_type AND pl.is_public_exact = false) AS is_private_home
    FROM public.provider_locations pl
    JOIN eligible e ON e.user_id = pl.provider_id
    WHERE pl.is_active = true
    ORDER BY pl.provider_id, pl.is_primary DESC NULLS LAST, pl.created_at DESC NULLS LAST
  )
  SELECT
    e.user_id AS provider_id,
    pl.loc_id AS location_id,
    pl.location_type,
    pl.display_name,
    CASE WHEN pl.is_private_home THEN NULL::geography ELSE pl.geo END AS geo,
    pl.radius_km,
    NULL::DOUBLE PRECISION AS distance_km,
    COALESCE(pl.is_private_home, false) AS is_distance_approx,
    pl.radius_km AS coverage_km,
    COALESCE(pl.is_primary, false) AS is_primary,
    e.provider_type,
    e.specialization,
    e.experience_years,
    e.rating,
    e.total_reviews,
    e.full_name,
    e.avatar_url,
    e.verified,
    e.professional_headline,
    e.session_modes,
    COALESCE(e.accepting_new_clients, true) AS accepting_new_clients
  FROM eligible e
  LEFT JOIN primary_loc pl ON pl.provider_id = e.user_id
  ORDER BY e.rating DESC NULLS LAST, e.full_name ASC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) TO authenticated;

REVOKE ALL ON FUNCTION public.discover_providers(provider_type[], NUMERIC, TEXT[], INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.discover_providers(provider_type[], NUMERIC, TEXT[], INTEGER) TO authenticated;

-- =========================================
-- Rollback notes (manual; do not run in prod without restore plan)
-- =========================================
-- 1. Restore prior nearby_providers / discover_providers from
--    20260722_nearby_providers_discover_fix.sql (or schema dump).
-- 2. DROP TABLE public.provider_certifications CASCADE;
-- 3. DROP FUNCTION public.normalize_provider_specialty(TEXT);
--    DROP FUNCTION public.normalize_provider_specialization_array(TEXT[]);
--    DROP FUNCTION public.protect_certification_verification_status();
--    DROP FUNCTION public.preserve_cert_verification_on_provider_update();
--    DROP FUNCTION public.protect_providers_discoverable();
-- 4. ALTER TABLE public.providers
--      DROP COLUMN IF EXISTS professional_headline,
--      DROP COLUMN IF EXISTS session_modes,
--      DROP COLUMN IF EXISTS languages,
--      DROP COLUMN IF EXISTS accepting_new_clients;
-- 5. Specialty backfill and profiles.bio backfill are not automatically reversible.
-- =========================================
