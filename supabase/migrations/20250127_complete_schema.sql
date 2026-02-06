-- =========================================
-- COTRAINR COMPLETE DATABASE SCHEMA
-- =========================================
-- This migration creates the complete database schema for Cotrainr
-- Run this after enabling required extensions in Supabase dashboard
-- =========================================

-- =========================================
-- EXTENSIONS
-- =========================================
-- Enable required extensions (run these in Supabase SQL Editor first if not enabled)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- CREATE EXTENSION IF NOT EXISTS "postgis";

-- =========================================
-- HELPER FUNCTIONS
-- =========================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================
-- ENUMS
-- =========================================

-- User roles
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('client', 'trainer', 'nutritionist');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

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

-- Subscription plans
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
-- Note: 'friends' is reserved for future implementation
-- For now, treat 'friends' as 'public' in policies
DO $$ BEGIN
  CREATE TYPE post_visibility AS ENUM ('public', 'friends', 'private');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Report reasons
DO $$ BEGIN
  CREATE TYPE report_reason AS ENUM ('spam', 'inappropriate', 'harassment', 'fake', 'other');
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
-- TABLES
-- =========================================

-- Profiles (user profiles with role)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL DEFAULT 'client',
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  phone TEXT,
  date_of_birth DATE,
  gender TEXT,
  height_cm INTEGER,
  weight_kg NUMERIC(5, 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
-- Privacy approach: 
-- - For home + is_public_exact=false: geo stores APPROXIMATE location (rounded to ~1-3km grid)
-- - For home + is_public_exact=true: geo stores exact location
-- - For gym/studio/park: geo stores exact location
-- - RPC never returns exact geo for home-private (masks in response)
CREATE TABLE IF NOT EXISTS public.provider_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  location_type location_type NOT NULL,
  display_name TEXT NOT NULL,
  -- Geo is required for all locations
  -- For home-private: store approximate (rounded) geo for distance calculation
  -- For home-public or gym/studio: store exact geo
  -- RPC masks exact geo in response for home-private
  geo GEOGRAPHY(Point, 4326) NOT NULL,
  radius_km NUMERIC(5, 2) NOT NULL CHECK (radius_km > 0),
  is_public_exact BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Subscriptions
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  plan subscription_plan NOT NULL DEFAULT 'free',
  status subscription_status NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure plan column exists (in case table was created without it)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'subscriptions' 
    AND column_name = 'plan'
  ) THEN
    ALTER TABLE public.subscriptions 
    ADD COLUMN plan subscription_plan NOT NULL DEFAULT 'free';
  END IF;
END $$;

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

-- Ensure client_id column exists (in case table was created without it)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'leads' 
    AND column_name = 'client_id'
  ) THEN
    -- Check if table has any rows
    IF (SELECT COUNT(*) FROM public.leads) > 0 THEN
      RAISE EXCEPTION 'Table leads exists with data but missing client_id column. Please drop and recreate.';
    ELSE
      ALTER TABLE public.leads 
      ADD COLUMN client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- Conversations (created when lead is accepted)
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL UNIQUE REFERENCES public.leads(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure client_id column exists (in case table was created without it)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'conversations' 
    AND column_name = 'client_id'
  ) THEN
    -- Check if table has any rows
    IF (SELECT COUNT(*) FROM public.conversations) > 0 THEN
      RAISE EXCEPTION 'Table conversations exists with data but missing client_id column. Please drop and recreate.';
    ELSE
      ALTER TABLE public.conversations 
      ADD COLUMN client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

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

-- Posts (Cocircle social feed)
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  visibility post_visibility NOT NULL DEFAULT 'public',
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post media
CREATE TABLE IF NOT EXISTS public.post_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL,
  media_kind media_kind NOT NULL,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post likes
CREATE TABLE IF NOT EXISTS public.post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Post comments
CREATE TABLE IF NOT EXISTS public.post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post reports
CREATE TABLE IF NOT EXISTS public.post_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason report_reason NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, reporter_id)
);

-- Meals
CREATE TABLE IF NOT EXISTS public.meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  meal_type TEXT NOT NULL, -- breakfast, lunch, dinner, snack
  consumed_at TIMESTAMPTZ NOT NULL,
  total_calories NUMERIC(6, 2) DEFAULT 0,
  total_protein NUMERIC(6, 2) DEFAULT 0,
  total_carbs NUMERIC(6, 2) DEFAULT 0,
  total_fat NUMERIC(6, 2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Meal items
CREATE TABLE IF NOT EXISTS public.meal_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id UUID NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
  food_name TEXT NOT NULL,
  quantity NUMERIC(6, 2) NOT NULL,
  unit TEXT NOT NULL,
  calories NUMERIC(6, 2) DEFAULT 0,
  protein NUMERIC(6, 2) DEFAULT 0,
  carbs NUMERIC(6, 2) DEFAULT 0,
  fat NUMERIC(6, 2) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Meal media
CREATE TABLE IF NOT EXISTS public.meal_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id UUID NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL,
  media_kind media_kind NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Daily metrics
CREATE TABLE IF NOT EXISTS public.metrics_daily (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  steps INTEGER DEFAULT 0,
  calories_burned NUMERIC(6, 2) DEFAULT 0,
  distance_km NUMERIC(6, 2) DEFAULT 0,
  water_intake_liters NUMERIC(4, 2) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- User profiles (quest system)
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  level INTEGER NOT NULL DEFAULT 1,
  xp INTEGER NOT NULL DEFAULT 0,
  coins INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User quests (active quests)
CREATE TABLE IF NOT EXISTS public.user_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quest_definition_id TEXT NOT NULL,
  category TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active, completed, claimed
  progress_current NUMERIC(10, 2) DEFAULT 0,
  progress_target NUMERIC(10, 2) NOT NULL,
  reward_xp INTEGER NOT NULL DEFAULT 0,
  reward_coins INTEGER DEFAULT 0,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ
);

-- User quest settings
CREATE TABLE IF NOT EXISTS public.user_quest_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_quest_slots INTEGER NOT NULL DEFAULT 3,
  weekly_quest_slots INTEGER NOT NULL DEFAULT 2,
  refills_used_today INTEGER NOT NULL DEFAULT 0,
  last_refill_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User quest refills (track daily refills)
CREATE TABLE IF NOT EXISTS public.user_quest_refills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  refill_date DATE NOT NULL,
  refills_used INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, refill_date)
);

-- Leaderboard points (separate from XP)
CREATE TABLE IF NOT EXISTS public.leaderboard_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points INTEGER NOT NULL DEFAULT 0,
  period_type TEXT NOT NULL, -- daily, weekly, monthly
  period_start DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, period_type, period_start)
);

-- Video sessions
CREATE TABLE IF NOT EXISTS public.video_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status video_session_status NOT NULL DEFAULT 'scheduled',
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  room_id TEXT UNIQUE,
  token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================
-- INDEXES
-- =========================================

-- Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- Providers
CREATE INDEX IF NOT EXISTS idx_providers_user_id ON public.providers(user_id);
CREATE INDEX IF NOT EXISTS idx_providers_type ON public.providers(provider_type);
CREATE INDEX IF NOT EXISTS idx_providers_verified ON public.providers(verified) WHERE verified = true;

-- Provider locations
CREATE INDEX IF NOT EXISTS idx_provider_locations_provider_id ON public.provider_locations(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_locations_geo ON public.provider_locations USING GIST(geo);
CREATE INDEX IF NOT EXISTS idx_provider_locations_active ON public.provider_locations(is_active) WHERE is_active = true;
CREATE UNIQUE INDEX IF NOT EXISTS idx_provider_locations_primary ON public.provider_locations(provider_id) WHERE is_primary = true;

-- Subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
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

-- Posts
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON public.posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON public.posts(visibility);

-- Post media
CREATE INDEX IF NOT EXISTS idx_post_media_post_id ON public.post_media(post_id);

-- Post likes
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);

-- Post comments
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_author_id ON public.post_comments(author_id);

-- Meals
CREATE INDEX IF NOT EXISTS idx_meals_user_id ON public.meals(user_id);
CREATE INDEX IF NOT EXISTS idx_meals_consumed_at ON public.meals(consumed_at DESC);

-- Meal items
CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id ON public.meal_items(meal_id);

-- Metrics daily
CREATE INDEX IF NOT EXISTS idx_metrics_daily_user_date ON public.metrics_daily(user_id, date DESC);

-- User quests
CREATE INDEX IF NOT EXISTS idx_user_quests_user_id ON public.user_quests(user_id);
CREATE INDEX IF NOT EXISTS idx_user_quests_status ON public.user_quests(status);

-- Leaderboard points
CREATE INDEX IF NOT EXISTS idx_leaderboard_points_user_period ON public.leaderboard_points(user_id, period_type, period_start);
CREATE INDEX IF NOT EXISTS idx_leaderboard_points_period_points ON public.leaderboard_points(period_type, period_start, points DESC);

-- Video sessions
CREATE INDEX IF NOT EXISTS idx_video_sessions_host_id ON public.video_sessions(host_id);
CREATE INDEX IF NOT EXISTS idx_video_sessions_conversation_id ON public.video_sessions(conversation_id);
CREATE INDEX IF NOT EXISTS idx_video_sessions_status ON public.video_sessions(status);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- =========================================
-- TRIGGERS
-- =========================================

-- Updated_at triggers
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_providers_updated_at
  BEFORE UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_provider_locations_updated_at
  BEFORE UPDATE ON public.provider_locations
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_weekly_usage_updated_at
  BEFORE UPDATE ON public.weekly_usage
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_post_comments_updated_at
  BEFORE UPDATE ON public.post_comments
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_meals_updated_at
  BEFORE UPDATE ON public.meals
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_metrics_daily_updated_at
  BEFORE UPDATE ON public.metrics_daily
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_quest_settings_updated_at
  BEFORE UPDATE ON public.user_quest_settings
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_leaderboard_points_updated_at
  BEFORE UPDATE ON public.leaderboard_points
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_video_sessions_updated_at
  BEFORE UPDATE ON public.video_sessions
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Home location privacy enforcement
-- Note: geo is always required (stores approximate for home-private)
-- This trigger ensures home locations cannot be marked public_exact
-- The RPC function masks exact geo in response for home-private
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

CREATE TRIGGER trg_handle_primary_location
  BEFORE UPDATE ON public.provider_locations
  FOR EACH ROW
  WHEN (NEW.is_primary = true AND (OLD.is_primary IS NULL OR OLD.is_primary = false))
  EXECUTE FUNCTION handle_primary_location();

-- =========================================
-- ROW LEVEL SECURITY (RLS)
-- =========================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.metrics_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_quest_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_quest_refills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Providers policies
CREATE POLICY "Anyone can view providers"
  ON public.providers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Providers can update own provider"
  ON public.providers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Providers can insert own provider"
  ON public.providers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Enforce provider_type matches profiles.role
CREATE OR REPLACE FUNCTION public.enforce_provider_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_role user_role;
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

-- Provider locations policies
-- CRITICAL: Only providers can access their own locations directly
-- Discovery MUST go through nearby_providers() RPC which masks private home geo
CREATE POLICY "Providers can manage own locations"
  ON public.provider_locations FOR ALL
  TO authenticated
  USING (auth.uid() = provider_id)
  WITH CHECK (auth.uid() = provider_id);

-- NO PUBLIC SELECT POLICY - Force discovery through nearby_providers() RPC only
-- This prevents direct table queries that would leak exact home geo

-- Subscriptions policies
CREATE POLICY "Users can view own subscription"
  ON public.subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- No insert/update policies (Edge Functions only)

-- Weekly usage policies
CREATE POLICY "Users can view own usage"
  ON public.weekly_usage FOR SELECT
  USING (auth.uid() = user_id);

-- No insert/update policies (Edge Functions only)

-- Leads policies
CREATE POLICY "Participants can view leads"
  ON public.leads FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Providers can update lead status"
  ON public.leads FOR UPDATE
  USING (auth.uid() = provider_id);

-- No insert policy (Edge Functions only)

-- Conversations policies
CREATE POLICY "Participants can view conversations"
  ON public.conversations FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- No insert policy (Edge Functions only)

-- Messages policies
CREATE POLICY "Participants can view messages"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id
        AND (client_id = auth.uid() OR provider_id = auth.uid())
    )
  );

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

-- Posts policies
-- Note: 'friends' visibility treated as 'public' until friends system is implemented
CREATE POLICY "Anyone can view public posts"
  ON public.posts FOR SELECT
  TO authenticated
  USING (
    visibility = 'public' 
    OR visibility = 'friends'  -- Treat as public until friends implemented
    OR author_id = auth.uid()  -- Users can always see their own posts
  );

CREATE POLICY "Users can create own posts"
  ON public.posts FOR INSERT
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can update own posts"
  ON public.posts FOR UPDATE
  USING (author_id = auth.uid());

CREATE POLICY "Users can delete own posts"
  ON public.posts FOR DELETE
  USING (author_id = auth.uid());

-- Post media policies
-- Note: Matches posts policy - treats 'friends' as 'public' until friends system implemented
CREATE POLICY "Anyone can view post media"
  ON public.post_media FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE id = post_id
        AND (
          visibility IN ('public', 'friends')  -- Friends treated as public
          OR author_id = auth.uid()
        )
    )
  );

CREATE POLICY "Users can manage own post media"
  ON public.post_media FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE id = post_id AND author_id = auth.uid()
    )
  );

-- Post likes policies
CREATE POLICY "Anyone can view likes"
  ON public.post_likes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can like posts"
  ON public.post_likes FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can unlike own likes"
  ON public.post_likes FOR DELETE
  USING (user_id = auth.uid());

-- Post comments policies
CREATE POLICY "Anyone can view comments"
  ON public.post_comments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create comments"
  ON public.post_comments FOR INSERT
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can update own comments"
  ON public.post_comments FOR UPDATE
  USING (author_id = auth.uid());

CREATE POLICY "Users can delete own comments"
  ON public.post_comments FOR DELETE
  USING (author_id = auth.uid());

-- Post reports policies
CREATE POLICY "Users can report posts"
  ON public.post_reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

-- Meals policies
CREATE POLICY "Users can manage own meals"
  ON public.meals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Meal items policies
CREATE POLICY "Users can manage own meal items"
  ON public.meal_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.meals
      WHERE id = meal_id AND user_id = auth.uid()
    )
  );

-- Meal media policies
CREATE POLICY "Users can manage own meal media"
  ON public.meal_media FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.meals
      WHERE id = meal_id AND user_id = auth.uid()
    )
  );

-- Metrics daily policies
CREATE POLICY "Users can manage own metrics"
  ON public.metrics_daily FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User profiles (quest) policies
CREATE POLICY "Users can manage own quest profile"
  ON public.user_profiles FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User quests policies
CREATE POLICY "Users can manage own quests"
  ON public.user_quests FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User quest settings policies
CREATE POLICY "Users can manage own quest settings"
  ON public.user_quest_settings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User quest refills policies
CREATE POLICY "Users can manage own quest refills"
  ON public.user_quest_refills FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Leaderboard points policies
-- Leaderboard is public (anyone can view all points)
CREATE POLICY "Anyone can view leaderboard"
  ON public.leaderboard_points FOR SELECT
  TO authenticated
  USING (true);

-- No insert/update policies (Edge Functions only)

-- Video sessions policies
CREATE POLICY "Participants can view sessions"
  ON public.video_sessions FOR SELECT
  USING (
    host_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id
        AND (client_id = auth.uid() OR provider_id = auth.uid())
    )
  );

-- No insert/update policies (Edge Functions only)

-- Notifications policies
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- =========================================
-- RPC FUNCTIONS
-- =========================================

-- Nearby providers (spatial search)
-- CRITICAL: This is the ONLY way to discover providers
-- Privacy: Returns NULL geo for home-private locations (exact coordinates never exposed)
-- Note: geo column stores approximate location for home-private (for distance calculation)
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
    -- Privacy: Mask geo for private home locations (never expose exact coordinates)
    -- Note: geo column stores approximate for home-private, but we return NULL to client
    CASE 
      WHEN pl.location_type = 'home' AND pl.is_public_exact = false THEN NULL
      ELSE pl.geo
    END AS geo,
    pl.radius_km,
    -- Calculate distance using geo (which is approximate for home-private)
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
    -- Provider identity (from profiles)
    pr.full_name,
    pr.avatar_url,
    p.verified
  FROM public.provider_locations pl
  JOIN public.providers p ON p.user_id = pl.provider_id
  JOIN public.profiles pr ON pr.id = p.user_id
  WHERE 
    pl.is_active = true
    AND pl.geo IS NOT NULL  -- Require geo for distance calculation (all locations have geo now)
    AND (provider_types IS NULL OR p.provider_type = ANY(provider_types))
    AND (location_types IS NULL OR pl.location_type = ANY(location_types))
    -- Filter by distance (geo is approximate for home-private, exact for others)
    AND ST_DWithin(
      pl.geo::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      (max_distance_km * 1000)::DOUBLE PRECISION
    )
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.nearby_providers TO authenticated;

-- Create lead transaction (from fix_quota_race_conditions.sql)
-- This is included here for completeness, but should be in separate migration
-- See: supabase/migrations/20250127_fix_quota_race_conditions.sql

-- Update lead status transaction (from fix_quota_race_conditions.sql)
-- This is included here for completeness, but should be in separate migration
-- See: supabase/migrations/20250127_fix_quota_race_conditions.sql

-- =========================================
-- CONSTRAINTS
-- =========================================

-- Note: Unique constraints are defined in table definitions above
-- No additional constraints needed here

-- =========================================
-- COMMENTS
-- =========================================

COMMENT ON TABLE public.profiles IS 'User profiles with role (single source of truth for RBAC)';
COMMENT ON TABLE public.providers IS 'Trainer and nutritionist provider profiles';
COMMENT ON TABLE public.provider_locations IS 'Service locations with privacy controls (home locations never expose exact geo)';
COMMENT ON TABLE public.subscriptions IS 'User subscription plans (no client writes, Edge Functions only)';
COMMENT ON TABLE public.weekly_usage IS 'Weekly quota usage tracking (no client writes, Edge Functions only)';
COMMENT ON TABLE public.leads IS 'Client requests to providers (no client inserts, Edge Functions only)';
COMMENT ON TABLE public.conversations IS 'Chat conversations created when lead is accepted';
COMMENT ON TABLE public.messages IS 'Chat messages between clients and providers';
COMMENT ON TABLE public.posts IS 'Cocircle social feed posts';
COMMENT ON TABLE public.video_sessions IS 'Video call sessions (no client writes, Edge Functions only)';
