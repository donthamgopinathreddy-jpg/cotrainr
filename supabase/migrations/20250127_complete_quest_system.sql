-- =========================================
-- COMPLETE QUEST SYSTEM MIGRATION
-- =========================================
-- This migration creates a full quest/challenge/achievement/leaderboard system
-- Idempotent: Can be run multiple times safely
-- =========================================

-- =========================================
-- STEP 1: FIX EXISTING TABLES
-- =========================================

-- Fix user_profiles: Add total_xp column (service expects total_xp, not xp)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'user_profiles' 
    AND column_name = 'total_xp'
  ) THEN
    ALTER TABLE public.user_profiles ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0;
    -- Migrate existing xp to total_xp
    UPDATE public.user_profiles SET total_xp = xp WHERE total_xp = 0;
  END IF;
END $$;

-- Fix user_quests: Add missing columns
DO $$ 
BEGIN
  -- Ensure table exists first (create if it doesn't)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'user_quests'
  ) THEN
    CREATE TABLE public.user_quests (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      quest_definition_id TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'steps',
      difficulty TEXT NOT NULL DEFAULT 'easy',
      status TEXT NOT NULL DEFAULT 'available',
      progress_current NUMERIC(10, 2) DEFAULT 0,
      progress_target NUMERIC(10, 2) NOT NULL,
      reward_xp INTEGER NOT NULL DEFAULT 0,
      reward_coins INTEGER DEFAULT 0,
      started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      completed_at TIMESTAMPTZ,
      claimed_at TIMESTAMPTZ,
      type TEXT NOT NULL DEFAULT 'daily',
      assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ
    );
  ELSE
    -- Table exists, add missing columns
    -- Add type column (daily, weekly, challenge)
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_quests' 
      AND column_name = 'type'
    ) THEN
      ALTER TABLE public.user_quests ADD COLUMN type TEXT NOT NULL DEFAULT 'daily';
    END IF;

    -- Add assigned_at column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_quests' 
      AND column_name = 'assigned_at'
    ) THEN
      ALTER TABLE public.user_quests ADD COLUMN assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    END IF;

    -- Add expires_at column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_quests' 
      AND column_name = 'expires_at'
    ) THEN
      ALTER TABLE public.user_quests ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;

    -- Add category column if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_quests' 
      AND column_name = 'category'
    ) THEN
      ALTER TABLE public.user_quests ADD COLUMN category TEXT NOT NULL DEFAULT 'steps';
    ELSE
      -- Ensure category is NOT NULL if it exists but is nullable
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_quests' 
        AND column_name = 'category'
        AND is_nullable = 'YES'
      ) THEN
        UPDATE public.user_quests SET category = 'steps' WHERE category IS NULL;
        ALTER TABLE public.user_quests ALTER COLUMN category SET NOT NULL;
        ALTER TABLE public.user_quests ALTER COLUMN category SET DEFAULT 'steps';
      END IF;
    END IF;

    -- Add difficulty column if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_quests' 
      AND column_name = 'difficulty'
    ) THEN
      ALTER TABLE public.user_quests ADD COLUMN difficulty TEXT NOT NULL DEFAULT 'easy';
    ELSE
      -- Ensure difficulty is NOT NULL if it exists but is nullable
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_quests' 
        AND column_name = 'difficulty'
        AND is_nullable = 'YES'
      ) THEN
        UPDATE public.user_quests SET difficulty = 'easy' WHERE difficulty IS NULL;
        ALTER TABLE public.user_quests ALTER COLUMN difficulty SET NOT NULL;
        ALTER TABLE public.user_quests ALTER COLUMN difficulty SET DEFAULT 'easy';
      END IF;
    END IF;

    -- Fix status: Change 'active' to 'available' or 'in_progress'
    -- Update existing 'active' to 'in_progress'
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_quests' 
      AND column_name = 'status'
    ) THEN
      UPDATE public.user_quests SET status = 'in_progress' WHERE status = 'active';
    END IF;
  END IF;
END $$;

-- Fix user_quest_settings: Add refresh tracking columns
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'user_quest_settings' 
    AND column_name = 'last_daily_refresh'
  ) THEN
    ALTER TABLE public.user_quest_settings ADD COLUMN last_daily_refresh TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'user_quest_settings' 
    AND column_name = 'last_weekly_refresh'
  ) THEN
    ALTER TABLE public.user_quest_settings ADD COLUMN last_weekly_refresh TIMESTAMPTZ;
  END IF;
END $$;

-- Fix user_quest_refills: Add refilled_at column (service expects refilled_at, not refill_date)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'user_quest_refills' 
    AND column_name = 'refilled_at'
  ) THEN
    ALTER TABLE public.user_quest_refills ADD COLUMN refilled_at TIMESTAMPTZ;
    -- Migrate refill_date to refilled_at
    UPDATE public.user_quest_refills 
    SET refilled_at = refill_date::TIMESTAMPTZ 
    WHERE refilled_at IS NULL AND refill_date IS NOT NULL;
  END IF;
END $$;

-- =========================================
-- STEP 2: CREATE NEW TABLES
-- =========================================

-- Quest definitions (server-driven quest templates)
-- Use existing 'quests' table if it exists, otherwise create it
DO $$ 
BEGIN
  -- Check if 'quests' table exists (the actual table name in your DB)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'quests'
  ) THEN
    -- Create quests table if it doesn't exist
    CREATE TABLE public.quests (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'steps', -- steps, workout, nutrition, hydration, consistency, social, recovery
      difficulty TEXT NOT NULL DEFAULT 'easy', -- easy, medium, hard
      time_window TEXT NOT NULL DEFAULT 'anytime', -- anytime, morning, evening
      reward_xp INTEGER NOT NULL DEFAULT 0,
      reward_points INTEGER NOT NULL DEFAULT 0, -- Leaderboard points
      requirements JSONB NOT NULL DEFAULT '{}'::jsonb, -- e.g., {"steps": 8000, "before": "08:00"}
      cooldown_days INTEGER NOT NULL DEFAULT 2,
      icon_name TEXT, -- Icon identifier for Flutter
      icon_color TEXT, -- Hex color
      roles TEXT[], -- null = all, or ["client", "trainer", "nutritionist"]
      quest_type TEXT NOT NULL DEFAULT 'daily', -- daily, weekly, challenge
      is_active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  ELSE
    -- Table exists, ensure it has ALL required columns
    -- Category
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'category'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN category TEXT NOT NULL DEFAULT 'steps';
    END IF;
    
    -- Difficulty
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'difficulty'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN difficulty TEXT NOT NULL DEFAULT 'easy';
    END IF;
    
    -- Time window
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'time_window'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN time_window TEXT NOT NULL DEFAULT 'anytime';
    END IF;
    
    -- Quest type
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'quest_type'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN quest_type TEXT NOT NULL DEFAULT 'daily';
    END IF;
    
    -- Reward XP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'reward_xp'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN reward_xp INTEGER NOT NULL DEFAULT 0;
    END IF;
    
    -- Reward points
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'reward_points'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN reward_points INTEGER NOT NULL DEFAULT 0;
    END IF;
    
    -- Requirements
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'requirements'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN requirements JSONB NOT NULL DEFAULT '{}'::jsonb;
    END IF;
    
    -- Cooldown days
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'cooldown_days'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN cooldown_days INTEGER NOT NULL DEFAULT 2;
    END IF;
    
    -- Icon name
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'icon_name'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN icon_name TEXT;
    END IF;
    
    -- Icon color
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'icon_color'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN icon_color TEXT;
    END IF;
    
    -- Is active
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'quests' 
      AND column_name = 'is_active'
    ) THEN
      ALTER TABLE public.quests ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
    END IF;
  END IF;
END $$;

-- Create indexes on quests table
CREATE INDEX IF NOT EXISTS idx_quests_type ON public.quests(quest_type);
CREATE INDEX IF NOT EXISTS idx_quests_active ON public.quests(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_quests_category ON public.quests(category);

-- Achievements (milestone definitions)
CREATE TABLE IF NOT EXISTS public.achievements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'streaks', -- streaks, steps, nutrition, hydration, challenges, social, consistency
  tier INTEGER NOT NULL DEFAULT 1, -- 1, 2, 3, etc.
  target_progress NUMERIC(10, 2) NOT NULL,
  reward_xp INTEGER NOT NULL DEFAULT 0,
  badge_frame TEXT, -- Cosmetic frame name
  title_reward TEXT, -- e.g., "Rookie Runner"
  icon_name TEXT,
  icon_color TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure achievements has category column (if table existed without it)
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'achievements'
  ) THEN
    -- Add category column if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'achievements' 
      AND column_name = 'category'
    ) THEN
      ALTER TABLE public.achievements ADD COLUMN category TEXT NOT NULL DEFAULT 'streaks';
    ELSE
      -- Ensure category is NOT NULL if it exists but is nullable
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'achievements' 
        AND column_name = 'category'
        AND is_nullable = 'YES'
      ) THEN
        UPDATE public.achievements SET category = 'streaks' WHERE category IS NULL;
        ALTER TABLE public.achievements ALTER COLUMN category SET NOT NULL;
        ALTER TABLE public.achievements ALTER COLUMN category SET DEFAULT 'streaks';
      END IF;
    END IF;
  END IF;
END $$;

-- Create category index after ensuring column exists
CREATE INDEX IF NOT EXISTS idx_achievements_category ON public.achievements(category);

-- User achievements (progress tracking)
CREATE TABLE IF NOT EXISTS public.user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  current_progress NUMERIC(10, 2) NOT NULL DEFAULT 0,
  is_unlocked BOOLEAN NOT NULL DEFAULT false,
  unlocked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- Ensure user_achievements has is_unlocked column (if table existed without it)
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'user_achievements'
  ) THEN
    -- Add is_unlocked column if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_achievements' 
      AND column_name = 'is_unlocked'
    ) THEN
      ALTER TABLE public.user_achievements ADD COLUMN is_unlocked BOOLEAN NOT NULL DEFAULT false;
    ELSE
      -- Ensure is_unlocked is NOT NULL if it exists but is nullable
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_achievements' 
        AND column_name = 'is_unlocked'
        AND is_nullable = 'YES'
      ) THEN
        UPDATE public.user_achievements SET is_unlocked = false WHERE is_unlocked IS NULL;
        ALTER TABLE public.user_achievements ALTER COLUMN is_unlocked SET NOT NULL;
        ALTER TABLE public.user_achievements ALTER COLUMN is_unlocked SET DEFAULT false;
      END IF;
    END IF;
    
    -- Add unlocked_at column if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'user_achievements' 
      AND column_name = 'unlocked_at'
    ) THEN
      ALTER TABLE public.user_achievements ADD COLUMN unlocked_at TIMESTAMPTZ;
    END IF;
  END IF;
END $$;

-- Create unlocked index after ensuring column exists
CREATE INDEX IF NOT EXISTS idx_user_achievements_unlocked ON public.user_achievements(user_id, is_unlocked) WHERE is_unlocked = true;

-- Challenges (group challenges with friends)
CREATE TABLE IF NOT EXISTS public.challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  challenge_type TEXT NOT NULL, -- steps, workout, nutrition, hydration, etc.
  scope TEXT NOT NULL DEFAULT 'friends', -- friends, local, global
  goal_value NUMERIC(10, 2) NOT NULL,
  goal_unit TEXT, -- steps, minutes, liters, etc.
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  reward_xp INTEGER NOT NULL DEFAULT 0,
  reward_points INTEGER NOT NULL DEFAULT 0,
  max_participants INTEGER,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Challenge members (who joined)
CREATE TABLE IF NOT EXISTS public.challenge_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(challenge_id, user_id)
);

-- Challenge progress (individual progress in challenges)
CREATE TABLE IF NOT EXISTS public.challenge_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  current_progress NUMERIC(10, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(challenge_id, user_id)
);

-- =========================================
-- STEP 3: CREATE INDEXES
-- =========================================

-- Quest definitions
-- Indexes already created above in the quests table section
-- Note: category index created after column is ensured to exist (see DO block below)

-- User quests (add missing indexes)
CREATE INDEX IF NOT EXISTS idx_user_quests_type ON public.user_quests(type);
CREATE INDEX IF NOT EXISTS idx_user_quests_expires_at ON public.user_quests(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_quests_assigned_at ON public.user_quests(assigned_at);

-- Achievements
-- Note: category index created after column is ensured to exist (see DO block above)
CREATE INDEX IF NOT EXISTS idx_achievements_active ON public.achievements(is_active) WHERE is_active = true;

-- User achievements
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON public.user_achievements(user_id);
-- Note: unlocked index created after column is ensured to exist (see DO block above at line 365)

-- Challenges
CREATE INDEX IF NOT EXISTS idx_challenges_scope ON public.challenges(scope);
CREATE INDEX IF NOT EXISTS idx_challenges_active ON public.challenges(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_challenges_dates ON public.challenges(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_challenges_created_by ON public.challenges(created_by);

-- Challenge members
CREATE INDEX IF NOT EXISTS idx_challenge_members_challenge_id ON public.challenge_members(challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_members_user_id ON public.challenge_members(user_id);

-- Challenge progress
CREATE INDEX IF NOT EXISTS idx_challenge_progress_challenge_id ON public.challenge_progress(challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_progress_user_id ON public.challenge_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_challenge_progress_rank ON public.challenge_progress(challenge_id, current_progress DESC);

-- =========================================
-- STEP 4: CREATE TRIGGERS
-- =========================================

-- Updated_at triggers for new tables
CREATE TRIGGER trg_quests_updated_at
  BEFORE UPDATE ON public.quests
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_achievements_updated_at
  BEFORE UPDATE ON public.achievements
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_achievements_updated_at
  BEFORE UPDATE ON public.user_achievements
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_challenges_updated_at
  BEFORE UPDATE ON public.challenges
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_challenge_progress_updated_at
  BEFORE UPDATE ON public.challenge_progress
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- =========================================
-- STEP 5: ENABLE RLS
-- =========================================

ALTER TABLE public.quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_progress ENABLE ROW LEVEL SECURITY;

-- =========================================
-- STEP 6: CREATE RLS POLICIES
-- =========================================

-- Quests: Public read (anyone can see available quests)
DROP POLICY IF EXISTS "Anyone can view quests" ON public.quests;
CREATE POLICY "Anyone can view quests"
  ON public.quests FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Achievements: Public read
DROP POLICY IF EXISTS "Anyone can view achievements" ON public.achievements;
CREATE POLICY "Anyone can view achievements"
  ON public.achievements FOR SELECT
  TO authenticated
  USING (is_active = true);

-- User achievements: Users can manage own
DROP POLICY IF EXISTS "Users can manage own achievements" ON public.user_achievements;
CREATE POLICY "Users can manage own achievements"
  ON public.user_achievements FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Challenges: Anyone can view active challenges
DROP POLICY IF EXISTS "Anyone can view active challenges" ON public.challenges;
CREATE POLICY "Anyone can view active challenges"
  ON public.challenges FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Challenge members: Participants can view, anyone can join
DROP POLICY IF EXISTS "Anyone can view challenge members" ON public.challenge_members;
CREATE POLICY "Anyone can view challenge members"
  ON public.challenge_members FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can join challenges" ON public.challenge_members;
CREATE POLICY "Users can join challenges"
  ON public.challenge_members FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Challenge progress: Participants can view, users can update own
DROP POLICY IF EXISTS "Anyone can view challenge progress" ON public.challenge_progress;
CREATE POLICY "Anyone can view challenge progress"
  ON public.challenge_progress FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can update own challenge progress" ON public.challenge_progress;
CREATE POLICY "Users can update own challenge progress"
  ON public.challenge_progress FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =========================================
-- STEP 7: CREATE RPC FUNCTIONS
-- =========================================

-- Function: allocate_daily_quests(user_id)
CREATE OR REPLACE FUNCTION public.allocate_daily_quests(p_user_id UUID)
RETURNS TABLE(quest_id UUID, quest_definition_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings RECORD;
  v_slots INTEGER;
  v_today DATE;
  v_expires_at TIMESTAMPTZ;
  v_quest_def RECORD;
  v_quest_instance_id UUID;
  v_completed_ids TEXT[];
BEGIN
  -- Get or create user quest settings
  SELECT * INTO v_settings
  FROM public.user_quest_settings
  WHERE user_id = p_user_id;
  
  IF v_settings IS NULL THEN
    INSERT INTO public.user_quest_settings (user_id, daily_quest_slots)
    VALUES (p_user_id, 5)
    RETURNING * INTO v_settings;
  END IF;
  
  v_slots := v_settings.daily_quest_slots;
  v_today := CURRENT_DATE;
  v_expires_at := (v_today + INTERVAL '1 day')::TIMESTAMPTZ;
  
  -- Get completed quests in last 7 days (for cooldown)
  SELECT ARRAY_AGG(DISTINCT quest_definition_id) INTO v_completed_ids
  FROM public.user_quests
  WHERE user_id = p_user_id
    AND status = 'claimed'
    AND claimed_at >= (CURRENT_DATE - INTERVAL '7 days')::TIMESTAMPTZ;
  
  -- Get current daily quests
  DELETE FROM public.user_quests
  WHERE user_id = p_user_id
    AND type = 'daily'
    AND expires_at < NOW();
  
  -- Select available quests (not in cooldown, daily type, active)
  -- Join to get category from quests table
  FOR v_quest_def IN
    SELECT q.* FROM public.quests q
    WHERE q.quest_type = 'daily'
      AND q.is_active = true
      AND (v_completed_ids IS NULL OR q.id != ALL(v_completed_ids))
    ORDER BY RANDOM()
    LIMIT v_slots
  LOOP
    -- Check if user already has this quest today
    -- Note: user_quests may use quest_definition_id or quest_id - check your schema
    IF NOT EXISTS (
      SELECT 1 FROM public.user_quests
      WHERE user_id = p_user_id
        AND (quest_definition_id = v_quest_def.id OR quest_id = v_quest_def.id)
        AND type = 'daily'
        AND assigned_at::DATE = v_today
    ) THEN
      INSERT INTO public.user_quests (
        user_id,
        quest_definition_id,
        type,
        category,
        difficulty,
        status,
        progress_target,
        reward_xp,
        reward_coins,
        assigned_at,
        expires_at
      ) VALUES (
        p_user_id,
        v_quest_def.id,
        'daily',
        v_quest_def.category,  -- Get category from quests table
        v_quest_def.difficulty,
        'available',
        (v_quest_def.requirements->>'target')::NUMERIC,
        v_quest_def.reward_xp,
        0,
        NOW(),
        v_expires_at
      )
      RETURNING id INTO v_quest_instance_id;
      
      RETURN QUERY SELECT v_quest_instance_id, v_quest_def.id;
    END IF;
  END LOOP;
  
  -- Update last refresh
  UPDATE public.user_quest_settings
  SET last_daily_refresh = NOW()
  WHERE user_id = p_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.allocate_daily_quests FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.allocate_daily_quests TO authenticated;

-- Function: allocate_weekly_quests(user_id)
CREATE OR REPLACE FUNCTION public.allocate_weekly_quests(p_user_id UUID)
RETURNS TABLE(quest_id UUID, quest_definition_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings RECORD;
  v_slots INTEGER;
  v_week_start DATE;
  v_week_end TIMESTAMPTZ;
  v_quest_def RECORD;
  v_quest_instance_id UUID;
BEGIN
  SELECT * INTO v_settings
  FROM public.user_quest_settings
  WHERE user_id = p_user_id;
  
  IF v_settings IS NULL THEN
    INSERT INTO public.user_quest_settings (user_id, weekly_quest_slots)
    VALUES (p_user_id, 4)
    RETURNING * INTO v_settings;
  END IF;
  
  v_slots := v_settings.weekly_quest_slots;
  v_week_start := DATE_TRUNC('week', CURRENT_DATE)::DATE;
  v_week_end := (v_week_start + INTERVAL '7 days')::TIMESTAMPTZ;
  
  -- Delete expired weekly quests
  DELETE FROM public.user_quests
  WHERE user_id = p_user_id
    AND type = 'weekly'
    AND expires_at < NOW();
  
  -- Select weekly quests from quests table
  FOR v_quest_def IN
    SELECT q.* FROM public.quests q
    WHERE q.quest_type = 'weekly'
      AND q.is_active = true
    ORDER BY RANDOM()
    LIMIT v_slots
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.user_quests
      WHERE user_id = p_user_id
        AND (quest_definition_id = v_quest_def.id OR quest_id = v_quest_def.id)
        AND type = 'weekly'
        AND assigned_at >= v_week_start::TIMESTAMPTZ
    ) THEN
      INSERT INTO public.user_quests (
        user_id,
        quest_definition_id,
        type,
        category,
        difficulty,
        status,
        progress_target,
        reward_xp,
        reward_coins,
        assigned_at,
        expires_at
      ) VALUES (
        p_user_id,
        v_quest_def.id,
        'weekly',
        v_quest_def.category,  -- Get category from quests table
        v_quest_def.difficulty,
        'available',
        (v_quest_def.requirements->>'target')::NUMERIC,
        v_quest_def.reward_xp,
        0,
        NOW(),
        v_week_end
      )
      RETURNING id INTO v_quest_instance_id;
      
      RETURN QUERY SELECT v_quest_instance_id, v_quest_def.id;
    END IF;
  END LOOP;
  
  UPDATE public.user_quest_settings
  SET last_weekly_refresh = NOW()
  WHERE user_id = p_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.allocate_weekly_quests FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.allocate_weekly_quests TO authenticated;

-- Function: refill_quests(user_id) with limits
CREATE OR REPLACE FUNCTION public.refill_quests(p_user_id UUID)
RETURNS TABLE(quest_id UUID, quest_definition_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_refill_record RECORD;
  v_max_refills INTEGER := 2;
  v_today DATE;
  v_quest_def RECORD;
  v_quest_instance_id UUID;
BEGIN
  v_today := CURRENT_DATE;
  
  -- Get or create refill record
  SELECT * INTO v_refill_record
  FROM public.user_quest_refills
  WHERE user_id = p_user_id
    AND refill_date = v_today;
  
  IF v_refill_record IS NULL THEN
    INSERT INTO public.user_quest_refills (user_id, refill_date, refills_used, refilled_at)
    VALUES (p_user_id, v_today, 0, NOW())
    RETURNING * INTO v_refill_record;
  END IF;
  
  -- Check limit
  IF v_refill_record.refills_used >= v_max_refills THEN
    RAISE EXCEPTION 'Daily refill limit reached (max %)', v_max_refills;
  END IF;
  
  -- Select a new quest from quests table (avoid duplicates)
  SELECT q.* INTO v_quest_def
  FROM public.quests q
  WHERE q.quest_type = 'daily'
    AND q.is_active = true
    AND q.id NOT IN (
      SELECT COALESCE(quest_definition_id, quest_id::TEXT) FROM public.user_quests
      WHERE user_id = p_user_id
        AND type = 'daily'
        AND expires_at::DATE = v_today
    )
  ORDER BY RANDOM()
  LIMIT 1;
  
  IF v_quest_def IS NULL THEN
    RAISE EXCEPTION 'No available quests for refill';
  END IF;
  
  -- Insert new quest
  INSERT INTO public.user_quests (
    user_id,
    quest_definition_id,
    type,
    category,
    difficulty,
    status,
    progress_target,
    reward_xp,
    reward_coins,
    assigned_at,
    expires_at
  ) VALUES (
    p_user_id,
    v_quest_def.id,
    'daily',
        v_quest_def.category,  -- Get category from quests table
        v_quest_def.difficulty,
        'available',
        (v_quest_def.requirements->>'target')::NUMERIC,
        v_quest_def.reward_xp,
        0,
        NOW(),
        (v_today + INTERVAL '1 day')::TIMESTAMPTZ
      )
      RETURNING id INTO v_quest_instance_id;
  
  -- Update refill count
  UPDATE public.user_quest_refills
  SET refills_used = refills_used + 1,
      refilled_at = NOW()
  WHERE user_id = p_user_id
    AND refill_date = v_today;
  
  RETURN QUERY SELECT v_quest_instance_id, v_quest_def.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refill_quests FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refill_quests TO authenticated;

-- Function: update_quest_progress(quest_instance_id, delta)
CREATE OR REPLACE FUNCTION public.update_quest_progress(
  p_quest_instance_id UUID,
  p_delta NUMERIC
)
RETURNS TABLE(
  quest_id UUID,
  current_progress NUMERIC,
  target_progress NUMERIC,
  is_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quest RECORD;
  v_new_progress NUMERIC;
BEGIN
  -- Get quest
  SELECT * INTO v_quest
  FROM public.user_quests
  WHERE id = p_quest_instance_id
    AND user_id = auth.uid()
    AND status IN ('available', 'in_progress');
  
  IF v_quest IS NULL THEN
    RAISE EXCEPTION 'Quest not found or not accessible';
  END IF;
  
  -- Update progress
  v_new_progress := LEAST(
    (v_quest.progress_current + p_delta),
    v_quest.progress_target
  );
  
  UPDATE public.user_quests
  SET progress_current = v_new_progress,
      status = CASE 
        WHEN v_new_progress >= progress_target THEN 'completed'
        ELSE 'in_progress'
      END,
      completed_at = CASE 
        WHEN v_new_progress >= progress_target AND completed_at IS NULL THEN NOW()
        ELSE completed_at
      END
  WHERE id = p_quest_instance_id;
  
  RETURN QUERY
  SELECT 
    p_quest_instance_id,
    v_new_progress,
    v_quest.progress_target,
    (v_new_progress >= v_quest.progress_target);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_quest_progress FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_quest_progress TO authenticated;

-- Function: claim_quest_rewards(quest_instance_id)
CREATE OR REPLACE FUNCTION public.claim_quest_rewards(p_quest_instance_id UUID)
RETURNS TABLE(
  quest_id UUID,
  xp_awarded INTEGER,
  coins_awarded INTEGER,
  new_total_xp INTEGER,
  new_level INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quest RECORD;
  v_profile RECORD;
  v_new_xp INTEGER;
  v_new_level INTEGER;
BEGIN
  -- Get quest
  SELECT * INTO v_quest
  FROM public.user_quests
  WHERE id = p_quest_instance_id
    AND user_id = auth.uid()
    AND status = 'completed';
  
  IF v_quest IS NULL THEN
    RAISE EXCEPTION 'Quest not found, not completed, or already claimed';
  END IF;
  
  -- Get user profile
  SELECT * INTO v_profile
  FROM public.user_profiles
  WHERE user_id = auth.uid();
  
  IF v_profile IS NULL THEN
    INSERT INTO public.user_profiles (user_id, total_xp, level, coins)
    VALUES (auth.uid(), 0, 1, 0)
    RETURNING * INTO v_profile;
  END IF;
  
  -- Award XP and coins
  v_new_xp := v_profile.total_xp + v_quest.reward_xp;
  v_new_level := FLOOR(v_new_xp / 1000)::INTEGER + 1; -- 1000 XP per level
  
  UPDATE public.user_profiles
  SET total_xp = v_new_xp,
      level = v_new_level,
      coins = coins + COALESCE(v_quest.reward_coins, 0)
  WHERE user_id = auth.uid();
  
  -- Update quest status
  UPDATE public.user_quests
  SET status = 'claimed',
      claimed_at = NOW()
  WHERE id = p_quest_instance_id;
  
  -- Award leaderboard points
  INSERT INTO public.leaderboard_points (user_id, points, period_type, period_start)
  VALUES (
    auth.uid(),
    v_quest.reward_points,
    'daily',
    CURRENT_DATE
  )
  ON CONFLICT (user_id, period_type, period_start)
  DO UPDATE SET points = leaderboard_points.points + v_quest.reward_points;
  
  RETURN QUERY
  SELECT 
    p_quest_instance_id,
    v_quest.reward_xp,
    COALESCE(v_quest.reward_coins, 0),
    v_new_xp,
    v_new_level;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_quest_rewards FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_quest_rewards TO authenticated;

-- Function: create_challenge(title, type, start/end, goal)
CREATE OR REPLACE FUNCTION public.create_challenge(
  p_title TEXT,
  p_description TEXT,
  p_challenge_type TEXT,
  p_scope TEXT,
  p_goal_value NUMERIC,
  p_goal_unit TEXT,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  p_reward_xp INTEGER DEFAULT 0,
  p_reward_points INTEGER DEFAULT 0,
  p_max_participants INTEGER DEFAULT NULL
)
RETURNS TABLE(challenge_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge_id UUID;
BEGIN
  INSERT INTO public.challenges (
    title,
    description,
    challenge_type,
    scope,
    goal_value,
    goal_unit,
    start_date,
    end_date,
    reward_xp,
    reward_points,
    max_participants,
    created_by
  ) VALUES (
    p_title,
    p_description,
    p_challenge_type,
    p_scope,
    p_goal_value,
    p_goal_unit,
    p_start_date,
    p_end_date,
    p_reward_xp,
    p_reward_points,
    p_max_participants,
    auth.uid()
  )
  RETURNING id INTO v_challenge_id;
  
  -- Auto-join creator
  INSERT INTO public.challenge_members (challenge_id, user_id)
  VALUES (v_challenge_id, auth.uid())
  ON CONFLICT DO NOTHING;
  
  -- Initialize progress
  INSERT INTO public.challenge_progress (challenge_id, user_id, current_progress)
  VALUES (v_challenge_id, auth.uid(), 0)
  ON CONFLICT DO NOTHING;
  
  RETURN QUERY SELECT v_challenge_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_challenge FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_challenge TO authenticated;

-- Function: join_challenge(challenge_id)
CREATE OR REPLACE FUNCTION public.join_challenge(p_challenge_id UUID)
RETURNS TABLE(success BOOLEAN, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge RECORD;
BEGIN
  -- Get challenge
  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
    AND is_active = true;
  
  IF v_challenge IS NULL THEN
    RETURN QUERY SELECT false, 'Challenge not found or inactive';
    RETURN;
  END IF;
  
  -- Check if already joined
  IF EXISTS (
    SELECT 1 FROM public.challenge_members
    WHERE challenge_id = p_challenge_id
      AND user_id = auth.uid()
  ) THEN
    RETURN QUERY SELECT false, 'Already joined this challenge';
    RETURN;
  END IF;
  
  -- Check max participants
  IF v_challenge.max_participants IS NOT NULL THEN
    IF (
      SELECT COUNT(*) FROM public.challenge_members
      WHERE challenge_id = p_challenge_id
    ) >= v_challenge.max_participants THEN
      RETURN QUERY SELECT false, 'Challenge is full';
      RETURN;
    END IF;
  END IF;
  
  -- Join challenge
  INSERT INTO public.challenge_members (challenge_id, user_id)
  VALUES (p_challenge_id, auth.uid())
  ON CONFLICT DO NOTHING;
  
  -- Initialize progress
  INSERT INTO public.challenge_progress (challenge_id, user_id, current_progress)
  VALUES (p_challenge_id, auth.uid(), 0)
  ON CONFLICT DO NOTHING;
  
  RETURN QUERY SELECT true, 'Successfully joined challenge';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.join_challenge FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_challenge TO authenticated;

-- Function: update_challenge_progress(challenge_id, delta)
CREATE OR REPLACE FUNCTION public.update_challenge_progress(
  p_challenge_id UUID,
  p_delta NUMERIC
)
RETURNS TABLE(
  challenge_id UUID,
  current_progress NUMERIC,
  goal_value NUMERIC,
  is_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge RECORD;
  v_new_progress NUMERIC;
BEGIN
  -- Get challenge
  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
    AND is_active = true;
  
  IF v_challenge IS NULL THEN
    RAISE EXCEPTION 'Challenge not found or inactive';
  END IF;
  
  -- Check if user is a member
  IF NOT EXISTS (
    SELECT 1 FROM public.challenge_members
    WHERE challenge_id = p_challenge_id
      AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not a member of this challenge';
  END IF;
  
  -- Update progress
  INSERT INTO public.challenge_progress (challenge_id, user_id, current_progress)
  VALUES (p_challenge_id, auth.uid(), p_delta)
  ON CONFLICT (challenge_id, user_id)
  DO UPDATE SET 
    current_progress = LEAST(
      challenge_progress.current_progress + p_delta,
      v_challenge.goal_value
    ),
    updated_at = NOW();
  
  SELECT current_progress INTO v_new_progress
  FROM public.challenge_progress
  WHERE challenge_id = p_challenge_id
    AND user_id = auth.uid();
  
  RETURN QUERY
  SELECT 
    p_challenge_id,
    v_new_progress,
    v_challenge.goal_value,
    (v_new_progress >= v_challenge.goal_value);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_challenge_progress FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_challenge_progress TO authenticated;

-- Function: get_leaderboard(period_type, period_start, limit, cursor)
CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_period_type TEXT, -- daily, weekly, monthly
  p_period_start DATE,
  p_limit INTEGER DEFAULT 50,
  p_cursor_points INTEGER DEFAULT NULL,
  p_cursor_user_id UUID DEFAULT NULL
)
RETURNS TABLE(
  user_id UUID,
  username TEXT,
  avatar_url TEXT,
  rank BIGINT,
  points INTEGER,
  total_xp INTEGER,
  level INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH ranked AS (
    SELECT 
      lp.user_id,
      p.username,
      p.avatar_url,
      lp.points,
      up.total_xp,
      up.level,
      ROW_NUMBER() OVER (ORDER BY lp.points DESC, lp.user_id) AS rn
    FROM public.leaderboard_points lp
    JOIN public.profiles p ON p.id = lp.user_id
    LEFT JOIN public.user_profiles up ON up.user_id = lp.user_id
    WHERE lp.period_type = p_period_type
      AND lp.period_start = p_period_start
      AND (
        p_cursor_points IS NULL 
        OR lp.points < p_cursor_points
        OR (lp.points = p_cursor_points AND (p_cursor_user_id IS NULL OR lp.user_id > p_cursor_user_id))
      )
    ORDER BY lp.points DESC, lp.user_id
    LIMIT p_limit
  )
  SELECT 
    user_id,
    COALESCE(username, 'User') AS username,
    avatar_url,
    rn AS rank,
    points,
    COALESCE(total_xp, 0) AS total_xp,
    COALESCE(level, 1) AS level
  FROM ranked
  ORDER BY rank;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_leaderboard FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_leaderboard TO authenticated;

-- =========================================
-- STEP 8: SEED INITIAL QUEST DEFINITIONS
-- =========================================

-- Insert default quest definitions (idempotent)
-- Handle both TEXT and UUID id types
DO $$
DECLARE
  v_id_type TEXT;
  v_quest_id TEXT;
BEGIN
  -- Check if quests table exists and what type the id column is
  SELECT data_type INTO v_id_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'quests'
    AND column_name = 'id';
  
  IF v_id_type = 'uuid' THEN
    -- If id is UUID, check if quests already exist by title to avoid duplicates
    -- Only insert if quest with same title doesn't exist
    INSERT INTO public.quests (id, title, description, category, difficulty, time_window, reward_xp, reward_points, requirements, cooldown_days, icon_name, icon_color, quest_type)
    SELECT gen_random_uuid(), 'Steps Sprint', 'Hit 8,000 steps today', 'steps', 'easy', 'anytime', 50, 10, '{"target": 8000, "type": "steps"}'::jsonb, 2, 'directions_walk', '#FF9800', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Steps Sprint')
    UNION ALL
    SELECT gen_random_uuid(), '10K Steps', 'Hit 10,000 steps today', 'steps', 'medium', 'anytime', 75, 15, '{"target": 10000, "type": "steps"}'::jsonb, 2, 'directions_walk', '#FF9800', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '10K Steps')
    UNION ALL
    SELECT gen_random_uuid(), 'Early Bird Steps', 'Hit 2,000 steps before 8:00 AM', 'steps', 'medium', 'morning', 60, 12, '{"target": 2000, "type": "steps", "before": "08:00"}'::jsonb, 2, 'wb_twilight', '#FFC300', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Early Bird Steps')
    UNION ALL
    SELECT gen_random_uuid(), 'Hydration Boost', 'Drink 2.0L water today', 'hydration', 'easy', 'anytime', 40, 8, '{"target": 2.0, "type": "water"}'::jsonb, 2, 'water_drop', '#2196F3', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Hydration Boost')
    UNION ALL
    SELECT gen_random_uuid(), 'Meet Water Goal', 'Hit your daily water goal', 'hydration', 'easy', 'anytime', 50, 10, '{"target": 1.0, "type": "water_goal"}'::jsonb, 2, 'water_drop', '#2196F3', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Meet Water Goal')
    UNION ALL
    SELECT gen_random_uuid(), 'Log Meals', 'Log 2 meals today', 'nutrition', 'easy', 'anytime', 40, 8, '{"target": 2, "type": "meals"}'::jsonb, 2, 'restaurant', '#4CAF50', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Log Meals')
    UNION ALL
    SELECT gen_random_uuid(), 'Protein Power', 'Hit 80g protein today', 'nutrition', 'medium', 'anytime', 60, 12, '{"target": 80, "type": "protein"}'::jsonb, 2, 'fitness_center', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Protein Power')
    UNION ALL
    SELECT gen_random_uuid(), 'Daily Check-in', 'Open Cotrainr and log 1 metric', 'consistency', 'easy', 'anytime', 20, 5, '{"target": 1, "type": "log_metric"}'::jsonb, 2, 'check_circle', '#9C27B0', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Daily Check-in')
    UNION ALL
    SELECT gen_random_uuid(), 'Quick Workout', 'Complete 15 min workout today', 'workout', 'easy', 'anytime', 60, 12, '{"target": 15, "type": "workout_minutes"}'::jsonb, 2, 'fitness_center', '#F44336', 'daily'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Quick Workout')
    UNION ALL
    SELECT gen_random_uuid(), 'Steps Marathon', 'Total 50,000 steps this week', 'steps', 'medium', 'anytime', 250, 50, '{"target": 50000, "type": "steps", "period": "week"}'::jsonb, 0, 'directions_walk', '#FF9800', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Steps Marathon')
    UNION ALL
    SELECT gen_random_uuid(), 'Meal Consistency', 'Log meals 5 days this week', 'nutrition', 'medium', 'anytime', 200, 40, '{"target": 5, "type": "meals_days", "period": "week"}'::jsonb, 0, 'restaurant', '#4CAF50', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Meal Consistency')
    UNION ALL
    SELECT gen_random_uuid(), 'Hydration Streak', 'Hit water goal 4 days this week', 'hydration', 'medium', 'anytime', 180, 35, '{"target": 4, "type": "water_goal_days", "period": "week"}'::jsonb, 0, 'water_drop', '#2196F3', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Hydration Streak')
    UNION ALL
    SELECT gen_random_uuid(), 'Workout Week', 'Complete 3 workouts this week', 'workout', 'medium', 'anytime', 220, 45, '{"target": 3, "type": "workouts", "period": "week"}'::jsonb, 0, 'fitness_center', '#F44336', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = 'Workout Week')
    UNION ALL
    SELECT gen_random_uuid(), '5-Day Streak', 'Maintain a 5-day streak', 'consistency', 'hard', 'anytime', 300, 60, '{"target": 5, "type": "streak_days", "period": "week"}'::jsonb, 0, 'local_fire_department', '#FF9800', 'weekly'
    WHERE NOT EXISTS (SELECT 1 FROM public.quests WHERE title = '5-Day Streak');
  ELSE
    -- If id is TEXT, use text identifiers
    INSERT INTO public.quests (id, title, description, category, difficulty, time_window, reward_xp, reward_points, requirements, cooldown_days, icon_name, icon_color, quest_type)
    VALUES
      ('daily_steps_8k', 'Steps Sprint', 'Hit 8,000 steps today', 'steps', 'easy', 'anytime', 50, 10, '{"target": 8000, "type": "steps"}'::jsonb, 2, 'directions_walk', '#FF9800', 'daily'),
      ('daily_steps_10k', '10K Steps', 'Hit 10,000 steps today', 'steps', 'medium', 'anytime', 75, 15, '{"target": 10000, "type": "steps"}'::jsonb, 2, 'directions_walk', '#FF9800', 'daily'),
      ('daily_steps_morning', 'Early Bird Steps', 'Hit 2,000 steps before 8:00 AM', 'steps', 'medium', 'morning', 60, 12, '{"target": 2000, "type": "steps", "before": "08:00"}'::jsonb, 2, 'wb_twilight', '#FFC300', 'daily'),
      ('daily_water_2l', 'Hydration Boost', 'Drink 2.0L water today', 'hydration', 'easy', 'anytime', 40, 8, '{"target": 2.0, "type": "water"}'::jsonb, 2, 'water_drop', '#2196F3', 'daily'),
      ('daily_water_goal', 'Meet Water Goal', 'Hit your daily water goal', 'hydration', 'easy', 'anytime', 50, 10, '{"target": 1.0, "type": "water_goal"}'::jsonb, 2, 'water_drop', '#2196F3', 'daily'),
      ('daily_meals_2', 'Log Meals', 'Log 2 meals today', 'nutrition', 'easy', 'anytime', 40, 8, '{"target": 2, "type": "meals"}'::jsonb, 2, 'restaurant', '#4CAF50', 'daily'),
      ('daily_protein_80g', 'Protein Power', 'Hit 80g protein today', 'nutrition', 'medium', 'anytime', 60, 12, '{"target": 80, "type": "protein"}'::jsonb, 2, 'fitness_center', '#F44336', 'daily'),
      ('daily_open_app', 'Daily Check-in', 'Open Cotrainr and log 1 metric', 'consistency', 'easy', 'anytime', 20, 5, '{"target": 1, "type": "log_metric"}'::jsonb, 2, 'check_circle', '#9C27B0', 'daily'),
      ('daily_workout_15min', 'Quick Workout', 'Complete 15 min workout today', 'workout', 'easy', 'anytime', 60, 12, '{"target": 15, "type": "workout_minutes"}'::jsonb, 2, 'fitness_center', '#F44336', 'daily'),
      ('weekly_steps_50k', 'Steps Marathon', 'Total 50,000 steps this week', 'steps', 'medium', 'anytime', 250, 50, '{"target": 50000, "type": "steps", "period": "week"}'::jsonb, 0, 'directions_walk', '#FF9800', 'weekly'),
      ('weekly_meals_5days', 'Meal Consistency', 'Log meals 5 days this week', 'nutrition', 'medium', 'anytime', 200, 40, '{"target": 5, "type": "meals_days", "period": "week"}'::jsonb, 0, 'restaurant', '#4CAF50', 'weekly'),
      ('weekly_water_4days', 'Hydration Streak', 'Hit water goal 4 days this week', 'hydration', 'medium', 'anytime', 180, 35, '{"target": 4, "type": "water_goal_days", "period": "week"}'::jsonb, 0, 'water_drop', '#2196F3', 'weekly'),
      ('weekly_workouts_3', 'Workout Week', 'Complete 3 workouts this week', 'workout', 'medium', 'anytime', 220, 45, '{"target": 3, "type": "workouts", "period": "week"}'::jsonb, 0, 'fitness_center', '#F44336', 'weekly'),
      ('weekly_streak_5days', '5-Day Streak', 'Maintain a 5-day streak', 'consistency', 'hard', 'anytime', 300, 60, '{"target": 5, "type": "streak_days", "period": "week"}'::jsonb, 0, 'local_fire_department', '#FF9800', 'weekly')
    ON CONFLICT (id) DO NOTHING;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    -- If table doesn't exist or other error, skip seed data
    NULL;
END $$;

-- =========================================
-- STEP 9: COMMENTS
-- =========================================

COMMENT ON TABLE public.quests IS 'Server-driven quest templates (daily, weekly, challenge)';
COMMENT ON TABLE public.achievements IS 'Achievement definitions (milestones, badges)';
COMMENT ON TABLE public.user_achievements IS 'User achievement progress and unlocks';
COMMENT ON TABLE public.challenges IS 'Group challenges with friends/local/global scope';
COMMENT ON TABLE public.challenge_members IS 'Challenge participants';
COMMENT ON TABLE public.challenge_progress IS 'Individual progress in challenges';
