-- Add cover_url column to profiles table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'cover_url'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN cover_url TEXT;
  END IF;
END $$;
