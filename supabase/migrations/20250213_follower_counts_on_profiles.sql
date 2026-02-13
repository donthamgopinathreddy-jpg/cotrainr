-- Add cached follower/following counts to profiles
-- Triggers update counts on user_follows INSERT/DELETE
-- Followers = rows where following_id = profile.id
-- Following = rows where follower_id = profile.id

-- 1. Add columns to profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS followers_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS following_count INTEGER NOT NULL DEFAULT 0;

-- 2. Backfill existing counts
UPDATE public.profiles p
SET 
  followers_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.following_id = p.id),
  following_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.follower_id = p.id);

-- 3. Trigger function to update counts
CREATE OR REPLACE FUNCTION public.update_profile_follow_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- New follow: follower_id started following following_id
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id;
    UPDATE public.profiles SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.following_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 4. Create triggers
DROP TRIGGER IF EXISTS trg_user_follows_update_counts ON public.user_follows;
CREATE TRIGGER trg_user_follows_update_counts
  AFTER INSERT OR DELETE ON public.user_follows
  FOR EACH ROW EXECUTE FUNCTION public.update_profile_follow_counts();

-- 5. Index for profile lookups (profiles.id is PK, already indexed)
COMMENT ON COLUMN public.profiles.followers_count IS 'Cached count: rows in user_follows where following_id = id';
COMMENT ON COLUMN public.profiles.following_count IS 'Cached count: rows in user_follows where follower_id = id';
