-- Ensure provider reviews RPCs + public provider profile RPC exist.
-- Fixes: PGRST202 submit_provider_review missing; public profile unavailable
-- when direct providers SELECT fails (RLS / schema drift).

-- =============================================================================
-- 0. Professional columns (must exist before profile RPC)
-- =============================================================================
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS professional_headline TEXT;
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS session_modes TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS languages TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS accepting_new_clients BOOLEAN NOT NULL DEFAULT true;

DROP POLICY IF EXISTS "Anyone can view providers" ON public.providers;
CREATE POLICY "Anyone can view providers"
  ON public.providers FOR SELECT
  TO authenticated
  USING (true);

-- =============================================================================
-- 1. provider_reviews table + aggregates
-- =============================================================================
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

DROP POLICY IF EXISTS "Clients can read own reviews" ON public.provider_reviews;
CREATE POLICY "Clients can read own reviews"
  ON public.provider_reviews FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

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
  v_provider_type TEXT;
  v_lead_ok BOOLEAN;
BEGIN
  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rating must be between 1 and 5');
  END IF;

  -- Any plan may review; only require an accepted connection.
  SELECT p.provider_type::TEXT
  INTO v_provider_type
  FROM public.providers p
  WHERE p.user_id = p_provider_id;

  IF v_provider_type IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Provider not found');
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

REVOKE ALL ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.list_provider_reviews(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_provider_reviews(UUID, INT) TO authenticated;

-- =============================================================================
-- 2. Public provider profile RPC (includes signup specialization + profile fields)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_public_provider_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row RECORD;
  v_loc RECORD;
  v_allowed BOOLEAN := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT
    p.user_id,
    p.provider_type::TEXT AS provider_type,
    p.professional_headline,
    p.specialization,
    p.experience_years,
    p.hourly_rate,
    COALESCE(p.session_modes, '{}'::TEXT[]) AS session_modes,
    COALESCE(p.languages, '{}'::TEXT[]) AS languages,
    COALESCE(p.accepting_new_clients, true) AS accepting_new_clients,
    COALESCE(p.verified, false) AS verified,
    COALESCE(p.discoverable, true) AS discoverable,
    COALESCE(p.rating, 0) AS rating,
    COALESCE(p.total_reviews, 0) AS total_reviews
  INTO v_row
  FROM public.providers p
  WHERE p.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_uid = p_user_id OR COALESCE(v_row.discoverable, true) THEN
    v_allowed := true;
  ELSIF EXISTS (
    SELECT 1 FROM public.leads l
    WHERE l.status = 'accepted'
      AND (
        (l.client_id = v_uid AND l.provider_id = p_user_id)
        OR (l.provider_id = v_uid AND l.client_id = p_user_id)
      )
  ) THEN
    v_allowed := true;
  ELSIF EXISTS (
    SELECT 1 FROM public.leads l
    WHERE l.status = 'requested'
      AND l.client_id = v_uid
      AND l.provider_id = p_user_id
  ) THEN
    v_allowed := true;
  END IF;

  IF NOT v_allowed THEN
    RETURN NULL;
  END IF;

  SELECT pl.display_name, pl.radius_km
  INTO v_loc
  FROM public.provider_locations pl
  WHERE pl.provider_id = p_user_id
    AND pl.is_active = true
  ORDER BY pl.is_primary DESC NULLS LAST
  LIMIT 1;

  RETURN jsonb_build_object(
    'user_id', v_row.user_id,
    'provider_type', v_row.provider_type,
    'professional_headline', v_row.professional_headline,
    'specialization', to_jsonb(v_row.specialization),
    'experience_years', v_row.experience_years,
    'hourly_rate', v_row.hourly_rate,
    'session_modes', to_jsonb(v_row.session_modes),
    'languages', to_jsonb(v_row.languages),
    'accepting_new_clients', v_row.accepting_new_clients,
    'verified', v_row.verified,
    'discoverable', v_row.discoverable,
    'rating', v_row.rating,
    'total_reviews', v_row.total_reviews,
    'full_name', (SELECT pr.full_name FROM public.profiles pr WHERE pr.id = p_user_id),
    'avatar_url', (SELECT pr.avatar_url FROM public.profiles pr WHERE pr.id = p_user_id),
    'bio', (SELECT pr.bio FROM public.profiles pr WHERE pr.id = p_user_id),
    'username', (SELECT pr.username FROM public.profiles pr WHERE pr.id = p_user_id),
    'primary_location_label', NULLIF(TRIM(COALESCE(v_loc.display_name, '')), ''),
    'coverage_km', v_loc.radius_km
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_public_provider_profile(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_provider_profile(UUID) TO authenticated;
ALTER FUNCTION public.get_public_provider_profile(UUID) OWNER TO postgres;
