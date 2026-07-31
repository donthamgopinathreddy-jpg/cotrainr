-- Allow any subscription plan (free / basic / premium) to submit provider reviews.
-- Still requires an accepted lead connection.

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

REVOKE ALL ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) TO authenticated;
