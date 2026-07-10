-- Provider reviews: client ratings for subscribed/eligible clients.

CREATE TABLE IF NOT EXISTS public.provider_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  body TEXT,
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (client_id, provider_id)
);

CREATE INDEX IF NOT EXISTS idx_provider_reviews_provider_visible
  ON public.provider_reviews (provider_id, created_at DESC)
  WHERE is_hidden = false;

ALTER TABLE public.provider_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read visible reviews" ON public.provider_reviews;
CREATE POLICY "Anyone authenticated can read visible reviews"
  ON public.provider_reviews FOR SELECT
  TO authenticated
  USING (is_hidden = false);

DROP POLICY IF EXISTS "Clients can insert own review via RPC only" ON public.provider_reviews;
-- Inserts via submit_provider_review RPC (security definer). No direct client insert policy.

CREATE OR REPLACE FUNCTION public._refresh_provider_rating_stats(p_provider_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_avg NUMERIC;
  v_count INTEGER;
BEGIN
  SELECT COALESCE(AVG(rating)::NUMERIC, 0), COUNT(*)::INTEGER
  INTO v_avg, v_count
  FROM public.provider_reviews
  WHERE provider_id = p_provider_id AND is_hidden = false;

  UPDATE public.providers
  SET rating = ROUND(v_avg, 2),
      total_reviews = v_count,
      updated_at = NOW()
  WHERE user_id = p_provider_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_provider_review(
  p_provider_id UUID,
  p_rating SMALLINT,
  p_body TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id UUID := auth.uid();
  v_plan TEXT;
  v_provider_type public.provider_type;
  v_lead_ok BOOLEAN;
BEGIN
  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rating must be between 1 and 5');
  END IF;

  SELECT COALESCE(s.plan::TEXT, 'free'), p.provider_type
  INTO v_plan, v_provider_type
  FROM public.providers p
  LEFT JOIN public.subscriptions s ON s.user_id = v_client_id
  WHERE p.user_id = p_provider_id;

  IF v_provider_type IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Provider not found');
  END IF;

  IF v_plan = 'free' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Upgrade to Basic or Unlimited to leave a review');
  END IF;

  IF v_plan = 'basic' AND v_provider_type = 'nutritionist' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Basic plan can only review trainers');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.leads
    WHERE client_id = v_client_id
      AND provider_id = p_provider_id
      AND status = 'accepted'
  ) INTO v_lead_ok;

  IF NOT v_lead_ok THEN
    RETURN jsonb_build_object('ok', false, 'error', 'You can only review a provider you are connected with');
  END IF;

  INSERT INTO public.provider_reviews (client_id, provider_id, rating, body)
  VALUES (v_client_id, p_provider_id, p_rating, NULLIF(TRIM(COALESCE(p_body, '')), ''))
  ON CONFLICT (client_id, provider_id) DO UPDATE
    SET rating = EXCLUDED.rating,
        body = EXCLUDED.body,
        updated_at = NOW(),
        is_hidden = false;

  PERFORM public._refresh_provider_rating_stats(p_provider_id);
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.list_provider_reviews(p_provider_id UUID, p_limit INT DEFAULT 20)
RETURNS TABLE (
  id UUID,
  rating SMALLINT,
  body TEXT,
  created_at TIMESTAMPTZ,
  reviewer_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.rating,
    r.body,
    r.created_at,
    COALESCE(pr.full_name, pr.username, 'Client') AS reviewer_name
  FROM public.provider_reviews r
  LEFT JOIN public.profiles pr ON pr.id = r.client_id
  WHERE r.provider_id = p_provider_id
    AND r.is_hidden = false
  ORDER BY r.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_hide_provider_review(p_review_id UUID, p_actor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id UUID;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  UPDATE public.provider_reviews
  SET is_hidden = true, updated_at = NOW()
  WHERE id = p_review_id
  RETURNING provider_id INTO v_provider_id;

  IF v_provider_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Review not found');
  END IF;

  PERFORM public._refresh_provider_rating_stats(v_provider_id);
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_provider_review(p_review_id UUID, p_actor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id UUID;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
  END IF;

  DELETE FROM public.provider_reviews
  WHERE id = p_review_id
  RETURNING provider_id INTO v_provider_id;

  IF v_provider_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Review not found');
  END IF;

  PERFORM public._refresh_provider_rating_stats(v_provider_id);
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.list_provider_reviews(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_provider_reviews(UUID, INT) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_hide_provider_review(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_hide_provider_review(UUID, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.admin_delete_provider_review(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_provider_review(UUID, UUID) TO service_role;
