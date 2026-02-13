-- FIX: column "category" does not exist
-- Root cause: user_quests or quests may lack category if migrations ran out of order
-- This migration is idempotent and safe to run multiple times

-- 1. Add category to user_quests if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_quests' AND column_name = 'category'
  ) THEN
    ALTER TABLE public.user_quests ADD COLUMN category TEXT NOT NULL DEFAULT 'steps';
    UPDATE public.user_quests SET category = 'steps' WHERE category IS NULL;
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_quests' AND column_name = 'category'
      AND is_nullable = 'YES'
  ) THEN
    UPDATE public.user_quests SET category = 'steps' WHERE category IS NULL;
    ALTER TABLE public.user_quests ALTER COLUMN category SET NOT NULL;
    ALTER TABLE public.user_quests ALTER COLUMN category SET DEFAULT 'steps';
  END IF;
END $$;

-- 2. Add category to quests if missing (for static quest allocation)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'quests'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'quests' AND column_name = 'category'
  ) THEN
    ALTER TABLE public.quests ADD COLUMN category TEXT NOT NULL DEFAULT 'steps';
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'quests'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'quests' AND column_name = 'category'
      AND is_nullable = 'YES'
  ) THEN
    UPDATE public.quests SET category = 'steps' WHERE category IS NULL;
    ALTER TABLE public.quests ALTER COLUMN category SET NOT NULL;
    ALTER TABLE public.quests ALTER COLUMN category SET DEFAULT 'steps';
  END IF;
END $$;

-- 3. Add category to achievements if missing
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'achievements'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'achievements' AND column_name = 'category'
  ) THEN
    ALTER TABLE public.achievements ADD COLUMN category TEXT NOT NULL DEFAULT 'streaks';
  END IF;
END $$;

-- Index for category queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_user_quests_category ON public.user_quests(category);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'quests') THEN
    CREATE INDEX IF NOT EXISTS idx_quests_category ON public.quests(category);
  END IF;
END $$;
