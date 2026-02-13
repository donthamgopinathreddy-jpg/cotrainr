-- Add total_xp to user_profiles if missing (dynamic quest system expects it)
-- Idempotent: safe to run multiple times

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_profiles' AND column_name = 'total_xp'
  ) THEN
    ALTER TABLE public.user_profiles ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0;
    UPDATE public.user_profiles SET total_xp = COALESCE(xp, 0) WHERE total_xp = 0;
  END IF;
END $$;
