-- =========================================
-- FIX POSTS RLS POLICY (SIMPLIFIED VERSION)
-- =========================================
-- This is a simpler version that ensures posts are visible
-- Run this if the previous migration didn't work or if you want to test

-- Drop the new policy if it exists
DROP POLICY IF EXISTS "Users can view feed posts" ON public.posts;

-- Create a simple policy that allows:
-- 1. Own posts (any visibility)
-- 2. Public posts from anyone
-- This ensures posts show up immediately without needing follows table
CREATE POLICY "Users can view feed posts" ON public.posts
FOR SELECT TO authenticated
USING (
  -- Own posts (any visibility)
  author_id = auth.uid()
  OR
  -- Public posts from anyone
  visibility = 'public'
);

-- Note: If you want to add "friends" visibility later, you can update this policy
-- to include the EXISTS check for user_follows table
