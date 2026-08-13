-- =============================================================================
-- P0 Signup security + social incomplete profile + legal acceptances
-- Forward-only. Does not modify historical migrations.
-- =============================================================================

-- 1) Role escalation: revoke client-callable role sync
REVOKE ALL ON FUNCTION public.sync_profile_role_from_auth() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_profile_role_from_auth() FROM anon;
REVOKE ALL ON FUNCTION public.sync_profile_role_from_auth() FROM authenticated;
-- Keep available for trusted backend only.
GRANT EXECUTE ON FUNCTION public.sync_profile_role_from_auth() TO service_role;

-- Allow one-time role/username completion when profile is still incomplete
-- (OLD.username IS NULL). Ongoing role changes remain blocked for clients.
CREATE OR REPLACE FUNCTION public.enforce_profiles_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_jwt_role TEXT;
  v_incomplete BOOLEAN;
BEGIN
  BEGIN
    v_jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN
    v_jwt_role := NULL;
  END;

  v_incomplete := (OLD.username IS NULL OR length(trim(OLD.username)) = 0);

  IF v_jwt_role = 'service_role'
     OR current_user = 'postgres'
     OR (SELECT COALESCE(usesuper, false) FROM pg_user WHERE usename = current_user LIMIT 1) THEN
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

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated updates not allowed';
  END IF;

  -- Incomplete stubs: only trusted SECURITY DEFINER paths may finalize.
  -- Block direct client UPDATE (role escalation / skip legal acceptance).
  IF v_incomplete THEN
    RAISE EXCEPTION 'Incomplete profiles must be completed via complete_cotrainr_profile';
  END IF;

  -- Complete profiles: freeze role + email
  NEW.role := OLD.role;
  NEW.email := OLD.email;

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

ALTER FUNCTION public.enforce_profiles_fields() OWNER TO postgres;

-- 2) Allow incomplete social profiles (username NULL until Cotrainr completion)
ALTER TABLE public.profiles
  ALTER COLUMN username DROP NOT NULL;

ALTER TABLE public.profiles
  ALTER COLUMN username_lower DROP NOT NULL;

-- Replace unconditional unique with partial unique (NULL usernames allowed for incomplete)
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_username_lower_unique;

DROP INDEX IF EXISTS idx_profiles_username_lower_unique;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_lower_unique
  ON public.profiles (username_lower)
  WHERE username_lower IS NOT NULL;

-- 3) Legal acceptances (one current row per user; versions re-consent later)
CREATE TABLE IF NOT EXISTS public.legal_acceptances (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  terms_version TEXT NOT NULL,
  privacy_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own legal acceptance" ON public.legal_acceptances;
CREATE POLICY "Users read own legal acceptance"
  ON public.legal_acceptances
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Writes only via SECURITY DEFINER RPC (no direct INSERT/UPDATE for clients)
DROP POLICY IF EXISTS "Users insert own legal acceptance" ON public.legal_acceptances;
DROP POLICY IF EXISTS "Users update own legal acceptance" ON public.legal_acceptances;

REVOKE ALL ON TABLE public.legal_acceptances FROM PUBLIC;
REVOKE ALL ON TABLE public.legal_acceptances FROM anon;
GRANT SELECT ON TABLE public.legal_acceptances TO authenticated;
GRANT ALL ON TABLE public.legal_acceptances TO service_role;

-- Current legal document versions (bump when legal text changes)
CREATE OR REPLACE FUNCTION public.current_legal_versions()
RETURNS TABLE(terms_version TEXT, privacy_version TEXT)
LANGUAGE sql
STABLE
AS $$
  SELECT '2026-08-01'::TEXT, '2026-08-01'::TEXT;
$$;

REVOKE ALL ON FUNCTION public.current_legal_versions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_legal_versions() TO anon, authenticated;

-- 4) handle_new_user: email/password still requires username;
--    OAuth without username creates incomplete stub (role locked to client until completion)
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
BEGIN
  v_username := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'username', '')), '');
  v_full_name := COALESCE(NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
                          NULLIF(trim(NEW.raw_user_meta_data->>'name'), ''),
                          '');

  -- Incomplete social signup: auth user OK, stub profile, no username yet
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
    v_full_name,
    v_phone,
    v_dob,
    NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'gender', '')), ''),
    v_height_cm,
    v_weight_kg
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

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username already exists';
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- 5) Complete Cotrainr profile (social / incomplete) — trusted role write once
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
  p_privacy_version TEXT DEFAULT NULL
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
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_row FROM public.profiles WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  -- Already complete: do not allow role/username mutation via this RPC
  IF v_row.username IS NOT NULL AND length(trim(v_row.username)) > 0 THEN
    RAISE EXCEPTION 'Profile already complete';
  END IF;

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

  SELECT terms_version, privacy_version INTO v_terms, v_privacy
  FROM public.current_legal_versions();

  IF COALESCE(p_terms_version, '') <> v_terms
     OR COALESCE(p_privacy_version, '') <> v_privacy THEN
    RAISE EXCEPTION 'Legal acceptance versions are outdated';
  END IF;

  BEGIN
    IF NULLIF(trim(COALESCE(p_dob, '')), '') IS NOT NULL THEN
      v_dob := (left(p_dob, 10))::DATE;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_dob := NULL;
  END;

  BEGIN
    IF p_height_cm IS NOT NULL THEN
      v_height := ROUND(p_height_cm)::INTEGER;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_height := NULL;
  END;

  BEGIN
    IF p_weight_kg IS NOT NULL THEN
      v_weight := ROUND(p_weight_kg, 2)::NUMERIC(5, 2);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_weight := NULL;
  END;

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
    date_of_birth = COALESCE(v_dob, date_of_birth),
    gender = COALESCE(NULLIF(trim(COALESCE(p_gender, '')), ''), gender),
    height_cm = COALESCE(v_height, height_cm),
    weight_kg = COALESCE(v_weight, weight_kg),
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
      NULLIF(p_specialization, ARRAY[]::text[])
    )
    ON CONFLICT (user_id) DO UPDATE SET
      provider_type = EXCLUDED.provider_type,
      specialization = COALESCE(EXCLUDED.specialization, providers.specialization);
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
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT
) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.complete_cotrainr_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.complete_cotrainr_profile(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT[], TEXT, TEXT
) TO authenticated;

-- 6) Record legal acceptance for email/password signup (profile already complete)
CREATE OR REPLACE FUNCTION public.record_legal_acceptance(
  p_terms_version TEXT,
  p_privacy_version TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_terms TEXT;
  v_privacy TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT terms_version, privacy_version INTO v_terms, v_privacy
  FROM public.current_legal_versions();

  IF COALESCE(p_terms_version, '') <> v_terms
     OR COALESCE(p_privacy_version, '') <> v_privacy THEN
    RAISE EXCEPTION 'Legal acceptance versions are outdated';
  END IF;

  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_version, accepted_at, updated_at)
  VALUES (v_uid, v_terms, v_privacy, now(), now())
  ON CONFLICT (user_id) DO UPDATE SET
    terms_version = EXCLUDED.terms_version,
    privacy_version = EXCLUDED.privacy_version,
    accepted_at = EXCLUDED.accepted_at,
    updated_at = now();
END;
$$;

ALTER FUNCTION public.record_legal_acceptance(TEXT, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.record_legal_acceptance(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_legal_acceptance(TEXT, TEXT) TO authenticated;
