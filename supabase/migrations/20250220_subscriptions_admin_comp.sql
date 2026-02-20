-- =========================================
-- SUBSCRIPTIONS: Admin comp access + billing fields
-- =========================================
-- Idempotent: create table if missing, add comp_until, provider, etc.
-- Admin can grant/revoke comp via Retool (service_role).
-- Authenticated users: SELECT own only, no UPDATE.
-- =========================================

-- Create minimal subscriptions table if not exists (for fresh installs)
CREATE TABLE IF NOT EXISTS public.subscriptions (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'basic', 'premium')),
  status TEXT NOT NULL DEFAULT 'inactive' CHECK (status IN ('inactive', 'active', 'canceled', 'trialing', 'past_due')),
  provider TEXT NOT NULL DEFAULT 'manual' CHECK (provider IN ('manual', 'stripe', 'razorpay')),
  current_period_end TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
  customer_id TEXT,
  subscription_id TEXT,
  comp_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add columns if table existed from earlier migrations (different schema)

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'comp_until') THEN
    ALTER TABLE public.subscriptions ADD COLUMN comp_until TIMESTAMPTZ;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'provider') THEN
    ALTER TABLE public.subscriptions ADD COLUMN provider TEXT NOT NULL DEFAULT 'manual' CHECK (provider IN ('manual', 'stripe', 'razorpay'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'current_period_end') THEN
    ALTER TABLE public.subscriptions ADD COLUMN current_period_end TIMESTAMPTZ;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'cancel_at_period_end') THEN
    ALTER TABLE public.subscriptions ADD COLUMN cancel_at_period_end BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'customer_id') THEN
    ALTER TABLE public.subscriptions ADD COLUMN customer_id TEXT;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'subscription_id') THEN
    ALTER TABLE public.subscriptions ADD COLUMN subscription_id TEXT;
  END IF;
END $$;

-- Note: subscription_status enum (active, cancelled, expired) from existing schema.
-- App Insights uses status IN ('active','trialing') - trialing/past_due count 0 if enum not extended.

-- RLS: ensure subscriptions has SELECT own, NO UPDATE for authenticated
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can select own subscription" ON public.subscriptions;
CREATE POLICY "Users can select own subscription"
  ON public.subscriptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- No UPDATE policy for authenticated: admin changes via service_role only
-- (Existing migrations may have created one; we explicitly ensure no UPDATE for authenticated)
DROP POLICY IF EXISTS "Authenticated can update subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can update own subscription" ON public.subscriptions;

COMMENT ON COLUMN public.subscriptions.comp_until IS 'Admin-granted comp access until this date. Overrides current_period_end for entitlement.';
