-- =========================================
-- COTRAINR COMPLETE SCHEMA MIGRATION (HARDENED + FIXED)
-- =========================================
-- Runs top-to-bottom in Supabase SQL editor.
-- Explicit drops only (does not drop extensions / PostGIS objects).
-- Idempotent via explicit DROP ... IF EXISTS then CREATE.
--
-- Username login security approach:
-- OPTION A (preferred) implemented:
--  - NO public/anon RPC for username -> email.
--  - Keep internal resolver RPC but:
--      * REVOKE ALL from PUBLIC
--      * Hard-guard: only service_role JWT may call it
--  - Add Edge Function design note for username/email login UX.
--
-- Critical requirements satisfied:
--  - pgcrypto + postgis extensions kept
--  - handle_new_user trigger:
--      * writes profiles.email from NEW.email
--      * requires NEW.raw_user_meta_data->>'username'
--      * enforces regex ^[A-Za-z0-9_]{3,20}$
--      * sets username_lower = lower(username)
--      * sets role = 'client' always (do not trust metadata)
--  - FK integrity:
--      * providers.user_id PK FK -> auth.users(id)
--      * provider_locations.provider_id FK -> providers(user_id)
--      * leads.provider_id FK -> providers(user_id)
--      * conversations.provider_id FK -> providers(user_id)
--  - SECURITY DEFINER functions set search_path = public, pg_catalog
--  - RLS enabled for all tables + policies exist (incl. user_quest_refills)
--
-- Notes / pragmatic warnings:
-- 1) This migration DROPS ALL your app tables => you will lose data.
-- 2) If you already have users in auth.users, they will NOT automatically get profiles
--    unless you backfill. This script only handles new signups.
-- 3) profiles.email is a copy of auth.users.email at signup; it may drift if email changes.
--    We DO NOT add UNIQUE(email) here because you cannot guarantee sync with auth.users
--    without an auth.users update trigger (not recommended).
-- =========================================

-- =========================================
-- SECTION 1: EXTENSIONS
-- =========================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =========================================
-- SECTION 2: DROPS (EXPLICIT ONLY)
-- =========================================

-- Drop auth trigger (if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop tables (reverse dependency order)
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.leaderboard_points CASCADE;
DROP TABLE IF EXISTS public.user_quest_refills CASCADE;
DROP TABLE IF EXISTS public.user_quest_settings CASCADE;
DROP TABLE IF EXISTS public.user_quests CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.metrics_daily CASCADE;
DROP TABLE IF EXISTS public.meal_media CASCADE;
DROP TABLE IF EXISTS public.meal_items CASCADE;
DROP TABLE IF EXISTS public.meals CASCADE;
DROP TABLE IF EXISTS public.post_reports CASCADE;
DROP TABLE IF EXISTS public.post_comments CASCADE;
DROP TABLE IF EXISTS public.post_likes CASCADE;
DROP TABLE IF EXISTS public.post_media CASCADE;
DROP TABLE IF EXISTS public.posts CASCADE;
DROP TABLE IF EXISTS public.video_sessions CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.leads CASCADE;
DROP TABLE IF EXISTS public.weekly_usage CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.provider_locations CASCADE;
DROP TABLE IF EXISTS public.providers CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop functions (only ours)
DROP FUNCTION IF EXISTS public.update_lead_status_tx(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_lead_tx(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, public.provider_type[], public.location_type[]) CASCADE;
DROP FUNCTION IF EXISTS public.rpc_resolve_login_identifier(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.enforce_provider_role() CASCADE;
DROP FUNCTION IF EXISTS public.handle_primary_location() CASCADE;
DROP FUNCTION IF EXISTS public.enforce_home_privacy() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.enforce_profiles_fields() CASCADE;

-- Drop enum types
DROP TYPE IF EXISTS public.video_session_status CASCADE;
DROP TYPE IF EXISTS public.report_reason CASCADE;
DROP TYPE IF EXISTS public.post_visibility CASCADE;
DROP TYPE IF EXISTS public.media_kind CASCADE;
DROP TYPE IF EXISTS public.subscription_status CASCADE;
DROP TYPE IF EXISTS public.subscription_plan CASCADE;
DROP TYPE IF EXISTS public.lead_status CASCADE;
DROP TYPE IF EXISTS public.location_type CASCADE;
DROP TYPE IF EXISTS public.provider_type CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;

-- =========================================
-- SECTION 3: ENUMS
-- =========================================
CREATE TYPE public.user_role AS ENUM ('client', 'trainer', 'nutritionist');
CREATE TYPE public.provider_type AS ENUM ('trainer', 'nutritionist');
CREATE TYPE public.location_type AS ENUM ('home', 'gym', 'studio', 'park', 'other');
CREATE TYPE public.lead_status AS ENUM ('requested', 'accepted', 'declined', 'cancelled');
CREATE TYPE public.subscription_plan AS ENUM ('free', 'basic', 'premium');
CREATE TYPE public.subscription_status AS ENUM ('active', 'cancelled', 'expired');
CREATE TYPE public.media_kind AS ENUM ('image', 'video');
CREATE TYPE public.post_visibility AS ENUM ('public', 'friends', 'private');
CREATE TYPE public.report_reason AS ENUM ('spam', 'inappropriate', 'harassment', 'fake', 'other');
CREATE TYPE public.video_session_status AS ENUM ('scheduled', 'active', 'ended', 'cancelled');

-- =========================================
-- SECTION 4: HELPER FUNCTIONS
-- =========================================

-- updated_at trigger helper
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- =========================================
-- SECTION 5: TABLES
-- =========================================

-- Profiles (identity & RBAC with username support)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.user_role NOT NULL DEFAULT 'client',
  email TEXT NOT NULL,                 -- copy from auth.users.email at signup
  username TEXT NOT NULL,              -- 3-20 chars, alphanumeric + underscore
  username_lower TEXT NOT NULL,        -- derived lower(username)
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  phone TEXT,
  date_of_birth DATE,
  gender TEXT,
  height_cm INTEGER,
  weight_kg NUMERIC(5, 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT profiles_username_format CHECK (username ~ '^[A-Za-z0-9_]{3,20}$'),
  CONSTRAINT profiles_username_lower_unique UNIQUE (username_lower)
);

-- Providers
CREATE TABLE public.providers (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_type public.provider_type NOT NULL,
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

-- Provider locations
CREATE TABLE public.provider_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.providers(user_id) ON DELETE CASCADE,
  location_type public.location_type NOT NULL,
  display_name TEXT NOT NULL,
  geo GEOGRAPHY(Point, 4326) NOT NULL,
  radius_km NUMERIC(5, 2) NOT NULL CHECK (radius_km > 0),
  is_public_exact BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Subscriptions
CREATE TABLE public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  plan public.subscription_plan NOT NULL DEFAULT 'free',
  status public.subscription_status NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Weekly usage
CREATE TABLE public.weekly_usage (
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

-- Leads
CREATE TABLE public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES public.providers(user_id) ON DELETE CASCADE,
  provider_type public.provider_type NOT NULL,
  status public.lead_status NOT NULL DEFAULT 'requested',
  message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Conversations
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL UNIQUE REFERENCES public.leads(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES public.providers(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Messages
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  media_url TEXT,
  media_kind public.media_kind,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Video sessions
CREATE TABLE public.video_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status public.video_session_status NOT NULL DEFAULT 'scheduled',
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  room_id TEXT UNIQUE,
  token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Posts
CREATE TABLE public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  visibility public.post_visibility NOT NULL DEFAULT 'public',
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post media
CREATE TABLE public.post_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL,
  media_kind public.media_kind NOT NULL,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post likes
CREATE TABLE public.post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Post comments
CREATE TABLE public.post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post reports
CREATE TABLE public.post_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason public.report_reason NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, reporter_id)
);

-- Meals
CREATE TABLE public.meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  meal_type TEXT NOT NULL,
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
CREATE TABLE public.meal_items (
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
CREATE TABLE public.meal_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id UUID NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL,
  media_kind public.media_kind NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Metrics daily
CREATE TABLE public.metrics_daily (
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

-- Quest profile
CREATE TABLE public.user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  level INTEGER NOT NULL DEFAULT 1,
  xp INTEGER NOT NULL DEFAULT 0,
  coins INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Quests
CREATE TABLE public.user_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quest_definition_id TEXT NOT NULL,
  category TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  progress_current NUMERIC(10, 2) DEFAULT 0,
  progress_target NUMERIC(10, 2) NOT NULL,
  reward_xp INTEGER NOT NULL DEFAULT 0,
  reward_coins INTEGER DEFAULT 0,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ
);

-- Quest settings
CREATE TABLE public.user_quest_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_quest_slots INTEGER NOT NULL DEFAULT 3,
  weekly_quest_slots INTEGER NOT NULL DEFAULT 2,
  refills_used_today INTEGER NOT NULL DEFAULT 0,
  last_refill_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Quest refills
CREATE TABLE public.user_quest_refills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  refill_date DATE NOT NULL,
  refills_used INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, refill_date)
);

-- Leaderboard points
CREATE TABLE public.leaderboard_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points INTEGER NOT NULL DEFAULT 0,
  period_type TEXT NOT NULL,
  period_start DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, period_type, period_start)
);

-- Notifications
CREATE TABLE public.notifications (
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
-- SECTION 6: INDEXES
-- =========================================

-- Profiles
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(email);
-- username_lower has UNIQUE constraint => unique index already exists

-- Providers
CREATE INDEX idx_providers_type ON public.providers(provider_type);
CREATE INDEX idx_providers_verified ON public.providers(verified) WHERE verified = true;

-- Provider locations
CREATE INDEX idx_provider_locations_provider_id ON public.provider_locations(provider_id);
CREATE INDEX idx_provider_locations_geo ON public.provider_locations USING GIST(geo);
CREATE INDEX idx_provider_locations_active ON public.provider_locations(is_active) WHERE is_active = true;
CREATE UNIQUE INDEX idx_provider_locations_primary ON public.provider_locations(provider_id) WHERE is_primary = true;

-- Subscriptions
CREATE INDEX idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX idx_subscriptions_plan ON public.subscriptions(plan);

-- Weekly usage
CREATE INDEX idx_weekly_usage_user_week ON public.weekly_usage(user_id, week_start);

-- Leads
CREATE INDEX idx_leads_client_id ON public.leads(client_id);
CREATE INDEX idx_leads_provider_id ON public.leads(provider_id);
CREATE INDEX idx_leads_status ON public.leads(status);
CREATE UNIQUE INDEX idx_leads_unique_active ON public.leads(client_id, provider_id) WHERE status IN ('requested', 'accepted');

-- Conversations
CREATE INDEX idx_conversations_client_id ON public.conversations(client_id);
CREATE INDEX idx_conversations_provider_id ON public.conversations(provider_id);
CREATE INDEX idx_conversations_lead_id ON public.conversations(lead_id);

-- Messages
CREATE INDEX idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX idx_messages_created_at ON public.messages(created_at DESC);

-- Video sessions
CREATE INDEX idx_video_sessions_host_id ON public.video_sessions(host_id);
CREATE INDEX idx_video_sessions_conversation_id ON public.video_sessions(conversation_id);
CREATE INDEX idx_video_sessions_status ON public.video_sessions(status);

-- Posts
CREATE INDEX idx_posts_author_id ON public.posts(author_id);
CREATE INDEX idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX idx_posts_visibility ON public.posts(visibility);

-- Post media
CREATE INDEX idx_post_media_post_id ON public.post_media(post_id);

-- Post likes
CREATE INDEX idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX idx_post_likes_user_id ON public.post_likes(user_id);

-- Post comments
CREATE INDEX idx_post_comments_post_id ON public.post_comments(post_id);
CREATE INDEX idx_post_comments_author_id ON public.post_comments(author_id);

-- Meals
CREATE INDEX idx_meals_user_id ON public.meals(user_id);
CREATE INDEX idx_meals_consumed_at ON public.meals(consumed_at DESC);

-- Meal items
CREATE INDEX idx_meal_items_meal_id ON public.meal_items(meal_id);

-- Metrics daily
CREATE INDEX idx_metrics_daily_user_date ON public.metrics_daily(user_id, date DESC);

-- User quests
CREATE INDEX idx_user_quests_user_id ON public.user_quests(user_id);
CREATE INDEX idx_user_quests_status ON public.user_quests(status);

-- Leaderboard points
CREATE INDEX idx_leaderboard_points_user_period ON public.leaderboard_points(user_id, period_type, period_start);
CREATE INDEX idx_leaderboard_points_period_points ON public.leaderboard_points(period_type, period_start, points DESC);

-- Notifications
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_read ON public.notifications(user_id, read);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at DESC);

-- =========================================
-- SECTION 7: TRIGGERS + SECURITY ENFORCEMENT
-- =========================================

-- NOTE: We don't drop triggers here because DROP TABLE CASCADE already did that.
-- These CREATE statements are idempotent only if tables exist (which they do at this point).

-- updated_at triggers
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_providers_updated_at BEFORE UPDATE ON public.providers
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_provider_locations_updated_at BEFORE UPDATE ON public.provider_locations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_weekly_usage_updated_at BEFORE UPDATE ON public.weekly_usage
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_leads_updated_at BEFORE UPDATE ON public.leads
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_conversations_updated_at BEFORE UPDATE ON public.conversations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_video_sessions_updated_at BEFORE UPDATE ON public.video_sessions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_posts_updated_at BEFORE UPDATE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_post_comments_updated_at BEFORE UPDATE ON public.post_comments
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_meals_updated_at BEFORE UPDATE ON public.meals
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_metrics_daily_updated_at BEFORE UPDATE ON public.metrics_daily
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_user_quest_settings_updated_at BEFORE UPDATE ON public.user_quest_settings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_leaderboard_points_updated_at BEFORE UPDATE ON public.leaderboard_points
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Enforce safe/consistent profile fields on UPDATE (blocks role/email tampering)
CREATE OR REPLACE FUNCTION public.enforce_profiles_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_jwt_role TEXT;
BEGIN
  -- service_role guard (if present)
  BEGIN
    v_jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN
    v_jwt_role := NULL;
  END;

  IF v_jwt_role = 'service_role' THEN
    -- allow admin/service modifications but keep username_lower derived
    IF NEW.username IS DISTINCT FROM OLD.username THEN
      IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
      END IF;
      NEW.username_lower := lower(NEW.username);
    ELSE
      NEW.username_lower := OLD.username_lower;
    END IF;
    RETURN NEW;
  END IF;

  -- require auth for non-service updates
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated updates not allowed';
  END IF;

  -- block role changes and email changes for normal users
  NEW.role := OLD.role;
  NEW.email := OLD.email;

  -- username_lower is always derived
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
      RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
    END IF;
    NEW.username_lower := lower(NEW.username);
  ELSE
    NEW.username_lower := OLD.username_lower;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_enforce_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_profiles_fields();

-- Signup trigger: create profile (username required) and force role='client'
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_username TEXT;
  v_username_lower TEXT;
BEGIN
  v_username := NEW.raw_user_meta_data->>'username';

  IF v_username IS NULL OR v_username = '' THEN
    RAISE EXCEPTION 'Username is required in user metadata';
  END IF;

  IF v_username !~ '^[A-Za-z0-9_]{3,20}$' THEN
    RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
  END IF;

  v_username_lower := lower(v_username);

  -- fail early for clear error
  IF EXISTS (SELECT 1 FROM public.profiles WHERE username_lower = v_username_lower) THEN
    RAISE EXCEPTION 'Username already exists';
  END IF;

  INSERT INTO public.profiles (id, role, email, username, username_lower, full_name)
  VALUES (
    NEW.id,
    'client'::public.user_role,
    NEW.email,
    v_username,
    v_username_lower,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

-- auth trigger rerunnable (drop right before create for idempotency)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Home location privacy enforcement
CREATE OR REPLACE FUNCTION public.enforce_home_privacy()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.location_type = 'home' AND NEW.is_public_exact = true THEN
    NEW.is_public_exact := false;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_home_privacy
BEFORE INSERT OR UPDATE ON public.provider_locations
FOR EACH ROW
EXECUTE FUNCTION public.enforce_home_privacy();

-- Ensure only one primary location per provider
CREATE OR REPLACE FUNCTION public.handle_primary_location()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.is_primary = true THEN
    UPDATE public.provider_locations
    SET is_primary = false
    WHERE provider_id = NEW.provider_id
      AND id <> NEW.id
      AND is_primary = true;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_handle_primary_location
BEFORE INSERT OR UPDATE ON public.provider_locations
FOR EACH ROW
WHEN (NEW.is_primary = true)
EXECUTE FUNCTION public.handle_primary_location();

-- Enforce provider_type matches profiles.role
CREATE OR REPLACE FUNCTION public.enforce_provider_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_role public.user_role;
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

  IF NEW.provider_type = 'trainer' AND v_role <> 'trainer' THEN
    RAISE EXCEPTION 'provider_type trainer requires profiles.role=trainer';
  END IF;

  IF NEW.provider_type = 'nutritionist' AND v_role <> 'nutritionist' THEN
    RAISE EXCEPTION 'provider_type nutritionist requires profiles.role=nutritionist';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_provider_role
BEFORE INSERT OR UPDATE ON public.providers
FOR EACH ROW
EXECUTE FUNCTION public.enforce_provider_role();

-- =========================================
-- SECTION 8: RLS ENABLE
-- =========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;
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
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- =========================================
-- SECTION 9: POLICIES (DROP + CREATE)
-- =========================================

-- Drop policies (rerunnable)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

DROP POLICY IF EXISTS "Anyone can view providers" ON public.providers;
DROP POLICY IF EXISTS "Providers can update own provider" ON public.providers;
DROP POLICY IF EXISTS "Providers can insert own provider" ON public.providers;

DROP POLICY IF EXISTS "Providers can manage own locations" ON public.provider_locations;

DROP POLICY IF EXISTS "Users can view own subscription" ON public.subscriptions;

DROP POLICY IF EXISTS "Users can view own usage" ON public.weekly_usage;

DROP POLICY IF EXISTS "Participants can view leads" ON public.leads;
DROP POLICY IF EXISTS "Providers can update lead status" ON public.leads;

DROP POLICY IF EXISTS "Participants can view conversations" ON public.conversations;

DROP POLICY IF EXISTS "Participants can view messages" ON public.messages;
DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;

DROP POLICY IF EXISTS "Participants can view sessions" ON public.video_sessions;

DROP POLICY IF EXISTS "Anyone can view public posts" ON public.posts;
DROP POLICY IF EXISTS "Users can create own posts" ON public.posts;
DROP POLICY IF EXISTS "Users can update own posts" ON public.posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON public.posts;

DROP POLICY IF EXISTS "Anyone can view post media" ON public.post_media;
DROP POLICY IF EXISTS "Users can manage own post media" ON public.post_media;

DROP POLICY IF EXISTS "Anyone can view likes" ON public.post_likes;
DROP POLICY IF EXISTS "Users can like posts" ON public.post_likes;
DROP POLICY IF EXISTS "Users can unlike own likes" ON public.post_likes;

DROP POLICY IF EXISTS "Anyone can view comments" ON public.post_comments;
DROP POLICY IF EXISTS "Users can create comments" ON public.post_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON public.post_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.post_comments;

DROP POLICY IF EXISTS "Users can report posts" ON public.post_reports;

DROP POLICY IF EXISTS "Users can manage own meals" ON public.meals;
DROP POLICY IF EXISTS "Users can manage own meal items" ON public.meal_items;
DROP POLICY IF EXISTS "Users can manage own meal media" ON public.meal_media;

DROP POLICY IF EXISTS "Users can manage own metrics" ON public.metrics_daily;

DROP POLICY IF EXISTS "Users can manage own quest profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can manage own quests" ON public.user_quests;
DROP POLICY IF EXISTS "Users can manage own quest settings" ON public.user_quest_settings;
DROP POLICY IF EXISTS "Users can manage own quest refills" ON public.user_quest_refills;

DROP POLICY IF EXISTS "Anyone can view leaderboard" ON public.leaderboard_points;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;

-- Profiles (self-only)
CREATE POLICY "Users can view own profile" ON public.profiles
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
FOR INSERT WITH CHECK (auth.uid() = id);

-- Providers (authenticated can read list; no profile/email exposure here)
CREATE POLICY "Anyone can view providers" ON public.providers
FOR SELECT TO authenticated USING (true);

CREATE POLICY "Providers can update own provider" ON public.providers
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Providers can insert own provider" ON public.providers
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Provider locations: provider self-manage only (no public SELECT)
CREATE POLICY "Providers can manage own locations" ON public.provider_locations
FOR ALL TO authenticated
USING (auth.uid() = provider_id)
WITH CHECK (auth.uid() = provider_id);

-- Subscriptions: self read only
CREATE POLICY "Users can view own subscription" ON public.subscriptions
FOR SELECT USING (auth.uid() = user_id);

-- Weekly usage: self read only
CREATE POLICY "Users can view own usage" ON public.weekly_usage
FOR SELECT USING (auth.uid() = user_id);

-- Leads: participants read; provider can update
CREATE POLICY "Participants can view leads" ON public.leads
FOR SELECT USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Providers can update lead status" ON public.leads
FOR UPDATE USING (auth.uid() = provider_id);

-- Conversations: participants read
CREATE POLICY "Participants can view conversations" ON public.conversations
FOR SELECT USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- Messages: participants read + send
CREATE POLICY "Participants can view messages" ON public.messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = conversation_id
      AND (c.client_id = auth.uid() OR c.provider_id = auth.uid())
  )
);

CREATE POLICY "Participants can send messages" ON public.messages
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = conversation_id
      AND (c.client_id = auth.uid() OR c.provider_id = auth.uid())
  )
  AND sender_id = auth.uid()
);

-- Video sessions: host or conversation participants
CREATE POLICY "Participants can view sessions" ON public.video_sessions
FOR SELECT USING (
  host_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = conversation_id
      AND (c.client_id = auth.uid() OR c.provider_id = auth.uid())
  )
);

-- Posts: authenticated can read public/friends; author reads own
CREATE POLICY "Anyone can view public posts" ON public.posts
FOR SELECT TO authenticated
USING (visibility IN ('public', 'friends') OR author_id = auth.uid());

CREATE POLICY "Users can create own posts" ON public.posts
FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can update own posts" ON public.posts
FOR UPDATE USING (author_id = auth.uid());

CREATE POLICY "Users can delete own posts" ON public.posts
FOR DELETE USING (author_id = auth.uid());

-- Post media: readable if post visible; manageable by author
CREATE POLICY "Anyone can view post media" ON public.post_media
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.posts p
    WHERE p.id = post_id
      AND (p.visibility IN ('public', 'friends') OR p.author_id = auth.uid())
  )
);

CREATE POLICY "Users can manage own post media" ON public.post_media
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.author_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.author_id = auth.uid())
);

-- Likes
CREATE POLICY "Anyone can view likes" ON public.post_likes
FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can like posts" ON public.post_likes
FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can unlike own likes" ON public.post_likes
FOR DELETE USING (user_id = auth.uid());

-- Comments
CREATE POLICY "Anyone can view comments" ON public.post_comments
FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create comments" ON public.post_comments
FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can update own comments" ON public.post_comments
FOR UPDATE USING (author_id = auth.uid());

CREATE POLICY "Users can delete own comments" ON public.post_comments
FOR DELETE USING (author_id = auth.uid());

-- Reports
CREATE POLICY "Users can report posts" ON public.post_reports
FOR INSERT WITH CHECK (reporter_id = auth.uid());

-- Meals
CREATE POLICY "Users can manage own meals" ON public.meals
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Meal items
CREATE POLICY "Users can manage own meal items" ON public.meal_items
FOR ALL USING (
  EXISTS (SELECT 1 FROM public.meals m WHERE m.id = meal_id AND m.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.meals m WHERE m.id = meal_id AND m.user_id = auth.uid())
);

-- Meal media
CREATE POLICY "Users can manage own meal media" ON public.meal_media
FOR ALL USING (
  EXISTS (SELECT 1 FROM public.meals m WHERE m.id = meal_id AND m.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.meals m WHERE m.id = meal_id AND m.user_id = auth.uid())
);

-- Metrics
CREATE POLICY "Users can manage own metrics" ON public.metrics_daily
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Quest profile
CREATE POLICY "Users can manage own quest profile" ON public.user_profiles
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Quests
CREATE POLICY "Users can manage own quests" ON public.user_quests
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Quest settings
CREATE POLICY "Users can manage own quest settings" ON public.user_quest_settings
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Quest refills (explicit requirement)
CREATE POLICY "Users can manage own quest refills" ON public.user_quest_refills
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Leaderboard (authenticated read)
CREATE POLICY "Anyone can view leaderboard" ON public.leaderboard_points
FOR SELECT TO authenticated USING (true);

-- Notifications
CREATE POLICY "Users can view own notifications" ON public.notifications
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON public.notifications
FOR UPDATE USING (auth.uid() = user_id);

-- =========================================
-- SECTION 10: USERNAME LOGIN UX (EDGE FUNCTION - OPTION A)
-- =========================================
-- DO NOT expose username->email resolution to anon users.
-- Use Edge Function with service-role client:
--  - If identifier has '@': signInWithPassword(email)
--  - Else: service-role query profiles by username_lower and sign in using email
--  - Always return generic "Invalid credentials" on failure

-- =========================================
-- SECTION 11: RPCs
-- =========================================

-- Internal-only resolver (service_role only). Not granted to anon/authenticated.
CREATE OR REPLACE FUNCTION public.rpc_resolve_login_identifier(identifier TEXT)
RETURNS TABLE(email TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_jwt_role TEXT;
BEGIN
  -- hard guard: only service_role
  BEGIN
    v_jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN
    v_jwt_role := NULL;
  END;

  IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'This function can only be called by service_role';
  END IF;

  IF identifier LIKE '%@%' THEN
    RETURN QUERY SELECT identifier::TEXT;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.email
  FROM public.profiles p
  WHERE p.username_lower = lower(identifier)
  LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_resolve_login_identifier(TEXT) FROM PUBLIC;

-- Nearby providers (spatial search with home privacy masking)
CREATE OR REPLACE FUNCTION public.nearby_providers(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance_km DOUBLE PRECISION DEFAULT 50.0,
  provider_types public.provider_type[] DEFAULT NULL,
  location_types public.location_type[] DEFAULT NULL
)
RETURNS TABLE (
  provider_id UUID,
  location_id UUID,
  location_type public.location_type,
  display_name TEXT,
  geo GEOGRAPHY,
  radius_km NUMERIC,
  distance_km DOUBLE PRECISION,
  is_primary BOOLEAN,
  provider_type public.provider_type,
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
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pl.provider_id,
    pl.id AS location_id,
    pl.location_type,
    pl.display_name,
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
      (max_distance_km * 1000)::DOUBLE PRECISION
    )
  ORDER BY distance_km ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, public.provider_type[], public.location_type[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, public.provider_type[], public.location_type[]) TO authenticated;

-- Create lead transaction (quota enforcement)
CREATE OR REPLACE FUNCTION public.create_lead_tx(
  p_provider_id UUID,
  p_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_client_id UUID;
  v_client_role public.user_role;
  v_provider_type public.provider_type;
  v_week_start DATE;
  v_plan public.subscription_plan;
  v_requests_used INTEGER;
  v_nutritionist_requests_used INTEGER;
  v_requests_limit INTEGER;
  v_nutritionist_limit INTEGER;
  v_lead_id UUID;
BEGIN
  v_client_id := auth.uid();

  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated');
  END IF;

  SELECT role INTO v_client_role
  FROM public.profiles
  WHERE id = v_client_id;

  IF v_client_role IS NULL OR v_client_role <> 'client' THEN
    RETURN jsonb_build_object('error', 'Only clients can create leads');
  END IF;

  SELECT provider_type INTO v_provider_type
  FROM public.providers
  WHERE user_id = p_provider_id;

  IF v_provider_type IS NULL THEN
    RETURN jsonb_build_object('error', 'Provider not found');
  END IF;

  v_week_start := (current_date - ((extract(dow from current_date)::int + 6) % 7));

  SELECT COALESCE((SELECT plan FROM public.subscriptions WHERE user_id = v_client_id), 'free'::public.subscription_plan)
  INTO v_plan;

  INSERT INTO public.weekly_usage(user_id, week_start, requests_used, nutritionist_requests_used, video_sessions_used)
  VALUES (v_client_id, v_week_start, 0, 0, 0)
  ON CONFLICT (user_id, week_start) DO NOTHING;

  SELECT requests_used, nutritionist_requests_used
  INTO v_requests_used, v_nutritionist_requests_used
  FROM public.weekly_usage
  WHERE user_id = v_client_id AND week_start = v_week_start
  FOR UPDATE;

  IF v_plan = 'free' THEN
    v_requests_limit := 3;
    v_nutritionist_limit := 0;
  ELSIF v_plan = 'basic' THEN
    v_requests_limit := 15;
    v_nutritionist_limit := 3;
  ELSE
    v_requests_limit := 30;
    v_nutritionist_limit := 30;
  END IF;

  IF v_provider_type = 'nutritionist' THEN
    IF v_nutritionist_limit = 0 THEN
      RETURN jsonb_build_object('error', 'Nutritionist requests not allowed on free plan');
    END IF;
    IF v_nutritionist_requests_used >= v_nutritionist_limit THEN
      RETURN jsonb_build_object('error', 'Nutritionist request limit reached');
    END IF;
  END IF;

  IF v_requests_used >= v_requests_limit THEN
    RETURN jsonb_build_object('error', 'Request limit reached');
  END IF;

  BEGIN
    INSERT INTO public.leads(client_id, provider_id, provider_type, status, message)
    VALUES (v_client_id, p_provider_id, v_provider_type, 'requested', p_message)
    RETURNING id INTO v_lead_id;

    UPDATE public.weekly_usage
    SET
      requests_used = requests_used + 1,
      nutritionist_requests_used = CASE WHEN v_provider_type = 'nutritionist'
        THEN nutritionist_requests_used + 1 ELSE nutritionist_requests_used END
    WHERE user_id = v_client_id AND week_start = v_week_start;

    RETURN jsonb_build_object(
      'success', true,
      'lead_id', v_lead_id,
      'remaining_requests', v_requests_limit - v_requests_used - 1,
      'remaining_nutritionist_requests', CASE WHEN v_provider_type = 'nutritionist'
        THEN v_nutritionist_limit - v_nutritionist_requests_used - 1 ELSE NULL END
    );
  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object('error', 'Active lead already exists with this provider');
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.create_lead_tx(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_lead_tx(UUID, TEXT) TO authenticated;

-- Update lead status transaction
CREATE OR REPLACE FUNCTION public.update_lead_status_tx(
  p_lead_id UUID,
  p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_actor_id UUID;
  v_lead_record RECORD;
  v_conversation_id UUID;
BEGIN
  v_actor_id := auth.uid();

  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated');
  END IF;

  IF p_status NOT IN ('accepted', 'declined', 'cancelled') THEN
    RETURN jsonb_build_object('error', 'Invalid status');
  END IF;

  SELECT * INTO v_lead_record
  FROM public.leads
  WHERE id = p_lead_id;

  IF v_lead_record IS NULL THEN
    RETURN jsonb_build_object('error', 'Lead not found');
  END IF;

  IF v_lead_record.status <> 'requested' THEN
    RETURN jsonb_build_object('error', 'Lead status cannot be changed');
  END IF;

  IF p_status = 'cancelled' THEN
    IF v_actor_id <> v_lead_record.client_id THEN
      RETURN jsonb_build_object('error', 'Only client can cancel');
    END IF;
  ELSE
    IF v_actor_id <> v_lead_record.provider_id THEN
      RETURN jsonb_build_object('error', 'Only provider can accept/decline');
    END IF;
  END IF;

  UPDATE public.leads
  SET status = p_status::public.lead_status, updated_at = NOW()
  WHERE id = p_lead_id;

  IF p_status = 'accepted' THEN
    INSERT INTO public.conversations(lead_id, client_id, provider_id)
    VALUES (p_lead_id, v_lead_record.client_id, v_lead_record.provider_id)
    ON CONFLICT (lead_id) DO NOTHING
    RETURNING id INTO v_conversation_id;

    IF v_conversation_id IS NULL THEN
      SELECT id INTO v_conversation_id
      FROM public.conversations
      WHERE lead_id = p_lead_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'conversation_id', v_conversation_id);
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.update_lead_status_tx(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_lead_status_tx(UUID, TEXT) TO authenticated;
