-- =============================================================================
-- Shared onboarding: fitness_goals, atomic social finalize, completeness RPC
-- Forward-only. Does not modify historical migrations.
-- =============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fitness_goals TEXT[];

-- 1) Completeness (authoritative). Codes only — no extra PII.
CREATE OR REPLACE FUNCTION public.get_onboarding_state()
RETURNS TABLE(is_complete BOOLEAN, missing TEXT[])
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_missing TEXT[] := ARRAY[]::TEXT[];
  v_role TEXT;
  v_username TEXT;
  v_dob DATE;
  v_gender TEXT;
  v_height INTEGER;
  v_weight NUMERIC;
  v_goals TEXT[];
  v_legal BOOLEAN := false;
  v_terms TEXT;
  v_privacy TEXT;
  v_specs TEXT[];
  v_legacy BOOLEAN := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT false, ARRAY['unauthenticated']::TEXT[];
    RETURN;
  END IF;

  SELECT
    p.username,
    p.role::TEXT,
    p.date_of_birth,
    p.gender,
    p.height_cm,
    p.weight_kg,
    p.fitness_goals
  INTO v_username, v_role, v_dob, v_gender, v_height, v_weight, v_goals
  FROM public.profiles p
  WHERE p.id = v_uid;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, ARRAY['profile']::TEXT[];
    RETURN;
  END IF;

  SELECT terms_version, privacy_version INTO v_terms, v_privacy
  FROM public.current_legal_versions();

  SELECT EXISTS (
    SELECT 1 FROM public.legal_acceptances l
    WHERE l.user_id = v_uid
      AND l.terms_version = v_terms
      AND l.privacy_version = v_privacy
  ) INTO v_legal;

  -- Pre-migration email users: body complete, fitness_goals never written.
  v_legacy := (v_goals IS NULL)
    AND v_username IS NOT NULL AND length(trim(v_username)) > 0
    AND v_dob IS NOT NULL
    AND v_height IS NOT NULL
    AND v_weight IS NOT NULL;

  IF v_username IS NULL OR length(trim(v_username)) = 0 THEN
    v_missing := array_append(v_missing, 'username');
  END IF;
  IF v_role IS NULL OR v_role NOT IN ('client', 'trainer', 'nutritionist') THEN
    v_missing := array_append(v_missing, 'role');
  END IF;
  IF v_dob IS NULL THEN
    v_missing := array_append(v_missing, 'dob');
  END IF;
  IF v_gender IS NULL OR length(trim(v_gender)) = 0 THEN
    v_missing := array_append(v_missing, 'gender');
  END IF;
  IF v_height IS NULL THEN
    v_missing := array_append(v_missing, 'height');
  END IF;
  IF v_weight IS NULL THEN
    v_missing := array_append(v_missing, 'weight');
  END IF;
  IF NOT v_legacy AND (
       v_goals IS NULL
       OR cardinality(v_goals) = 0
       OR NOT EXISTS (SELECT 1 FROM unnest(v_goals) g WHERE length(trim(g)) > 0)
     ) THEN
    v_missing := array_append(v_missing, 'goals');
  END IF;
  IF NOT v_legacy AND NOT v_legal THEN
    v_missing := array_append(v_missing, 'legal');
  END IF;

  IF v_role IN ('trainer', 'nutritionist') THEN
    SELECT pr.specialization INTO v_specs
    FROM public.providers pr
    WHERE pr.user_id = v_uid;
    IF v_specs IS NULL
       OR cardinality(v_specs) = 0
       OR NOT EXISTS (SELECT 1 FROM unnest(v_specs) s WHERE length(trim(s)) > 0) THEN
      v_missing := array_append(v_missing, 'specialties');
    END IF;
  END IF;

  RETURN QUERY SELECT (cardinality(v_missing) = 0), v_missing;
END;
$$;

ALTER FUNCTION public.get_onboarding_state() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_onboarding_state() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_onboarding_state() TO authenticated;

-- 2) Drop previous complete_cotrainr_profile signature; replace with goals-required version.
DROP FUNCTION IF EXISTS public.complete_cotrainr_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT
);

CREATE OR REPLACE FUNCTION public.complete_cotrainr_profile(
  p_username TEXT,
  p_role TEXT,
  p_full_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_dob TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_height_cm NUMERIC DEFAULT NULL,
  p_weight_kg NUMERIC DEFAULT NULL,
  p_specialization TEXT[] DEFAULT NULL,
  p_terms_version TEXT DEFAULT NULL,
  p_privacy_version TEXT DEFAULT NULL,
  p_goals TEXT[] DEFAULT NULL
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_username TEXT := trim(COALESCE(p_username, ''));
  v_username_lower TEXT;
  v_role public.user_role;
  v_row public.profiles;
  v_terms TEXT;
  v_privacy TEXT;
  v_dob DATE;
  v_height INTEGER;
  v_weight NUMERIC(5, 2);
  v_phone TEXT;
  v_gender TEXT := NULLIF(trim(COALESCE(p_gender, '')), '');
  v_goals TEXT[];
  v_specs TEXT[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_row FROM public.profiles WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  -- Completeness is derived (not username-only). Already-complete users cannot mutate.
  IF EXISTS (
    SELECT 1 FROM public.get_onboarding_state() s WHERE s.is_complete
  ) THEN
    RAISE EXCEPTION 'Profile already complete';
  END IF;

  IF v_row.username IS NOT NULL AND length(trim(v_row.username)) > 0 THEN
    -- Continuation: freeze username + role (P0 — no self-promotion).
    v_username := v_row.username;
    v_username_lower := COALESCE(v_row.username_lower, lower(v_row.username));
    v_role := v_row.role;
  ELSE
    IF v_username = '' OR v_username !~ '^[A-Za-z0-9_]{3,20}$' THEN
      RAISE EXCEPTION 'Username must be 3-20 characters, alphanumeric and underscore only';
    END IF;
    v_username_lower := lower(v_username);

    IF EXISTS (
      SELECT 1 FROM public.profiles
      WHERE username_lower = v_username_lower AND id <> v_uid
    ) THEN
      RAISE EXCEPTION 'Username already exists';
    END IF;

    BEGIN
      v_role := lower(trim(COALESCE(p_role, '')))::public.user_role;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid role';
    END;

    IF v_role NOT IN (
      'client'::public.user_role,
      'trainer'::public.user_role,
      'nutritionist'::public.user_role
    ) THEN
      RAISE EXCEPTION 'Invalid role';
    END IF;
  END IF;

  IF NULLIF(trim(COALESCE(p_dob, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Date of birth is required';
  END IF;
  BEGIN
    v_dob := (left(p_dob, 10))::DATE;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Date of birth is required';
  END;

  IF v_gender IS NULL THEN
    RAISE EXCEPTION 'Gender is required';
  END IF;

  IF p_height_cm IS NULL THEN
    RAISE EXCEPTION 'Height is required';
  END IF;
  v_height := ROUND(p_height_cm)::INTEGER;

  IF p_weight_kg IS NULL THEN
    RAISE EXCEPTION 'Weight is required';
  END IF;
  v_weight := ROUND(p_weight_kg, 2)::NUMERIC(5, 2);

  SELECT COALESCE(array_agg(trim(g)), ARRAY[]::text[])
  INTO v_goals
  FROM unnest(COALESCE(p_goals, ARRAY[]::text[])) AS g
  WHERE length(trim(g)) > 0;

  IF v_goals IS NULL OR cardinality(v_goals) = 0 THEN
    RAISE EXCEPTION 'At least one fitness goal is required';
  END IF;

  SELECT COALESCE(array_agg(trim(s)), ARRAY[]::text[])
  INTO v_specs
  FROM unnest(COALESCE(p_specialization, ARRAY[]::text[])) AS s
  WHERE length(trim(s)) > 0;

  IF v_role IN ('trainer'::public.user_role, 'nutritionist'::public.user_role) THEN
    IF v_specs IS NULL OR cardinality(v_specs) = 0 THEN
      RAISE EXCEPTION 'At least one specialty is required';
    END IF;
  ELSE
    v_specs := NULL;
  END IF;

  SELECT terms_version, privacy_version INTO v_terms, v_privacy
  FROM public.current_legal_versions();

  IF COALESCE(p_terms_version, '') <> v_terms
     OR COALESCE(p_privacy_version, '') <> v_privacy THEN
    RAISE EXCEPTION 'Legal acceptance versions are outdated';
  END IF;

  v_phone := NULLIF(trim(COALESCE(p_phone, '')), '');
  IF v_phone IS NOT NULL AND v_phone ~ '^\+[0-9]{1,4}$' THEN
    v_phone := NULL;
  END IF;

  UPDATE public.profiles SET
    username = v_username,
    username_lower = v_username_lower,
    role = v_role,
    full_name = COALESCE(NULLIF(trim(COALESCE(p_full_name, '')), ''), full_name),
    phone = COALESCE(v_phone, phone),
    date_of_birth = v_dob,
    gender = v_gender,
    height_cm = v_height,
    weight_kg = v_weight,
    fitness_goals = v_goals,
    updated_at = now()
  WHERE id = v_uid
  RETURNING * INTO v_row;

  IF v_role IN ('trainer'::public.user_role, 'nutritionist'::public.user_role) THEN
    INSERT INTO public.providers (user_id, provider_type, specialization)
    VALUES (
      v_uid,
      CASE
        WHEN v_role = 'trainer'::public.user_role THEN 'trainer'::public.provider_type
        ELSE 'nutritionist'::public.provider_type
      END,
      v_specs
    )
    ON CONFLICT (user_id) DO UPDATE SET
      provider_type = EXCLUDED.provider_type,
      specialization = EXCLUDED.specialization;
  END IF;

  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_version, accepted_at, updated_at)
  VALUES (v_uid, v_terms, v_privacy, now(), now())
  ON CONFLICT (user_id) DO UPDATE SET
    terms_version = EXCLUDED.terms_version,
    privacy_version = EXCLUDED.privacy_version,
    accepted_at = EXCLUDED.accepted_at,
    updated_at = now();

  RETURN v_row;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

ALTER FUNCTION public.complete_cotrainr_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT, TEXT[]
) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.complete_cotrainr_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT, TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_cotrainr_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT, TEXT[]
) TO authenticated;

-- 3) Email signup trigger: persist fitness_goals + legal from signup metadata
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
  v_full_name TEXT;
  v_goals TEXT[];
  v_terms TEXT;
  v_privacy TEXT;
  v_meta_terms TEXT;
  v_meta_privacy TEXT;
BEGIN
  v_username := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'username', '')), '');
  v_full_name := COALESCE(NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
                          NULLIF(trim(NEW.raw_user_meta_data->>'name'), ''),
                          '');

  IF v_username IS NULL THEN
    INSERT INTO public.profiles (
      id, role, email, username, username_lower, full_name
    ) VALUES (
      NEW.id,
      'client'::public.user_role,
      NEW.email,
      NULL,
      NULL,
      v_full_name
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
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

  BEGIN
    IF NULLIF(NEW.raw_user_meta_data->>'dob', '') IS NOT NULL THEN
      v_dob := (left(NEW.raw_user_meta_data->>'dob', 10))::DATE;
    ELSE
      v_dob := NULL;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_dob := NULL;
  END;

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

  v_phone := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');
  IF v_phone IS NOT NULL AND v_phone ~ '^\+[0-9]{1,4}$' THEN
    v_phone := NULL;
  END IF;

  BEGIN
    SELECT COALESCE(array_agg(trim(elem)), ARRAY[]::text[])
    INTO v_goals
    FROM jsonb_array_elements_text(
      COALESCE(NEW.raw_user_meta_data->'goals', '[]'::jsonb)
    ) AS elem
    WHERE trim(elem) <> '';
  EXCEPTION WHEN OTHERS THEN
    v_goals := NULL;
  END;

  INSERT INTO public.profiles (
    id, role, email, username, username_lower, full_name,
    phone, date_of_birth, gender, height_cm, weight_kg, fitness_goals
  )
  VALUES (
    NEW.id,
    v_role,
    NEW.email,
    v_username,
    v_username_lower,
    v_full_name,
    v_phone,
    v_dob,
    NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'gender', '')), ''),
    v_height_cm,
    v_weight_kg,
    NULLIF(v_goals, ARRAY[]::text[])
  )
  ON CONFLICT (id) DO NOTHING;

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

  BEGIN
    SELECT terms_version, privacy_version INTO v_terms, v_privacy
    FROM public.current_legal_versions();
    v_meta_terms := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'terms_version', '')), '');
    v_meta_privacy := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'privacy_version', '')), '');
    IF v_meta_terms IS NOT NULL AND v_meta_privacy IS NOT NULL
       AND v_meta_terms = v_terms AND v_meta_privacy = v_privacy THEN
      INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_version, accepted_at, updated_at)
      VALUES (NEW.id, v_terms, v_privacy, now(), now())
      ON CONFLICT (user_id) DO NOTHING;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: legal acceptance failed for %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
