-- =========================================
-- Provider Locations: RPC + Geo Storage Hardening
-- =========================================
-- Idempotent. Does not break provider_locations CRUD. Discovery stays via RPC only.
-- =========================================

-- A) Ensure postgis extension
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =========================================
-- B) Canonical nearby_providers RPC
-- =========================================

CREATE OR REPLACE FUNCTION public.nearby_providers(
  user_lat double precision,
  user_lng double precision,
  max_distance_km double precision DEFAULT 50.0,
  provider_types provider_type[] DEFAULT NULL,
  location_types location_type[] DEFAULT NULL
)
RETURNS TABLE (
  provider_id uuid,
  location_id uuid,
  location_type location_type,
  display_name text,
  geo geography,
  radius_km numeric,
  distance_km double precision,
  is_primary boolean,
  provider_type provider_type,
  specialization text[],
  experience_years integer,
  rating numeric,
  total_reviews integer,
  full_name text,
  avatar_url text,
  verified boolean
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
    -- D) Privacy: geo NULL for home + !is_public_exact
    CASE
      WHEN pl.location_type = 'home'::location_type AND pl.is_public_exact = false THEN NULL::geography
      ELSE pl.geo
    END AS geo,
    pl.radius_km,
    -- D) Privacy: distance_km NULL for home + !is_public_exact (avoid triangulation)
    CASE
      WHEN pl.location_type = 'home'::location_type AND pl.is_public_exact = false THEN NULL::double precision
      ELSE (ST_Distance(
        pl.geo::geography,
        ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
      ) / 1000.0)::double precision
    END AS distance_km,
    pl.is_primary,
    p.provider_type,
    p.specialization,
    p.experience_years,
    p.rating,
    p.total_reviews,
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
      (max_distance_km * 1000.0)::double precision
    )
  ORDER BY (distance_km IS NULL) ASC, distance_km ASC;
END;
$$;

-- C) Harden function
ALTER FUNCTION public.nearby_providers(double precision, double precision, double precision, provider_type[], location_type[])
  OWNER TO postgres;

REVOKE ALL ON FUNCTION public.nearby_providers(double precision, double precision, double precision, provider_type[], location_type[])
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.nearby_providers(double precision, double precision, double precision, provider_type[], location_type[])
  TO authenticated;

COMMENT ON FUNCTION public.nearby_providers(double precision, double precision, double precision, provider_type[], location_type[]) IS
  'Canonical discovery RPC. Masks geo and distance_km for home+!is_public_exact.';

-- =========================================
-- 3) Geo storage hardening
-- =========================================
-- AUDIT: Flutter (provider_location_model.dart:79) sends geo as WKT string:
--   'geo': 'POINT($longitude $latitude)'
-- via direct Supabase .from('provider_locations').insert(json) / .update(json).
-- PostGIS geography type accepts WKT text via implicit cast; no trigger added.
-- Column provider_locations.geo is GEOGRAPHY(Point,4326) NOT NULL.
-- No change to repository write format; WKT is correctly handled by Postgres.
-- =========================================

-- =========================================
-- REPO AUDIT SUMMARY (migration 20250228)
-- =========================================
-- RPC signature: 5 args (user_lat, user_lng, max_distance_km, provider_types, location_types)
--   - Matches Flutter provider_locations_repository.dart fetchNearbyProviders params.
--
-- Function owner/permissions:
--   - OWNER TO postgres
--   - REVOKE ALL FROM PUBLIC
--   - GRANT EXECUTE TO authenticated
--
-- Privacy for home+!is_public_exact:
--   - geo => NULL::geography in RETURN payload
--   - distance_km => NULL::double precision (avoid triangulation)
--   - ORDER BY (distance_km IS NULL) ASC, distance_km ASC
--
-- Geo write: Flutter sends WKT string "POINT(lng lat)" via direct insert/update.
-- PostGIS accepts WKT. No trigger added. No repository change.
-- =========================================
