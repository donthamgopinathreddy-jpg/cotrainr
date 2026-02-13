-- User streaks table: one row per user for login streak tracking
-- Fixes bug where new users saw previous user's streak (SharedPreferences was device-scoped)

CREATE TABLE IF NOT EXISTS public.user_streaks (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak INTEGER NOT NULL DEFAULT 0,
  last_login_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure set_updated_at exists (idempotent)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_user_streaks_updated_at
  BEFORE UPDATE ON public.user_streaks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS
ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

-- Users can only read/insert/update their own streak
DROP POLICY IF EXISTS "Users can manage own streak" ON public.user_streaks;
CREATE POLICY "Users can manage own streak" ON public.user_streaks
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for fast lookups (primary key already indexes user_id)
CREATE INDEX IF NOT EXISTS idx_user_streaks_last_login 
  ON public.user_streaks(last_login_date);
