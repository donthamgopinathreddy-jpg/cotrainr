-- Create providers row with specialization when signing up as trainer/nutritionist.

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
  v_specialization TEXT[];
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

  IF v_role IN ('trainer'::public.user_role, 'nutritionist'::public.user_role) THEN
    SELECT COALESCE(array_agg(trim(elem)), ARRAY[]::text[])
    INTO v_specialization
    FROM jsonb_array_elements_text(
      COALESCE(NEW.raw_user_meta_data->'specialization', '[]'::jsonb)
    ) AS elem
    WHERE trim(elem) <> '';

    INSERT INTO public.providers (user_id, provider_type, specialization)
    VALUES (
      NEW.id,
      CASE
        WHEN v_role = 'trainer'::public.user_role THEN 'trainer'::public.provider_type
        ELSE 'nutritionist'::public.provider_type
      END,
      NULLIF(v_specialization, ARRAY[]::text[])
    )
    ON CONFLICT (user_id) DO UPDATE SET
      provider_type = EXCLUDED.provider_type,
      specialization = COALESCE(EXCLUDED.specialization, providers.specialization);
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
