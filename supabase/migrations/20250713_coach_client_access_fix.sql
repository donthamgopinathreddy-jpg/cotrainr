-- Post-accept coach/client access: RLS fixes, sharing columns, access helper RPC.
-- Canonical relationship remains public.leads with status = 'accepted'.

-- ---------------------------------------------------------------------------
-- 1) Client sharing preferences (persisted; default allow for backward compat)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS share_metrics_with_trainer BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS share_meals_with_trainer BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS share_nutrition_with_nutritionist BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.profiles.share_metrics_with_trainer IS
  'Client allows assigned trainer to view health/activity metrics (metrics_daily).';
COMMENT ON COLUMN public.profiles.share_meals_with_trainer IS
  'Client allows assigned trainer to view meal logs.';
COMMENT ON COLUMN public.profiles.share_nutrition_with_nutritionist IS
  'Client allows assigned nutritionist to view meal logs.';

-- ---------------------------------------------------------------------------
-- 2) Coach notes: coaches must be able to read notes they wrote
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Coaches can view notes for accepted clients" ON public.coach_notes;
CREATE POLICY "Coaches can view notes for accepted clients"
  ON public.coach_notes FOR SELECT
  USING (
    auth.uid() = coach_id
    AND EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.client_id = coach_notes.client_id
        AND l.provider_id = auth.uid()
        AND l.status = 'accepted'
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Metrics + meals: coach read via accepted lead + client sharing flags
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Coaches can view client metrics" ON public.metrics_daily;
CREATE POLICY "Coaches can view client metrics"
  ON public.metrics_daily FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.leads l
      JOIN public.profiles p ON p.id = l.client_id
      WHERE l.provider_id = auth.uid()
        AND l.client_id = metrics_daily.user_id
        AND l.status = 'accepted'
        AND l.provider_type = 'trainer'
        AND COALESCE(p.share_metrics_with_trainer, true) = true
    )
  );

DROP POLICY IF EXISTS "Coaches can view client meals" ON public.meals;
CREATE POLICY "Coaches can view client meals"
  ON public.meals FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.leads l
      JOIN public.profiles p ON p.id = l.client_id
      WHERE l.provider_id = auth.uid()
        AND l.client_id = meals.user_id
        AND l.status = 'accepted'
        AND (
          (l.provider_type = 'trainer' AND COALESCE(p.share_meals_with_trainer, true) = true)
          OR (l.provider_type = 'nutritionist' AND COALESCE(p.share_nutrition_with_nutritionist, true) = true)
        )
    )
  );

DROP POLICY IF EXISTS "Coaches can view client meal items" ON public.meal_items;
CREATE POLICY "Coaches can view client meal items"
  ON public.meal_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.meals m
      JOIN public.leads l ON l.client_id = m.user_id AND l.provider_id = auth.uid() AND l.status = 'accepted'
      JOIN public.profiles p ON p.id = l.client_id
      WHERE m.id = meal_items.meal_id
        AND (
          (l.provider_type = 'trainer' AND COALESCE(p.share_meals_with_trainer, true) = true)
          OR (l.provider_type = 'nutritionist' AND COALESCE(p.share_nutrition_with_nutritionist, true) = true)
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 4) Helper RPC: coach/nutritionist access status for a client
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.coach_client_access_status(p_client_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id uuid;
  v_lead record;
BEGIN
  v_provider_id := auth.uid();
  IF v_provider_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  SELECT l.id, l.status, l.provider_type, l.client_id, l.provider_id
  INTO v_lead
  FROM public.leads l
  WHERE l.client_id = p_client_id
    AND l.provider_id = v_provider_id
    AND l.status = 'accepted'
  ORDER BY l.created_at DESC
  LIMIT 1;

  IF v_lead IS NULL THEN
    RETURN jsonb_build_object(
      'has_accepted_lead', false,
      'lead_id', null,
      'provider_type', null,
      'share_metrics_with_trainer', false,
      'share_meals_with_trainer', false,
      'share_nutrition_with_nutritionist', false
    );
  END IF;

  RETURN jsonb_build_object(
    'has_accepted_lead', true,
    'lead_id', v_lead.id,
    'provider_type', v_lead.provider_type::text,
    'share_metrics_with_trainer', COALESCE((
      SELECT p.share_metrics_with_trainer FROM public.profiles p WHERE p.id = p_client_id
    ), true),
    'share_meals_with_trainer', COALESCE((
      SELECT p.share_meals_with_trainer FROM public.profiles p WHERE p.id = p_client_id
    ), true),
    'share_nutrition_with_nutritionist', COALESCE((
      SELECT p.share_nutrition_with_nutritionist FROM public.profiles p WHERE p.id = p_client_id
    ), true)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.coach_client_access_status(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.coach_client_access_status(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5) Allow clients to update sharing prefs on own profile
-- ---------------------------------------------------------------------------
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

  p_updates := p_updates - 'role' - 'email' - 'id';

  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = v_uid) INTO v_exists;

  IF NOT v_exists THEN
    BEGIN
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
      WHEN unique_violation THEN NULL;
    END;
  END IF;

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
    share_metrics_with_trainer = CASE
      WHEN p_updates ? 'share_metrics_with_trainer'
      THEN (p_updates->>'share_metrics_with_trainer')::boolean
      ELSE share_metrics_with_trainer
    END,
    share_meals_with_trainer = CASE
      WHEN p_updates ? 'share_meals_with_trainer'
      THEN (p_updates->>'share_meals_with_trainer')::boolean
      ELSE share_meals_with_trainer
    END,
    share_nutrition_with_nutritionist = CASE
      WHEN p_updates ? 'share_nutrition_with_nutritionist'
      THEN (p_updates->>'share_nutrition_with_nutritionist')::boolean
      ELSE share_nutrition_with_nutritionist
    END,
    updated_at = NOW()
  WHERE id = v_uid;

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
END;
$$;

REVOKE ALL ON FUNCTION public.update_my_profile(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_my_profile(jsonb) TO authenticated;
