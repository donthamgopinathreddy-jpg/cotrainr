-- =========================================
-- SUPABASE POSTS FEED DIAGNOSTIC INSPECTION
-- =========================================
-- Run this in Supabase SQL Editor
-- Copy ALL output and paste it back

-- =========================================
-- A) TABLE SCHEMAS
-- =========================================

-- Profiles table
SELECT 
    'profiles' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- Posts table
SELECT 
    'posts' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'posts'
ORDER BY ordinal_position;

-- Post media table
SELECT 
    'post_media' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'post_media'
ORDER BY ordinal_position;

-- Post likes table
SELECT 
    'post_likes' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'post_likes'
ORDER BY ordinal_position;

-- Post comments table
SELECT 
    'post_comments' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'post_comments'
ORDER BY ordinal_position;

-- Follows table (check common names)
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name IN ('user_follows', 'follows', 'following', 'user_following')
ORDER BY table_name, ordinal_position;

-- =========================================
-- B) RLS ENABLED STATUS
-- =========================================

SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
    AND tablename IN ('profiles', 'posts', 'post_media', 'post_likes', 'post_comments', 
                      'user_follows', 'follows', 'following', 'user_following')
ORDER BY tablename;

-- =========================================
-- C) RLS POLICIES
-- =========================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public' 
    AND tablename IN ('profiles', 'posts', 'post_media', 'post_likes', 'post_comments',
                      'user_follows', 'follows', 'following', 'user_following')
ORDER BY tablename, policyname;

-- =========================================
-- D) TABLE GRANTS
-- =========================================

SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public' 
    AND table_name IN ('profiles', 'posts', 'post_media', 'post_likes', 'post_comments',
                       'user_follows', 'follows', 'following', 'user_following')
ORDER BY table_name, grantee, privilege_type;

-- =========================================
-- E) INDEXES
-- =========================================

SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public' 
    AND tablename IN ('profiles', 'posts', 'post_media', 'post_likes', 'post_comments',
                      'user_follows', 'follows', 'following', 'user_following')
ORDER BY tablename, indexname;

-- =========================================
-- F) ROW COUNTS
-- =========================================

-- Total posts
SELECT 
    'Total posts' as metric,
    COUNT(*)::text as value
FROM public.posts;

-- Public posts
SELECT 
    'Public posts' as metric,
    COUNT(*)::text as value
FROM public.posts
WHERE visibility = 'public';

-- Posts by visibility breakdown
SELECT 
    visibility,
    COUNT(*) as count
FROM public.posts
GROUP BY visibility
ORDER BY count DESC;

-- Sample posts (first 5) with details
SELECT 
    id,
    author_id,
    visibility,
    created_at,
    LEFT(content, 50) as content_preview,
    likes_count,
    comments_count
FROM public.posts 
ORDER BY created_at DESC 
LIMIT 5;

-- =========================================
-- G) RLS POLICY LOGIC TEST
-- =========================================
-- Note: This will only work in authenticated context
-- In SQL Editor with service_role, it may show all posts
-- In Flutter with authenticated user, RLS will apply

-- Show what the RLS policy logic would return
-- (This simulates what an authenticated user would see)
SELECT 
    'RLS Test: Posts visible to authenticated user' as test_name,
    COUNT(*) as visible_count
FROM public.posts
WHERE 
    -- Own posts (any visibility)
    author_id = COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
    OR 
    -- Public posts
    visibility = 'public'
    OR 
    -- Posts from followed users (if follows table exists)
    (
        visibility = 'friends' 
        AND EXISTS (
            SELECT 1 FROM public.user_follows uf
            WHERE uf.follower_id = COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
            AND uf.following_id = posts.author_id
        )
    );

-- =========================================
-- H) STORAGE INSPECTION
-- =========================================

-- List buckets
SELECT 
    name as bucket_name,
    public as is_public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE name IN ('posts', 'avatars', 'post-media', 'media', 'covers')
ORDER BY name;

-- Storage policies (if accessible)
SELECT 
    b.name as bucket_name,
    p.policyname,
    p.cmd as command,
    p.qual as using_expression,
    p.with_check as with_check_expression
FROM storage.buckets b
LEFT JOIN pg_policies p ON p.tablename = 'objects' AND p.schemaname = 'storage'
WHERE b.name IN ('posts', 'avatars', 'post-media', 'media', 'covers')
ORDER BY b.name, p.policyname;

-- =========================================
-- I) FOREIGN KEY RELATIONSHIPS
-- =========================================

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN ('posts', 'post_media', 'post_likes', 'post_comments',
                          'user_follows', 'follows', 'following', 'user_following')
ORDER BY tc.table_name;

-- =========================================
-- J) AUTH CONTEXT CHECK
-- =========================================

SELECT 
    'auth.uid()' as function_name,
    auth.uid()::text as current_user_id,
    CASE 
        WHEN auth.uid() IS NULL THEN 'NULL - Running as service_role or anon'
        ELSE 'OK - Authenticated user context'
    END as status;

-- =========================================
-- K) POSTS WITH AUTHOR INFO (JOIN TEST)
-- =========================================
-- This tests if the join works

SELECT 
    p.id,
    p.author_id,
    p.visibility,
    p.created_at,
    pr.username as author_username,
    pr.full_name as author_full_name,
    pr.avatar_url as author_avatar
FROM public.posts p
LEFT JOIN public.profiles pr ON pr.id = p.author_id
ORDER BY p.created_at DESC
LIMIT 5;

-- =========================================
-- L) CHECK IF FOLLOWS TABLE EXISTS AND HAS DATA
-- =========================================

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_follows')
        THEN 'user_follows table EXISTS'
        ELSE 'user_follows table DOES NOT EXIST'
    END as follows_table_status;

-- If exists, show sample data
SELECT 
    follower_id,
    following_id,
    created_at
FROM public.user_follows
LIMIT 5;

-- =========================================
-- INSPECTION COMPLETE
-- =========================================
-- Copy all query results above and paste them back for analysis
