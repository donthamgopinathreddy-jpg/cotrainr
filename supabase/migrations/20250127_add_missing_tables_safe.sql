-- =========================================
-- SAFE MIGRATION: Add Missing Tables for Core Loop
-- =========================================
-- This migration works WITH your existing database structure
-- It only adds missing tables and columns needed for:
-- - Provider discovery (providers, provider_locations)
-- - Lead/request system (leads, conversations, messages)
-- - Quota tracking (weekly_usage)
-- - Subscription plan column fix (plan vs plan_type)
-- =========================================
-- IMPORTANT: This does NOT modify existing tables (profiles, subscriptions structure)
-- =========================================

-- =========================================
-- EXTENSIONS (Enable in Supabase dashboard if not already enabled)
-- =========================================
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- CREATE EXTENSION IF NOT EXISTS "postgis";

-- =========================================
-- HELPER FUNCTIONS
-- =========================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================
-- ENUMS (Create only if they don't exist)
-- =========================================

-- Provider types
DO $$ BEGIN
  CREATE TYPE provider_type AS ENUM ('trainer', 'nutritionist');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Location types
DO $$ BEGIN
  CREATE TYPE location_type AS ENUM ('home', 'gym', 'studio', 'park', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Lead status
DO $$ BEGIN
  CREATE TYPE lead_status AS ENUM ('requested', 'accepted', 'declined', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Subscription plans (for plan column)
DO $$ BEGIN
  CREATE TYPE subscription_plan AS ENUM ('free', 'basic', 'premium');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Subscription status
DO $$ BEGIN
  CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Media kinds
DO $$ BEGIN
  CREATE TYPE media_kind AS ENUM ('image', 'video');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Post visibility
DO $$ BEGIN
  CREATE TYPE post_visibility AS ENUM ('public', 'friends', 'private');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Video session status
DO $$ BEGIN
  CREATE TYPE video_session_status AS ENUM ('scheduled', 'active', 'ended', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- =========================================
-- FIX SUBSCRIPTIONS TABLE
-- =========================================
-- Your current subscriptions table has 'plan_type' (TEXT)
-- We need 'plan' (ENUM) for our RPC functions
-- This adds 'plan' column if missing, and syncs it with 'plan_type' if both exist

DO $$ 
BEGIN
  -- Check if 'plan' column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'subscriptions' 
    AND column_name = 'plan'
  ) THEN
    -- Add 'plan' column
    ALTER TABLE public.subscriptions 
    ADD COLUMN plan subscription_plan;
    
    -- If 'plan_type' exists, migrate data
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'subscriptions' 
      AND column_name = 'plan_type'
    ) THEN
      -- Sync plan_type -> plan
      UPDATE public.subscriptions
      SET plan = CASE 
        WHEN plan_type = 'free' THEN 'free'::subscription_plan
        WHEN plan_type = 'basic' THEN 'basic'::subscription_plan
        WHEN plan_type = 'premium' THEN 'premium'::subscription_plan
        ELSE 'free'::subscription_plan
      END
      WHERE plan IS NULL;
    END IF;
    
    -- Set default and make NOT NULL
    ALTER TABLE public.subscriptions 
    ALTER COLUMN plan SET DEFAULT 'free'::subscription_plan,
    ALTER COLUMN plan SET NOT NULL;
  END IF;
END $$;

-- =========================================
-- NEW TABLES (Only create if they don't exist)
-- =========================================

-- Providers (trainers and nutritionists)
CREATE TABLE IF NOT EXISTS public.providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_type provider_type NOT NULL,
  specialization TEXT[],
  experience_years INTEGER DEFAULT 0,
  hourly_rate NUMERIC(10, 2),
  bio TEXT,
  verified BOOLEAN NOT NULL DEFAULT false,
  rating NUMERIC(3, 2) DEFAULT 0.0,
  total_reviews INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Provider locations (service locations with privacy controls)
CREATE TABLE IF NOT EXISTS public.provider_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  location_type location_type NOT NULL,
  display_name TEXT NOT NULL,
  -- Geo stores approximate for home-private, exact for others
  geo GEOGRAPHY(Point, 4326) NOT NULL,
  radius_km NUMERIC(5, 2) NOT NULL CHECK (radius_km > 0),
  is_public_exact BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Weekly usage (tracks quota usage per week)
CREATE TABLE IF NOT EXISTS public.weekly_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start DATE NOT NULL,
  requests_used INTEGER NOT NULL DEFAULT 0,
  nutritionist_requests_used INTEGER NOT NULL DEFAULT 0,
  video_sessions_used INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, week_start)
);

-- Leads (client requests to providers)
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_type provider_type NOT NULL,
  status lead_status NOT NULL DEFAULT 'requested',
  message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Conversations (created when lead is accepted)
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL UNIQUE REFERENCES public.leads(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  media_url TEXT,
  media_kind media_kind,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================
-- INDEXES
-- =========================================

-- Providers
CREATE INDEX IF NOT EXISTS idx_providers_user_id ON public.providers(user_id);
CREATE INDEX IF NOT EXISTS idx_providers_type ON public.providers(provider_type);
CREATE INDEX IF NOT EXISTS idx_providers_verified ON public.providers(verified) WHERE verified = true;

-- Provider locations
CREATE INDEX IF NOT EXISTS idx_provider_locations_provider_id ON public.provider_locations(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_locations_geo ON public.provider_locations USING GIST(geo);
CREATE INDEX IF NOT EXISTS idx_provider_locations_active ON public.provider_locations(is_active) WHERE is_active = true;
CREATE UNIQUE INDEX IF NOT EXISTS idx_provider_locations_primary ON public.provider_locations(provider_id) WHERE is_primary = true;

-- Subscriptions (for plan column)
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan ON public.subscriptions(plan);

-- Weekly usage
CREATE INDEX IF NOT EXISTS idx_weekly_usage_user_week ON public.weekly_usage(user_id, week_start);

-- Leads
CREATE INDEX IF NOT EXISTS idx_leads_client_id ON public.leads(client_id);
CREATE INDEX IF NOT EXISTS idx_leads_provider_id ON public.leads(provider_id);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_leads_unique_active ON public.leads(client_id, provider_id) WHERE status IN ('requested', 'accepted');

-- Conversations
CREATE INDEX IF NOT EXISTS idx_conversations_client_id ON public.conversations(client_id);
CREATE INDEX IF NOT EXISTS idx_conversations_provider_id ON public.conversations(provider_id);
CREATE INDEX IF NOT EXISTS idx_conversations_lead_id ON public.conversations(lead_id);

-- Messages
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);

-- =========================================
-- TRIGGERS
-- =========================================

-- Updated_at triggers
DROP TRIGGER IF EXISTS trg_providers_updated_at ON public.providers;
CREATE TRIGGER trg_providers_updated_at
  BEFORE UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_provider_locations_updated_at ON public.provider_locations;
CREATE TRIGGER trg_provider_locations_updated_at
  BEFORE UPDATE ON public.provider_locations
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_weekly_usage_updated_at ON public.weekly_usage;
CREATE TRIGGER trg_weekly_usage_updated_at
  BEFORE UPDATE ON public.weekly_usage
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_leads_updated_at ON public.leads;
CREATE TRIGGER trg_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_conversations_updated_at ON public.conversations;
CREATE TRIGGER trg_conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Home location privacy enforcement
CREATE OR REPLACE FUNCTION enforce_home_privacy()
RETURNS TRIGGER AS $$
BEGIN
  -- Home locations cannot be public exact (privacy by default)
  IF NEW.location_type = 'home' AND NEW.is_public_exact = true THEN
    NEW.is_public_exact := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_home_privacy ON public.provider_locations;
CREATE TRIGGER trg_enforce_home_privacy
  BEFORE INSERT OR UPDATE ON public.provider_locations
  FOR EACH ROW
  EXECUTE FUNCTION enforce_home_privacy();

-- Primary location handler
CREATE OR REPLACE FUNCTION handle_primary_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_primary = true AND (OLD IS NULL OR OLD.is_primary = false) THEN
    UPDATE public.provider_locations
    SET is_primary = false
    WHERE provider_id = NEW.provider_id
      AND id != NEW.id
      AND is_primary = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_handle_primary_location ON public.provider_locations;
CREATE TRIGGER trg_handle_primary_location
  BEFORE UPDATE ON public.provider_locations
  FOR EACH ROW
  WHEN (NEW.is_primary = true AND (OLD.is_primary IS NULL OR OLD.is_primary = false))
  EXECUTE FUNCTION handle_primary_location();

-- Enforce provider_type matches profiles.role
-- Note: This works with your existing profiles.role (TEXT) structure
CREATE OR REPLACE FUNCTION public.enforce_provider_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = NEW.user_id;
  
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Profile not found for user_id %', NEW.user_id;
  END IF;
  
  IF v_role = 'client' THEN
    RAISE EXCEPTION 'Clients cannot be providers';
  END IF;
  
  IF NEW.provider_type = 'trainer' AND v_role != 'trainer' THEN
    RAISE EXCEPTION 'provider_type trainer requires profiles.role=trainer';
  END IF;
  
  IF NEW.provider_type = 'nutritionist' AND v_role != 'nutritionist' THEN
    RAISE EXCEPTION 'provider_type nutritionist requires profiles.role=nutritionist';
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_provider_role ON public.providers;
CREATE TRIGGER trg_enforce_provider_role
  BEFORE INSERT OR UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_provider_role();

-- =========================================
-- ROW LEVEL SECURITY (RLS)
-- =========================================

-- Enable RLS on new tables
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Providers policies
DROP POLICY IF EXISTS "Anyone can view providers" ON public.providers;
CREATE POLICY "Anyone can view providers"
  ON public.providers FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Providers can update own provider" ON public.providers;
CREATE POLICY "Providers can update own provider"
  ON public.providers FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Providers can insert own provider" ON public.providers;
CREATE POLICY "Providers can insert own provider"
  ON public.providers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Provider locations policies
-- CRITICAL: Only providers can access their own locations directly
-- Discovery MUST go through nearby_providers() RPC which masks private home geo
DROP POLICY IF EXISTS "Providers can manage own locations" ON public.provider_locations;
CREATE POLICY "Providers can manage own locations"
  ON public.provider_locations FOR ALL
  TO authenticated
  USING (auth.uid() = provider_id)
  WITH CHECK (auth.uid() = provider_id);

-- NO PUBLIC SELECT POLICY - Force discovery through nearby_providers() RPC only

-- Weekly usage policies
DROP POLICY IF EXISTS "Users can view own usage" ON public.weekly_usage;
CREATE POLICY "Users can view own usage"
  ON public.weekly_usage FOR SELECT
  USING (auth.uid() = user_id);

-- No insert/update policies (Edge Functions only)

-- Leads policies
DROP POLICY IF EXISTS "Participants can view leads" ON public.leads;
CREATE POLICY "Participants can view leads"
  ON public.leads FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

DROP POLICY IF EXISTS "Providers can update lead status" ON public.leads;
CREATE POLICY "Providers can update lead status"
  ON public.leads FOR UPDATE
  USING (auth.uid() = provider_id);

-- No insert policy (Edge Functions only)

-- Conversations policies
DROP POLICY IF EXISTS "Participants can view conversations" ON public.conversations;
CREATE POLICY "Participants can view conversations"
  ON public.conversations FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- No insert policy (Edge Functions only)

-- Messages policies
DROP POLICY IF EXISTS "Participants can view messages" ON public.messages;
CREATE POLICY "Participants can view messages"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id
        AND (client_id = auth.uid() OR provider_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;
CREATE POLICY "Participants can send messages"
  ON public.messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id
        AND (client_id = auth.uid() OR provider_id = auth.uid())
    )
    AND sender_id = auth.uid()
  );

-- =========================================
-- RPC FUNCTIONS
-- =========================================

-- Nearby providers (spatial search)
-- CRITICAL: This is the ONLY way to discover providers
-- Privacy: Returns NULL geo for home-private locations
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
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pl.provider_id,
    pl.id AS location_id,
    pl.location_type,
    pl.display_name,
    -- Privacy: Mask geo for private home locations
    CASE 
      WHEN pl.location_type = 'home' AND pl.is_public_exact = false THEN NULL
      ELSE pl.geo
    END AS geo,
    pl.radius_km,
    ST_Distance(
      pl.geo::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) / 1000.0 AS distance_km,
    pl.is_primary,
    p.provider_type,
    p.specialization,
    p.experience_years,
    p.rating,
    p.total_reviews,
    -- Provider identity (from profiles - works with your existing structure)
    COALESCE(pr.display_name, pr.first_name || ' ' || pr.last_name) AS full_name,
    pr.avatar_path AS avatar_url,
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
      (max_distance_km * 1000)::DOUBLE PRECISION
    )
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[]) TO authenticated;

-- =========================================
-- COMMENTS
-- =========================================

COMMENT ON TABLE public.providers IS 'Trainer and nutritionist provider profiles';
COMMENT ON TABLE public.provider_locations IS 'Service locations with privacy controls (home locations never expose exact geo)';
COMMENT ON TABLE public.subscriptions IS 'User subscription plans (plan column added for RPC compatibility)';
COMMENT ON TABLE public.weekly_usage IS 'Weekly quota usage tracking (no client writes, Edge Functions only)';
COMMENT ON TABLE public.leads IS 'Client requests to providers (no client inserts, Edge Functions only)';
COMMENT ON TABLE public.conversations IS 'Chat conversations created when lead is accepted';
COMMENT ON TABLE public.messages IS 'Chat messages between clients and providers';
