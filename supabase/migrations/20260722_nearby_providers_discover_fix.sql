-- Discover fix: stop excluding valid trainers via provider coverage radius,
-- include trainers without coordinates when they are verified+discoverable,
-- and dedupe to one row per provider (nearest location).
--
-- Root causes addressed:
-- 1. Dual ST_DWithin (client max_distance AND pl.radius_km) hid trainers
--    whose coverage radius (often default 5 km) was smaller than client distance.
-- 2. INNER requirement on provider_locations excluded trainers with no geo.
-- 3. Multiple active locations produced duplicate cards for one trainer.

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
  WITH eligible AS (
    SELECT
      p.user_id,
      p.provider_type,
      p.specialization,
      p.experience_years,
      p.rating,
      p.total_reviews,
      p.verified,
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
        specializations IS NULL
        OR cardinality(specializations) = 0
        OR p.specialization && specializations
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
      -- Client search radius only (provider radius_km is informational coverage).
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
    CASE
      WHEN c.is_private_home THEN NULL::geography
      ELSE c.geo
    END AS geo,
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
    c.verified
  FROM combined c
  ORDER BY distance_km ASC NULLS LAST, full_name ASC NULLS LAST;
END;
$$;

COMMENT ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) IS
  'Discovery RPC. verified+discoverable providers; client max_distance only; includes trainers without coordinates; one row per provider.';

-- Browse / no-GPS discovery: same eligibility, no distance filter.
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
  verified BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
        specializations IS NULL
        OR cardinality(specializations) = 0
        OR p.specialization && specializations
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
    CASE
      WHEN pl.is_private_home THEN NULL::geography
      ELSE pl.geo
    END AS geo,
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
    e.verified
  FROM eligible e
  LEFT JOIN primary_loc pl ON pl.provider_id = e.user_id
  ORDER BY e.rating DESC NULLS LAST, e.full_name ASC NULLS LAST;
END;
$$;

COMMENT ON FUNCTION public.discover_providers(provider_type[], NUMERIC, TEXT[], INTEGER) IS
  'Browse discovery without client GPS. Same verified+discoverable eligibility as nearby_providers.';

ALTER FUNCTION public.nearby_providers(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]
) OWNER TO postgres;

ALTER FUNCTION public.discover_providers(
  provider_type[], NUMERIC, TEXT[], INTEGER
) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[], NUMERIC, TEXT[]) TO authenticated;

REVOKE ALL ON FUNCTION public.discover_providers(provider_type[], NUMERIC, TEXT[], INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.discover_providers(provider_type[], NUMERIC, TEXT[], INTEGER) TO authenticated;
