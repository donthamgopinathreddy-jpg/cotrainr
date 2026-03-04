-- =========================================
-- Provider Locations: Discovery Logic + Privacy Fix
-- =========================================
-- 1. Enforce BOTH user_search_radius AND provider.radius_km (coverage)
-- 2. Return approximate distance for home+!is_public_exact (not NULL)
-- 3. Add is_distance_approx and coverage_km to RPC response
-- =========================================

CREATE EXTENSION IF NOT EXISTS "postgis";

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
      AND (provider_types IS NULL OR p.provider_type = ANY(provider_types))
      AND (location_types IS NULL OR pl.location_type = ANY(location_types))
      AND (min_rating IS NULL OR p.rating >= min_rating)
      AND (specializations IS NULL OR p.specialization && specializations)
      -- User search radius
      AND ST_DWithin(pl.geo::geography, user_point, (max_distance_km * 1000.0)::DOUBLE PRECISION)
      -- Provider coverage radius (trainer serves within radius_km)
      AND ST_DWithin(pl.geo::geography, user_point, (pl.radius_km * 1000.0)::DOUBLE PRECISION)
  )
  SELECT
    dc.provider_id,
    dc.loc_id AS location_id,
    dc.location_type,
    dc.display_name,
    -- Privacy: Mask geo for home + !is_public_exact
    CASE
      WHEN dc.is_private_home THEN NULL::geography
      ELSE dc.geo
    END AS geo,
    dc.radius_km,
    -- Distance: approximate (rounded to 0.5 km) for private home, exact otherwise
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
  'Discovery RPC. Enforces user max_distance AND provider radius_km. Returns approx distance for home+!is_public_exact.';

REVOKE ALL ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) TO authenticated;
