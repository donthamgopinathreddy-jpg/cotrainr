-- Fix: meal/metrics coach RLS joined public.profiles while SELECT on profiles
-- was revoked for authenticated (cocircle RPC-only model). That caused:
--   permission denied for table profiles (42501)
-- on every meals SELECT/INSERT...RETURNING, including the meal tracker.

-- =============================================================================
-- 1. SECURITY DEFINER helpers (bypass profiles table privilege for invoker)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.coach_can_view_client_meals(p_client_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR p_client_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.leads l
    JOIN public.profiles p ON p.id = l.client_id
    WHERE l.provider_id = v_uid
      AND l.client_id = p_client_id
      AND l.status = 'accepted'
      AND (
        (l.provider_type = 'trainer' AND COALESCE(p.share_meals_with_trainer, true) = true)
        OR (l.provider_type = 'nutritionist' AND COALESCE(p.share_nutrition_with_nutritionist, true) = true)
      )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.coach_can_view_client_metrics(p_client_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR p_client_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.leads l
    JOIN public.profiles p ON p.id = l.client_id
    WHERE l.provider_id = v_uid
      AND l.client_id = p_client_id
      AND l.status = 'accepted'
      AND l.provider_type = 'trainer'
      AND COALESCE(p.share_metrics_with_trainer, true) = true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.coach_can_view_client_meals(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.coach_can_view_client_metrics(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.coach_can_view_client_meals(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.coach_can_view_client_metrics(uuid) TO authenticated;
ALTER FUNCTION public.coach_can_view_client_meals(uuid) OWNER TO postgres;
ALTER FUNCTION public.coach_can_view_client_metrics(uuid) OWNER TO postgres;

-- =============================================================================
-- 2. Recreate coach policies without direct profiles JOINs
-- =============================================================================
DROP POLICY IF EXISTS "Coaches can view client meals" ON public.meals;
CREATE POLICY "Coaches can view client meals"
  ON public.meals FOR SELECT
  USING (public.coach_can_view_client_meals(meals.user_id));

DROP POLICY IF EXISTS "Coaches can view client meal items" ON public.meal_items;
CREATE POLICY "Coaches can view client meal items"
  ON public.meal_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.meals m
      WHERE m.id = meal_items.meal_id
        AND public.coach_can_view_client_meals(m.user_id)
    )
  );

DROP POLICY IF EXISTS "Coaches can view client metrics" ON public.metrics_daily;
CREATE POLICY "Coaches can view client metrics"
  ON public.metrics_daily FOR SELECT
  USING (public.coach_can_view_client_metrics(metrics_daily.user_id));
