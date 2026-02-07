-- =========================================
-- ADD USER FOLLOWS TABLE FOR COCIRCLE SOCIAL FEED
-- =========================================
-- This migration adds a follows table to enable Instagram-style feed:
-- - Posts from users I follow
-- - My own posts
-- - Public posts (optional, can be removed if you only want followed + own)

-- Drop if exists (for idempotency)
DROP TABLE IF EXISTS public.user_follows CASCADE;

-- Create user_follows table
CREATE TABLE public.user_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CONSTRAINT user_follows_no_self_follow CHECK (follower_id != following_id)
);

-- Indexes for efficient queries
CREATE INDEX idx_user_follows_follower_id ON public.user_follows(follower_id);
CREATE INDEX idx_user_follows_following_id ON public.user_follows(following_id);
CREATE INDEX idx_user_follows_created_at ON public.user_follows(created_at DESC);

-- Enable RLS
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their follows" ON public.user_follows;
DROP POLICY IF EXISTS "Users can create follows" ON public.user_follows;
DROP POLICY IF EXISTS "Users can delete their follows" ON public.user_follows;

-- RLS Policies for user_follows
-- Users can view who they follow and who follows them
CREATE POLICY "Users can view their follows" ON public.user_follows
FOR SELECT TO authenticated
USING (follower_id = auth.uid() OR following_id = auth.uid());

-- Users can create follow relationships
CREATE POLICY "Users can create follows" ON public.user_follows
FOR INSERT TO authenticated
WITH CHECK (follower_id = auth.uid());

-- Users can delete their own follow relationships
CREATE POLICY "Users can delete their follows" ON public.user_follows
FOR DELETE TO authenticated
USING (follower_id = auth.uid());

-- =========================================
-- UPDATE POSTS RLS POLICY FOR FOLLOWED USERS
-- =========================================
-- Update the posts SELECT policy to allow viewing:
-- 1. Public posts
-- 2. Posts from users I follow (visibility = 'friends' or 'public')
-- 3. My own posts (any visibility)

DROP POLICY IF EXISTS "Anyone can view public posts" ON public.posts;

CREATE POLICY "Users can view feed posts" ON public.posts
FOR SELECT TO authenticated
USING (
  -- Own posts (any visibility)
  author_id = auth.uid()
  OR
  -- Public posts from anyone
  visibility = 'public'
  OR
  -- Posts from users I follow (friends visibility)
  (
    visibility = 'friends'
    AND EXISTS (
      SELECT 1 FROM public.user_follows uf
      WHERE uf.follower_id = auth.uid()
        AND uf.following_id = posts.author_id
    )
  )
);
