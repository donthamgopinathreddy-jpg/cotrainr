-- COCIRCLE FEED FIX - Idempotent migration for Supabase SQL Editor
-- Uses SECURITY DEFINER RPCs (views cannot be security definer in Postgres)
--
-- IMPORTANT: profiles table is RPC-read-only.
-- - Direct SELECT on public.profiles is REVOKED for all roles.
-- - All application code MUST use these RPCs for profile data:
--   - get_my_profile()           : current user's full profile
--   - get_public_profile(uuid)   : single user's public columns
--   - get_public_profiles(uuid[]) : batch public profiles (max 200 IDs)
--   - search_public_profiles(text, int) : search by username/full_name
--
-- Do NOT query profiles directly. Use the RPCs above.

-- 0) Patch enforce_profiles_fields to allow migration context (postgres user)
--    Migrations run as postgres with no JWT; without this, profile UPDATEs fail.
CREATE OR REPLACE FUNCTION public.enforce_profiles_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_jwt_role TEXT;
BEGIN
  -- service_role guard (if present)
  BEGIN
    v_jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN
    v_jwt_role := NULL;
  END;

  IF v_jwt_role = 'service_role' THEN
    -- allow admin/service modifications but keep username_lower derived
    IF NEW.username IS DISTINCT FROM OLD.username THEN
      IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
      END IF;
      NEW.username_lower := lower(NEW.username);
    ELSE
      NEW.username_lower := OLD.username_lower;
    END IF;
    RETURN NEW;
  END IF;

  -- allow migrations (postgres) and superuser
  IF current_user = 'postgres' OR (SELECT COALESCE(usesuper, false) FROM pg_user WHERE usename = current_user LIMIT 1) THEN
    IF NEW.username IS DISTINCT FROM OLD.username THEN
      IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
      END IF;
      NEW.username_lower := lower(NEW.username);
    ELSE
      NEW.username_lower := OLD.username_lower;
    END IF;
    RETURN NEW;
  END IF;

  -- require auth for non-service updates
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated updates not allowed';
  END IF;

  -- block role changes and email changes for normal users
  NEW.role := OLD.role;
  NEW.email := OLD.email;

  -- username_lower is always derived
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    IF NEW.username IS NULL OR NEW.username = '' OR NEW.username !~ '^[A-Za-z0-9_]{3,20}$' THEN
      RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
    END IF;
    NEW.username_lower := lower(NEW.username);
  ELSE
    NEW.username_lower := OLD.username_lower;
  END IF;

  RETURN NEW;
END;
$$;

-- 1) PROFILES: Ensure required columns exist
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username TEXT,
  ADD COLUMN IF NOT EXISTS username_lower TEXT,
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_url TEXT,
  ADD COLUMN IF NOT EXISTS followers_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS following_count INTEGER NOT NULL DEFAULT 0;

UPDATE public.profiles SET username_lower = lower(username) WHERE username IS NOT NULL AND (username_lower IS NULL OR username_lower <> lower(username));

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_lower_unique ON public.profiles(username_lower) WHERE username_lower IS NOT NULL;

-- Trigger: keep username_lower in sync with username
CREATE OR REPLACE FUNCTION public.sync_username_lower()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  NEW.username_lower := CASE WHEN NEW.username IS NOT NULL THEN lower(NEW.username) ELSE NULL END;
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.sync_username_lower() FROM PUBLIC;
ALTER FUNCTION public.sync_username_lower() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_profiles_sync_username_lower ON public.profiles;
CREATE TRIGGER trg_profiles_sync_username_lower
  BEFORE INSERT OR UPDATE OF username ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_username_lower();

-- user_follows integrity: UNIQUE, CHECK, indexes (idempotent)
DO $$
BEGIN
  ALTER TABLE public.user_follows ADD CONSTRAINT user_follows_follower_following_unique UNIQUE (follower_id, following_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN unique_violation THEN
    RAISE NOTICE 'user_follows_follower_following_unique: duplicate rows exist, skipping. Dedupe and re-run.';
END $$;

DO $$
BEGIN
  ALTER TABLE public.user_follows ADD CONSTRAINT user_follows_no_self_follow CHECK (follower_id <> following_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN check_violation THEN
    RAISE NOTICE 'user_follows_no_self_follow: existing self-follow rows, skipping. Clean data and re-run.';
END $$;

CREATE INDEX IF NOT EXISTS idx_user_follows_follower_id ON public.user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following_id ON public.user_follows(following_id);

-- Backfill followers_count and following_count for ALL profiles
UPDATE public.profiles p
SET
  followers_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.following_id = p.id),
  following_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.follower_id = p.id);

-- user_follows trigger: keep follower/following counts in sync
CREATE OR REPLACE FUNCTION public.update_follow_counts()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id;
    UPDATE public.profiles SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.following_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;

REVOKE ALL ON FUNCTION public.update_follow_counts() FROM PUBLIC;
ALTER FUNCTION public.update_follow_counts() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_user_follows_update_counts ON public.user_follows;
CREATE TRIGGER trg_user_follows_update_counts
  AFTER INSERT OR DELETE ON public.user_follows
  FOR EACH ROW EXECUTE FUNCTION public.update_follow_counts();

-- rebuild_follow_counts: admin-only, recompute followers_count/following_count from user_follows
CREATE OR REPLACE FUNCTION public.rebuild_follow_counts()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles p
  SET
    followers_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.following_id = p.id),
    following_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.follower_id = p.id);
END $$;

REVOKE ALL ON FUNCTION public.rebuild_follow_counts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebuild_follow_counts() TO service_role;
ALTER FUNCTION public.rebuild_follow_counts() OWNER TO postgres;

-- 2) PROFILES RLS: Drop ALL SELECT policies, keep UPDATE and INSERT
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'SELECT')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', r.policyname);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- 3) REVOKE SELECT on profiles (clients use RPCs only)
REVOKE SELECT ON public.profiles FROM PUBLIC;
REVOKE SELECT ON public.profiles FROM anon;
REVOKE SELECT ON public.profiles FROM authenticated;

-- 4) SECURITY DEFINER RPCs for profile access (auth.uid() null guards, SET search_path)
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS SETOF public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  RETURN QUERY SELECT * FROM public.profiles WHERE id = auth.uid();
END $$;

REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
ALTER FUNCTION public.get_my_profile() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.get_public_profile(p_user_id uuid)
RETURNS TABLE(id uuid, username text, full_name text, avatar_url text, role text, followers_count integer, following_count integer, bio text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  RETURN QUERY
    SELECT p.id, p.username, p.full_name, p.avatar_url, p.role::text, p.followers_count, p.following_count, p.bio
    FROM public.profiles p WHERE p.id = p_user_id;
END $$;

REVOKE ALL ON FUNCTION public.get_public_profile(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid) TO authenticated;
ALTER FUNCTION public.get_public_profile(uuid) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.get_public_profiles(p_user_ids uuid[])
RETURNS TABLE(id uuid, username text, full_name text, avatar_url text, role text, followers_count integer, following_count integer, bio text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  ids uuid[];
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL OR array_length(p_user_ids, 1) = 0 THEN RETURN; END IF;
  ids := p_user_ids[1:LEAST(array_length(p_user_ids, 1), 200)];
  RETURN QUERY
    SELECT p.id, p.username, p.full_name, p.avatar_url, p.role::text, p.followers_count, p.following_count, p.bio
    FROM public.profiles p WHERE p.id = ANY(ids);
END $$;

REVOKE ALL ON FUNCTION public.get_public_profiles(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(uuid[]) TO authenticated;
ALTER FUNCTION public.get_public_profiles(uuid[]) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.search_public_profiles(p_query text, p_limit int DEFAULT 20)
RETURNS TABLE(id uuid, username text, full_name text, avatar_url text, role text, followers_count integer, following_count integer, bio text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  q text;
  lim int;
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  q := trim(coalesce(p_query, ''));
  IF q = '' THEN RETURN; END IF;
  lim := GREATEST(1, LEAST(p_limit, 50));
  RETURN QUERY
    SELECT p.id, p.username, p.full_name, p.avatar_url, p.role::text, p.followers_count, p.following_count, p.bio
    FROM public.profiles p
    WHERE p.username_lower LIKE '%' || lower(q) || '%' OR p.full_name ILIKE '%' || q || '%'
    LIMIT lim;
END $$;

REVOKE ALL ON FUNCTION public.search_public_profiles(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(text, int) TO authenticated;
ALTER FUNCTION public.search_public_profiles(text, int) OWNER TO postgres;

-- get_notification_push: for Edge functions (service role) - no direct profiles read
CREATE OR REPLACE FUNCTION public.get_notification_push(p_user_id uuid)
RETURNS TABLE(notification_push boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE
AS $$
BEGIN
  RETURN QUERY SELECT p.notification_push FROM public.profiles p WHERE p.id = p_user_id;
END $$;

REVOKE ALL ON FUNCTION public.get_notification_push(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_notification_push(uuid) TO service_role;
ALTER FUNCTION public.get_notification_push(uuid) OWNER TO postgres;

-- 5) Feed RPC: single query, no per-row RPC (replaces view with N+1)
DROP VIEW IF EXISTS public.cocircle_feed_posts_v CASCADE;
DROP VIEW IF EXISTS public.profiles_public_v CASCADE;
DROP VIEW IF EXISTS public.profiles_own_v CASCADE;

CREATE OR REPLACE FUNCTION public.get_cocircle_feed(
  p_limit int DEFAULT 30,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  author_id uuid,
  content text,
  visibility post_visibility,
  likes_count int,
  comments_count int,
  created_at timestamptz,
  author_username text,
  author_full_name text,
  author_avatar_url text,
  author_role text,
  media jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  lim int;
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  lim := GREATEST(1, LEAST(p_limit, 50));

  RETURN QUERY
  SELECT
    p.id,
    p.author_id,
    p.content,
    p.visibility,
    p.likes_count::int,
    p.comments_count::int,
    p.created_at,
    COALESCE(pr.username, ''),
    COALESCE(pr.full_name, ''),
    COALESCE(pr.avatar_url, ''),
    COALESCE(pr.role::text, ''),
    COALESCE(pm.media, '[]'::jsonb)
  FROM public.posts p
  LEFT JOIN public.profiles pr ON pr.id = p.author_id
  LEFT JOIN LATERAL (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('media_url', m.media_url, 'media_kind', m.media_kind, 'order_index', m.order_index) ORDER BY m.order_index), '[]'::jsonb) AS media
    FROM public.post_media m WHERE m.post_id = p.id
  ) pm ON true
  WHERE (
    p.author_id = auth.uid()
    OR p.visibility = 'public'
    OR (
      p.visibility = 'friends'
      AND EXISTS (
        SELECT 1 FROM public.user_follows uf
        WHERE uf.follower_id = auth.uid() AND uf.following_id = p.author_id
      )
    )
  )
  AND (
    (p_before_created_at IS NULL AND p_before_id IS NULL)
    OR (p_before_created_at IS NOT NULL AND p_before_id IS NOT NULL AND (p.created_at, p.id) < (p_before_created_at, p_before_id))
  )
  ORDER BY p.created_at DESC, p.id DESC
  LIMIT lim;
END $$;

REVOKE ALL ON FUNCTION public.get_cocircle_feed(int, timestamptz, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_cocircle_feed(int, timestamptz, uuid) TO authenticated;
ALTER FUNCTION public.get_cocircle_feed(int, timestamptz, uuid) OWNER TO postgres;

-- 6) Indexes for feed performance
DROP INDEX IF EXISTS public.idx_posts_created_at_desc;
CREATE INDEX IF NOT EXISTS idx_posts_feed_keyset ON public.posts(created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_post_media_post_id_order ON public.post_media(post_id, order_index);
CREATE INDEX IF NOT EXISTS idx_user_follows_follower_following ON public.user_follows(follower_id, following_id);

-- 7) POSTS RLS (for direct table access; feed uses RPC)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'posts' AND schemaname = 'public' AND cmd = 'SELECT')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.posts', r.policyname);
  END LOOP;
END $$;

CREATE POLICY "Posts visibility: own public or friends" ON public.posts
  FOR SELECT TO authenticated
  USING (
    author_id = auth.uid()
    OR visibility = 'public'
    OR (
      visibility = 'friends'
      AND EXISTS (
        SELECT 1 FROM public.user_follows uf
        WHERE uf.follower_id = auth.uid() AND uf.following_id = posts.author_id
      )
    )
  );

-- 8) POST_MEDIA RLS
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'post_media' AND cmd = 'SELECT')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.post_media', r.policyname);
  END LOOP;
END $$;

CREATE POLICY "Post media visibility matches posts" ON public.post_media
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_media.post_id
        AND (
          p.author_id = auth.uid()
          OR p.visibility = 'public'
          OR (
            p.visibility = 'friends'
            AND EXISTS (
              SELECT 1 FROM public.user_follows uf
              WHERE uf.follower_id = auth.uid() AND uf.following_id = p.author_id
            )
          )
        )
    )
  );

-- 9) Prevent manual count updates
CREATE OR REPLACE FUNCTION public.prevent_manual_post_counts()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_setting('app.allow_post_count_update', true) = 'true' THEN
    RETURN NEW;
  END IF;

  NEW.likes_count := OLD.likes_count;
  NEW.comments_count := OLD.comments_count;
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.prevent_manual_post_counts() FROM PUBLIC;
ALTER FUNCTION public.prevent_manual_post_counts() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_prevent_manual_post_counts ON public.posts;
CREATE TRIGGER trg_prevent_manual_post_counts
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_manual_post_counts();

-- 10) LIKES_COUNT trigger
CREATE OR REPLACE FUNCTION public.update_posts_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.allow_post_count_update', 'true', true);
  BEGIN
    IF TG_OP = 'INSERT' THEN
      UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    ELSE
      RAISE EXCEPTION 'update_posts_likes_count called for unsupported TG_OP=%', TG_OP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_post_count_update', 'false', true);
    RAISE;
  END;
  PERFORM set_config('app.allow_post_count_update', 'false', true);
  RETURN COALESCE(NEW, OLD);
END $$;

REVOKE ALL ON FUNCTION public.update_posts_likes_count() FROM PUBLIC;
ALTER FUNCTION public.update_posts_likes_count() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_post_likes_update_count ON public.post_likes;
CREATE TRIGGER trg_post_likes_update_count
  AFTER INSERT OR DELETE ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.update_posts_likes_count();

-- 11) COMMENTS_COUNT trigger
CREATE OR REPLACE FUNCTION public.update_posts_comments_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.allow_post_count_update', 'true', true);
  BEGIN
    IF TG_OP = 'INSERT' THEN
      UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE public.posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
    ELSE
      RAISE EXCEPTION 'update_posts_comments_count called for unsupported TG_OP=%', TG_OP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.allow_post_count_update', 'false', true);
    RAISE;
  END;
  PERFORM set_config('app.allow_post_count_update', 'false', true);
  RETURN COALESCE(NEW, OLD);
END $$;

REVOKE ALL ON FUNCTION public.update_posts_comments_count() FROM PUBLIC;
ALTER FUNCTION public.update_posts_comments_count() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_post_comments_update_count ON public.post_comments;
CREATE TRIGGER trg_post_comments_update_count
  AFTER INSERT OR DELETE ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_posts_comments_count();

-- rebuild_post_counts: admin-only, recompute likes_count/comments_count from post_likes/post_comments
CREATE OR REPLACE FUNCTION public.rebuild_post_counts()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.allow_post_count_update', 'true', true);
  BEGIN
    UPDATE public.posts p
    SET
      likes_count = (SELECT COUNT(*)::INTEGER FROM public.post_likes pl WHERE pl.post_id = p.id),
      comments_count = (SELECT COUNT(*)::INTEGER FROM public.post_comments pc WHERE pc.post_id = p.id);
  EXCEPTION
    WHEN OTHERS THEN
      PERFORM set_config('app.allow_post_count_update', 'false', true);
      RAISE;
  END;
  PERFORM set_config('app.allow_post_count_update', 'false', true);
END $$;

REVOKE ALL ON FUNCTION public.rebuild_post_counts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebuild_post_counts() TO service_role;
ALTER FUNCTION public.rebuild_post_counts() OWNER TO postgres;

-- =============================================================================
-- POST-MIGRATION VERIFICATION QUERIES (run in Supabase SQL Editor after deploy)
-- =============================================================================
-- 1) Run rebuild and inspect top 5 posts
--    SELECT public.rebuild_post_counts();
--    SELECT id, likes_count, comments_count FROM public.posts ORDER BY created_at DESC LIMIT 5;
--
-- 2) Independently validate counts match reality
--    SELECT
--      p.id,
--      p.likes_count,
--      (SELECT COUNT(*) FROM public.post_likes pl WHERE pl.post_id = p.id) AS real_likes,
--      p.comments_count,
--      (SELECT COUNT(*) FROM public.post_comments pc WHERE pc.post_id = p.id) AS real_comments
--    FROM public.posts p
--    ORDER BY p.created_at DESC
--    LIMIT 5;
