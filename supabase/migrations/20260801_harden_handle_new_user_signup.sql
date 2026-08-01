-- Harden signup trigger: safe casts for height/weight/dob, isolate providers insert,
-- and expose username availability check for the signup wizard (anon-safe).

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
  v_dob DATE;
  v_height_cm INTEGER;
  v_weight_kg NUMERIC(5, 2);
  v_phone TEXT;
BEGIN
  v_username := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'username', '')), '');

  IF v_username IS NULL THEN
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

  -- Safe date parse (accepts ISO timestamps like 2002-01-01T00:00:00.000)
  BEGIN
    IF NULLIF(NEW.raw_user_meta_data->>'dob', '') IS NOT NULL THEN
      v_dob := (left(NEW.raw_user_meta_data->>'dob', 10))::DATE;
    ELSE
      v_dob := NULL;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_dob := NULL;
  END;

  -- Safe height: Dart doubles often arrive as "170.0" which ::INTEGER rejects
  BEGIN
    IF NULLIF(NEW.raw_user_meta_data->>'height_cm', '') IS NOT NULL THEN
      v_height_cm := ROUND((NEW.raw_user_meta_data->>'height_cm')::NUMERIC)::INTEGER;
    ELSE
      v_height_cm := NULL;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_height_cm := NULL;
  END;

  BEGIN
    IF NULLIF(NEW.raw_user_meta_data->>'weight_kg', '') IS NOT NULL THEN
      v_weight_kg := ROUND((NEW.raw_user_meta_data->>'weight_kg')::NUMERIC, 2)::NUMERIC(5, 2);
    ELSE
      v_weight_kg := NULL;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_weight_kg := NULL;
  END;

  -- Treat bare country-code-only phone as empty
  v_phone := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');
  IF v_phone IS NOT NULL AND v_phone ~ '^\+[0-9]{1,4}$' THEN
    v_phone := NULL;
  END IF;

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
    COALESCE(NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''), ''),
    v_phone,
    v_dob,
    NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'gender', '')), ''),
    v_height_cm,
    v_weight_kg
  );

  -- Provider row must not abort auth.users insert if it fails
  IF v_role IN ('trainer'::public.user_role, 'nutritionist'::public.user_role) THEN
    BEGIN
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
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user: providers insert failed for %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- Username availability for signup wizard (callable before auth).
CREATE OR REPLACE FUNCTION public.is_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_username TEXT := trim(COALESCE(p_username, ''));
BEGIN
  IF v_username = '' OR v_username !~ '^[A-Za-z0-9_]{3,20}$' THEN
    RETURN FALSE;
  END IF;
  RETURN NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE username_lower = lower(v_username)
  );
END;
$$;

ALTER FUNCTION public.is_username_available(TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.is_username_available(TEXT) TO anon, authenticated;
