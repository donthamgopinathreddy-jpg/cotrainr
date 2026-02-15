-- Fix: New users unable to save profile/cover images
-- 1) Add update_my_profile RPC for robust profile updates (handles missing profile)
-- 2) Ensure avatars bucket and storage policies exist
-- 3) Ensure profiles has avatar_url, cover_url columns

-- 1) Ensure avatar_url and cover_url columns exist
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_url TEXT;

-- 2) Create update_my_profile RPC - SECURITY DEFINER, ensures profile exists
CREATE OR REPLACE FUNCTION public.update_my_profile(p_updates jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
  v_exists boolean;
  v_username text;
  v_username_lower text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Block role and email from client updates (security)
  p_updates := p_updates - 'role' - 'email' - 'id';

  -- Ensure profile exists (handle_new_user may have failed or not run yet)
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = v_uid) INTO v_exists;

  IF NOT v_exists THEN
    BEGIN
      -- Create profile from auth.users (in case handle_new_user didn't run)
      SELECT
        COALESCE(u.raw_user_meta_data->>'username', 'user_' || substring(u.id::text, 1, 8)),
        lower(COALESCE(u.raw_user_meta_data->>'username', 'user_' || substring(u.id::text, 1, 8)))
      INTO v_username, v_username_lower
      FROM auth.users u WHERE u.id = v_uid;

      IF v_username IS NULL OR v_username = '' THEN
        v_username := 'user_' || substring(v_uid::text, 1, 8);
        v_username_lower := v_username;
      END IF;

      INSERT INTO public.profiles (
        id, role, email, username, username_lower, full_name, phone,
        date_of_birth, gender, height_cm, weight_kg, avatar_url, cover_url
      )
      SELECT
        u.id,
        COALESCE((u.raw_user_meta_data->>'role')::public.user_role, 'client'::public.user_role),
        u.email,
        v_username,
        v_username_lower,
        COALESCE(u.raw_user_meta_data->>'full_name', ''),
        NULLIF(u.raw_user_meta_data->>'phone', ''),
        CASE WHEN u.raw_user_meta_data->>'dob' IS NOT NULL
          THEN (u.raw_user_meta_data->>'dob')::date ELSE NULL END,
        NULLIF(u.raw_user_meta_data->>'gender', ''),
        CASE WHEN u.raw_user_meta_data->>'height_cm' IS NOT NULL
          THEN (u.raw_user_meta_data->>'height_cm')::integer ELSE NULL END,
        CASE WHEN u.raw_user_meta_data->>'weight_kg' IS NOT NULL
          THEN (u.raw_user_meta_data->>'weight_kg')::numeric(5,2) ELSE NULL END,
        NULL,
        NULL
      FROM auth.users u
      WHERE u.id = v_uid;
    EXCEPTION
      WHEN unique_violation THEN
        NULL; -- Profile already exists (race), continue to UPDATE
    END;
  END IF;

  -- Update profile with allowed fields only (core fields that always exist)
  UPDATE public.profiles
  SET
    full_name = CASE WHEN p_updates ? 'full_name' THEN (p_updates->>'full_name')::text ELSE full_name END,
    phone = CASE WHEN p_updates ? 'phone' THEN (p_updates->>'phone')::text ELSE phone END,
    date_of_birth = CASE WHEN p_updates ? 'date_of_birth' THEN (p_updates->>'date_of_birth')::date ELSE date_of_birth END,
    gender = CASE WHEN p_updates ? 'gender' THEN (p_updates->>'gender')::text ELSE gender END,
    height_cm = CASE WHEN p_updates ? 'height_cm' THEN (p_updates->>'height_cm')::integer ELSE height_cm END,
    weight_kg = CASE WHEN p_updates ? 'weight_kg' THEN (p_updates->>'weight_kg')::numeric(5,2) ELSE weight_kg END,
    bio = CASE WHEN p_updates ? 'bio' THEN (p_updates->>'bio')::text ELSE bio END,
    avatar_url = CASE WHEN p_updates ? 'avatar_url' THEN (p_updates->>'avatar_url')::text ELSE avatar_url END,
    cover_url = CASE WHEN p_updates ? 'cover_url' THEN (p_updates->>'cover_url')::text ELSE cover_url END,
    updated_at = NOW()
  WHERE id = v_uid;

  -- Username update (with validation)
  IF p_updates ? 'username' AND (p_updates->>'username') IS NOT NULL AND (p_updates->>'username') <> '' THEN
    v_username := (p_updates->>'username');
    IF v_username !~ '^[A-Za-z0-9_]{3,20}$' THEN
      RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
    END IF;
    v_username_lower := lower(v_username);
    IF EXISTS(SELECT 1 FROM public.profiles WHERE username_lower = v_username_lower AND id <> v_uid) THEN
      RAISE EXCEPTION 'Username already exists';
    END IF;
    UPDATE public.profiles SET username = v_username, username_lower = v_username_lower WHERE id = v_uid;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.update_my_profile(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_my_profile(jsonb) TO authenticated;
ALTER FUNCTION public.update_my_profile(jsonb) OWNER TO postgres;

-- 3) Ensure avatars bucket exists (idempotent)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- 4) Storage policies for avatars (drop and recreate for idempotency)
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Public can view avatars" ON storage.objects;

CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Public can view avatars"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');
