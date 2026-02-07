-- =========================================
-- FIX POSTS TO PROFILES RELATIONSHIP
-- =========================================
-- This creates a view or function to help with the join
-- OR we can test if the join works with the simplified syntax

-- Option 1: Test the current join syntax
-- Run this in Supabase SQL Editor to see if join works:
SELECT 
    p.id,
    p.author_id,
    p.content,
    pr.username,
    pr.full_name
FROM posts p
LEFT JOIN profiles pr ON pr.id = p.author_id
WHERE p.visibility = 'public'
LIMIT 5;

-- If the above works, then the issue is in Flutter query syntax
-- If it doesn't work, check RLS on profiles table

-- Option 2: Verify profiles RLS allows reading other users' profiles
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'profiles' AND schemaname = 'public';

-- Expected: Should see "Authenticated can view basic profiles" policy
-- that allows SELECT for authenticated users
