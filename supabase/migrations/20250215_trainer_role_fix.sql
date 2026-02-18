-- Fix: handle_new_user was always setting role='client', ignoring signup choice.
-- Trainers/nutritionists who signed up got client profile and saw client UI.
-- Now we use role from raw_user_meta_data when valid (client/trainer/nutritionist).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_username TEXT;
  v_username_lower TEXT;
  v_role public.user_role;
BEGIN
  v_username := NEW.raw_user_meta_data->>'username';

  IF v_username IS NULL OR v_username = '' THEN
    RAISE EXCEPTION 'Username is required in user metadata';
  END IF;

  IF v_username !~ '^[A-Za-z0-9_]{3,20}$' THEN
    RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
  END IF;

  v_username_lower := lower(v_username);

  IF EXISTS (SELECT 1 FROM public.profiles WHERE username_lower = v_username_lower) THEN
    RAISE EXCEPTION 'Username already exists';
  END IF;

  -- Use role from signup metadata if valid, else default to client
  BEGIN
    v_role := lower(COALESCE(NEW.raw_user_meta_data->>'role', 'client'))::public.user_role;
  EXCEPTION WHEN invalid_text_representation OR OTHERS THEN
    v_role := 'client'::public.user_role;
  END;

  INSERT INTO public.profiles (
    id, role, email, username, username_lower, full_name,
    phone, date_of_birth, gender, height_cm, weight_kg
  )
  VALUES (
    NEW.id,
    v_role,
    NEW.email,
    v_username,
    v_username_lower,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NULLIF(NEW.raw_user_meta_data->>'phone', ''),
    CASE WHEN NEW.raw_user_meta_data->>'dob' IS NOT NULL
      THEN (NEW.raw_user_meta_data->>'dob')::DATE ELSE NULL END,
    NULLIF(NEW.raw_user_meta_data->>'gender', ''),
    CASE WHEN NEW.raw_user_meta_data->>'height_cm' IS NOT NULL
      THEN (NEW.raw_user_meta_data->>'height_cm')::INTEGER ELSE NULL END,
    CASE WHEN NEW.raw_user_meta_data->>'weight_kg' IS NOT NULL
      THEN (NEW.raw_user_meta_data->>'weight_kg')::NUMERIC(5, 2) ELSE NULL END
  );

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

-- Backfill: update existing profiles where user metadata has trainer/nutritionist but profile has client
UPDATE public.profiles p
SET role = CASE lower(u.raw_user_meta_data->>'role')
  WHEN 'trainer' THEN 'trainer'::public.user_role
  WHEN 'nutritionist' THEN 'nutritionist'::public.user_role
  ELSE p.role
END
FROM auth.users u
WHERE u.id = p.id
  AND p.role = 'client'::public.user_role
  AND lower(COALESCE(u.raw_user_meta_data->>'role', '')) IN ('trainer', 'nutritionist');

-- RPC: sync profile role from auth metadata (safety net for signup flow)
-- Only updates if metadata role is valid and differs from profile
CREATE OR REPLACE FUNCTION public.sync_profile_role_from_auth()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid;
  v_meta_role text;
  v_role public.user_role;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RETURN; END IF;

  SELECT lower(trim(COALESCE(raw_user_meta_data->>'role', '')))
  INTO v_meta_role FROM auth.users WHERE id = v_uid;

  IF v_meta_role IS NULL OR v_meta_role NOT IN ('client','trainer','nutritionist') THEN
    RETURN;
  END IF;

  BEGIN
    v_role := v_meta_role::public.user_role;
  EXCEPTION WHEN invalid_text_representation OR OTHERS THEN
    RETURN;
  END;

  UPDATE public.profiles SET role = v_role WHERE id = v_uid AND role IS DISTINCT FROM v_role;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_profile_role_from_auth() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_profile_role_from_auth() TO authenticated;
ALTER FUNCTION public.sync_profile_role_from_auth() OWNER TO postgres;
