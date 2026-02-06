-- Migration: Create provider_locations table for trainers and nutritionists
-- This table stores service locations (home, gym, studio, etc.) with privacy controls

-- Create enum for location types
CREATE TYPE location_type_enum AS ENUM ('home', 'gym', 'studio', 'park', 'other');

-- Create provider_locations table
CREATE TABLE IF NOT EXISTS provider_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  location_type location_type_enum NOT NULL,
  display_name TEXT NOT NULL,
  geo GEOGRAPHY(Point, 4326) NOT NULL,
  radius_km NUMERIC(5, 2) NOT NULL CHECK (radius_km > 0),
  is_public_exact BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on provider_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_provider_locations_provider_id ON provider_locations(provider_id);

-- Create index on geo for spatial queries (ST_DWithin)
CREATE INDEX IF NOT EXISTS idx_provider_locations_geo ON provider_locations USING GIST(geo);

-- Create index on is_active for filtering active locations
CREATE INDEX IF NOT EXISTS idx_provider_locations_is_active ON provider_locations(is_active) WHERE is_active = true;

-- Create unique constraint: only one primary location per provider
CREATE UNIQUE INDEX IF NOT EXISTS idx_provider_locations_unique_primary 
ON provider_locations(provider_id) 
WHERE is_primary = true;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_provider_locations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER trigger_provider_locations_updated_at
BEFORE UPDATE ON provider_locations
FOR EACH ROW
EXECUTE FUNCTION update_provider_locations_updated_at();

-- Function to enforce home location privacy (is_public_exact must be false for home)
CREATE OR REPLACE FUNCTION enforce_home_location_privacy()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.location_type = 'home' AND NEW.is_public_exact = true THEN
    RAISE EXCEPTION 'Home locations cannot have is_public_exact = true. Privacy violation.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce home privacy constraint
CREATE TRIGGER trigger_enforce_home_privacy
BEFORE INSERT OR UPDATE ON provider_locations
FOR EACH ROW
EXECUTE FUNCTION enforce_home_location_privacy();

-- Function to handle primary location updates (ensure only one primary)
CREATE OR REPLACE FUNCTION handle_primary_location_update()
RETURNS TRIGGER AS $$
BEGIN
  -- If setting a location as primary, unset all other primary locations for this provider
  IF NEW.is_primary = true AND (OLD.is_primary IS NULL OR OLD.is_primary = false) THEN
    UPDATE provider_locations
    SET is_primary = false
    WHERE provider_id = NEW.provider_id
      AND id != NEW.id
      AND is_primary = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to handle primary location updates
CREATE TRIGGER trigger_handle_primary_location
BEFORE UPDATE ON provider_locations
FOR EACH ROW
WHEN (NEW.is_primary = true AND (OLD.is_primary IS NULL OR OLD.is_primary = false))
EXECUTE FUNCTION handle_primary_location_update();

-- RLS Policies

-- Enable RLS
ALTER TABLE provider_locations ENABLE ROW LEVEL SECURITY;

-- Policy: Providers can insert their own locations
CREATE POLICY "Providers can insert their own locations"
ON provider_locations
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = provider_id);

-- Policy: Providers can update their own locations
CREATE POLICY "Providers can update their own locations"
ON provider_locations
FOR UPDATE
TO authenticated
USING (auth.uid() = provider_id)
WITH CHECK (auth.uid() = provider_id);

-- Policy: Providers can delete their own locations
CREATE POLICY "Providers can delete their own locations"
ON provider_locations
FOR DELETE
TO authenticated
USING (auth.uid() = provider_id);

-- Policy: Providers can select their own locations (full access)
CREATE POLICY "Providers can select their own locations"
ON provider_locations
FOR SELECT
TO authenticated
USING (auth.uid() = provider_id);

-- Policy: Authenticated users can select locations for discovery
-- BUT: Hide exact geo for home locations unless is_public_exact=true
CREATE POLICY "Users can select locations for discovery"
ON provider_locations
FOR SELECT
TO authenticated
USING (
  is_active = true AND
  (
    -- Show exact location if it's public or not a home location
    (is_public_exact = true OR location_type != 'home') OR
    -- For home locations without public exact, only show display_name (geo hidden by view/function)
    (location_type = 'home' AND is_public_exact = false)
  )
);

-- Create a view for public discovery that masks home location geo
CREATE OR REPLACE VIEW provider_locations_public AS
SELECT 
  id,
  provider_id,
  location_type,
  display_name,
  -- Mask geo for home locations that are not public exact
  CASE 
    WHEN location_type = 'home' AND is_public_exact = false THEN NULL
    ELSE geo
  END AS geo,
  radius_km,
  is_public_exact,
  is_active,
  is_primary,
  created_at,
  updated_at
FROM provider_locations
WHERE is_active = true;

-- Grant access to the view
GRANT SELECT ON provider_locations_public TO authenticated;

-- Optional: Create RPC function for nearby providers search
-- This can be used by Discover page for efficient spatial queries
CREATE OR REPLACE FUNCTION nearby_providers(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance_km DOUBLE PRECISION DEFAULT 50.0,
  location_types location_type_enum[] DEFAULT NULL
)
RETURNS TABLE (
  provider_id UUID,
  location_id UUID,
  location_type location_type_enum,
  display_name TEXT,
  geo GEOGRAPHY,
  radius_km NUMERIC,
  distance_km DOUBLE PRECISION,
  is_primary BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pl.provider_id,
    pl.id AS location_id,
    pl.location_type,
    pl.display_name,
    -- Only return exact geo if not a private home location
    CASE 
      WHEN pl.location_type = 'home' AND pl.is_public_exact = false THEN NULL
      ELSE pl.geo
    END AS geo,
    pl.radius_km,
    -- Calculate distance in km
    ST_Distance(
      pl.geo::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) / 1000.0 AS distance_km,
    pl.is_primary
  FROM provider_locations pl
  WHERE 
    pl.is_active = true
    AND (
      location_types IS NULL OR 
      pl.location_type = ANY(location_types)
    )
    AND ST_DWithin(
      pl.geo::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      (max_distance_km * 1000)::DOUBLE PRECISION
    )
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on RPC function
GRANT EXECUTE ON FUNCTION nearby_providers TO authenticated;
