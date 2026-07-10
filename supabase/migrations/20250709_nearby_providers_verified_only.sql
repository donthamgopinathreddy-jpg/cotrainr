-- Discovery hardening: verified + discoverable providers only.
-- Replaces nearby_providers with visibility filters.
--
-- JOIN NOTE: provider_locations.provider_id stores auth.users.id
-- (= providers.user_id). It is NOT providers.id where that column exists.
-- Join: providers.user_id = provider_locations.provider_id

CREATE EXTENSION IF NOT EXISTS "postgis";

-- Hide from Discover without revoking verified badge or deleting locations.
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS discoverable BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.providers.discoverable IS
  'When false, provider is hidden from nearby_providers/Discover but may remain verified.';

CREATE INDEX IF NOT EXISTS idx_providers_discoverable_verified
  ON public.providers (discoverable, verified)
  WHERE discoverable = true AND verified = true;

-- Drop legacy 5-arg overload (no verified filter, no min_rating/specializations).
DROP FUNCTION IF EXISTS public.nearby_providers(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[]
);
DROP FUNCTION IF EXISTS public.nearby_providers(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, public.provider_type[], public.location_type[]
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
  verified BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_point GEOGRAPHY;
BEGIN
  user_point := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;

  RETURN QUERY
  WITH dist_calc AS (
    SELECT
      pl.provider_id,
      pl.id AS loc_id,
      pl.location_type,
      pl.display_name,
      pl.geo,
      pl.radius_km,
      pl.is_primary,
      p.provider_type,
      p.specialization,
      p.experience_years,
      p.rating,
      p.total_reviews,
      pr.full_name,
      pr.avatar_url,
      p.verified,
      (ST_Distance(pl.geo::geography, user_point) / 1000.0)::DOUBLE PRECISION AS raw_distance,
      (pl.location_type = 'home'::location_type AND pl.is_public_exact = false) AS is_private_home
    FROM public.provider_locations pl
    JOIN public.providers p ON p.user_id = pl.provider_id
    JOIN public.profiles pr ON pr.id = p.user_id
    WHERE
      pl.is_active = true
      AND pl.geo IS NOT NULL
      AND p.verified IS TRUE
      AND p.discoverable IS TRUE
      AND (
        provider_types IS NULL
        OR cardinality(provider_types) = 0
        OR p.provider_type = ANY(provider_types)
      )
      AND (
        location_types IS NULL
        OR cardinality(location_types) = 0
        OR pl.location_type = ANY(location_types)
      )
      AND (min_rating IS NULL OR p.rating >= min_rating)
      AND (specializations IS NULL OR p.specialization && specializations)
      AND ST_DWithin(pl.geo::geography, user_point, (max_distance_km * 1000.0)::DOUBLE PRECISION)
      AND ST_DWithin(pl.geo::geography, user_point, (pl.radius_km * 1000.0)::DOUBLE PRECISION)
  )
  SELECT
    dc.provider_id,
    dc.loc_id AS location_id,
    dc.location_type,
    dc.display_name,
    CASE
      WHEN dc.is_private_home THEN NULL::geography
      ELSE dc.geo
    END AS geo,
    dc.radius_km,
    CASE
      WHEN dc.is_private_home THEN (ROUND(dc.raw_distance * 2.0) / 2.0)::DOUBLE PRECISION
      ELSE dc.raw_distance
    END AS distance_km,
    dc.is_private_home AS is_distance_approx,
    dc.radius_km AS coverage_km,
    dc.is_primary,
    dc.provider_type,
    dc.specialization,
    dc.experience_years,
    dc.rating,
    dc.total_reviews,
    dc.full_name,
    dc.avatar_url,
    dc.verified
  FROM dist_calc dc
  ORDER BY distance_km ASC;
END;
$$;

COMMENT ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) IS
  'Discovery RPC. Requires verified + discoverable provider, active location, and distance/coverage match.';

ALTER FUNCTION public.nearby_providers(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]
) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) TO authenticated;
