-- =========================================
-- Provider Locations: Canonical RPC + Geo Storage Hardening
-- =========================================
-- GOALS:
-- 1. Canonical nearby_providers RPC (5-arg) used by all Flutter callers
-- 2. Use profiles.full_name and profiles.avatar_url (canonical columns)
-- 3. Preserve privacy: home + !is_public_exact => geo NULL in response
-- 4. Ensure geo storage: WKT 'POINT(lng lat)' is accepted; add trigger fallback
-- =========================================

-- Ensure postgis is available
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Geo storage: Client sends geo as 'POINT(lng lat)' (WKT). PostGIS accepts this.
-- Column is NOT NULL. No trigger needed.

-- =========================================
-- 2. CANONICAL nearby_providers RPC
-- =========================================
-- CREATE OR REPLACE ensures the 5-arg (provider_types, location_types) version exists.
-- Any older 4-arg overload (location_type_enum[]) will remain but Flutter uses this one.

CREATE OR REPLACE FUNCTION public.nearby_providers(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance_km DOUBLE PRECISION DEFAULT 50.0,
  provider_types provider_type[] DEFAULT NULL,
  location_types location_type[] DEFAULT NULL
)
RETURNS TABLE (
  provider_id UUID,
  location_id UUID,
  location_type location_type,
  display_name TEXT,
  geo GEOGRAPHY,
  radius_km NUMERIC,
  distance_km DOUBLE PRECISION,
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
BEGIN
  RETURN QUERY
  SELECT
    pl.provider_id,
    pl.id AS location_id,
    pl.location_type,
    pl.display_name,
    -- Privacy: Mask geo for home + !is_public_exact
    CASE
      WHEN pl.location_type = 'home'::location_type AND pl.is_public_exact = false THEN NULL::geography
      ELSE pl.geo
    END AS geo,
    pl.radius_km,
    (ST_Distance(
      pl.geo::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) / 1000.0)::DOUBLE PRECISION AS distance_km,
    pl.is_primary,
    p.provider_type,
    p.specialization,
    p.experience_years,
    p.rating,
    p.total_reviews,
    -- Use profiles.full_name, avatar_url (canonical columns)
    pr.full_name,
    pr.avatar_url,
    p.verified
  FROM public.provider_locations pl
  JOIN public.providers p ON p.user_id = pl.provider_id
  JOIN public.profiles pr ON pr.id = p.user_id
  WHERE
    pl.is_active = true
    AND pl.geo IS NOT NULL
    AND (provider_types IS NULL OR p.provider_type = ANY(provider_types))
    AND (location_types IS NULL OR pl.location_type = ANY(location_types))
    AND ST_DWithin(
      pl.geo::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      (max_distance_km * 1000.0)::DOUBLE PRECISION
    )
  ORDER BY distance_km ASC;
END;
$$;

COMMENT ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[]) IS
  'Canonical discovery RPC. Masks geo for home+!is_public_exact. Use profiles.full_name, avatar_url.';

REVOKE ALL ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[]) TO authenticated;
