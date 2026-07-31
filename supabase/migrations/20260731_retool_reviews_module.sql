-- Retool Reviews & Ratings module + Flutter provider review alignment.
-- Creates public.reviews (Retool shape) and moderation RPCs.
-- Migrates existing provider_reviews rows, then keeps Flutter RPCs on reviews.

-- =============================================================================
-- 1. Canonical reviews table (Retool-required shape)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  status TEXT NOT NULL DEFAULT 'visible'
    CHECK (status IN ('visible', 'hidden', 'flagged', 'deleted')),
  admin_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (client_id, provider_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_provider_status_created
  ON public.reviews (provider_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reviews_status
  ON public.reviews (status);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read visible reviews" ON public.reviews;
CREATE POLICY "Authenticated can read visible reviews"
  ON public.reviews FOR SELECT
  TO authenticated
  USING (status = 'visible');

DROP POLICY IF EXISTS "Clients can read own reviews" ON public.reviews;
CREATE POLICY "Clients can read own reviews"
  ON public.reviews FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

-- No direct client INSERT/UPDATE/DELETE — writes via SECURITY DEFINER RPCs only.

-- =============================================================================
-- 2. Migrate from provider_reviews if present
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.provider_reviews') IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM information_schema.tables
       WHERE table_schema = 'public'
         AND table_name = 'provider_reviews'
         AND table_type = 'BASE TABLE'
     ) THEN
    INSERT INTO public.reviews (
      id, provider_id, client_id, rating, review_text, status, created_at, updated_at
    )
    SELECT
      pr.id,
      pr.provider_id,
      pr.client_id,
      pr.rating,
      pr.body,
      CASE WHEN COALESCE(pr.is_hidden, false) THEN 'hidden' ELSE 'visible' END,
      pr.created_at,
      pr.updated_at
    FROM public.provider_reviews pr
    ON CONFLICT (client_id, provider_id) DO UPDATE
      SET rating = EXCLUDED.rating,
          review_text = EXCLUDED.review_text,
          status = EXCLUDED.status,
          updated_at = EXCLUDED.updated_at;
  END IF;
END $$;

-- =============================================================================
-- 3. Rating recalculation (Retool name + internal alias)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.recalculate_provider_rating(provider_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_avg NUMERIC;
  v_count INTEGER;
BEGIN
  SELECT COALESCE(AVG(r.rating)::NUMERIC, 0), COUNT(*)::INTEGER
  INTO v_avg, v_count
  FROM public.reviews r
  WHERE r.provider_id = recalculate_provider_rating.provider_id
    AND r.status = 'visible';

  UPDATE public.providers p
  SET rating = ROUND(v_avg, 2),
      total_reviews = v_count,
      updated_at = NOW()
  WHERE p.user_id = recalculate_provider_rating.provider_id;
END;
$$;

-- Keep older internal name as wrapper
CREATE OR REPLACE FUNCTION public._refresh_provider_rating_stats(p_provider_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.recalculate_provider_rating(p_provider_id);
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_provider_rating(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.recalculate_provider_rating(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.recalculate_provider_rating(UUID) TO authenticated;

-- =============================================================================
-- 4. Moderation RPC (Retool-required)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.moderate_provider_review(
  review_id UUID,
  action TEXT,
  admin_note TEXT DEFAULT NULL,
  actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := actor_id;
  v_action TEXT := lower(trim(COALESCE(action, '')));
  v_provider_id UUID;
  v_new_status TEXT;
  v_row public.reviews%ROWTYPE;
BEGIN
  -- Prefer explicit actor; fall back to JWT uid for service tooling.
  IF v_actor IS NULL THEN
    v_actor := auth.uid();
  END IF;

  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Missing actor_id');
  END IF;

  -- Validate admin actor when helper exists
  IF to_regprocedure('public.admin_validate_actor(uuid)') IS NOT NULL THEN
    IF NOT public.admin_validate_actor(v_actor) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Invalid actor');
    END IF;
  END IF;

  SELECT * INTO v_row FROM public.reviews WHERE id = review_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Review not found');
  END IF;

  v_provider_id := v_row.provider_id;

  v_new_status := CASE v_action
    WHEN 'visible' THEN 'visible'
    WHEN 'unhide' THEN 'visible'
    WHEN 'restore' THEN 'visible'
    WHEN 'hide' THEN 'hidden'
    WHEN 'hidden' THEN 'hidden'
    WHEN 'flag' THEN 'flagged'
    WHEN 'flagged' THEN 'flagged'
    WHEN 'delete' THEN 'deleted'
    WHEN 'deleted' THEN 'deleted'
    ELSE NULL
  END;

  IF v_new_status IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Invalid action. Use visible|hide|flag|delete (or unhide|restore|hidden|flagged|deleted)'
    );
  END IF;

  UPDATE public.reviews r
  SET status = v_new_status,
      admin_note = COALESCE(
        NULLIF(TRIM(moderate_provider_review.admin_note), ''),
        r.admin_note
      ),
      updated_at = NOW()
  WHERE r.id = review_id;

  PERFORM public.recalculate_provider_rating(v_provider_id);

  IF to_regclass('public.admin_audit_log') IS NOT NULL THEN
    INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
    VALUES (
      'moderate_provider_review',
      v_actor,
      'review',
      review_id,
      jsonb_build_object(
        'action', v_action,
        'new_status', v_new_status,
        'provider_id', v_provider_id,
        'admin_note', NULLIF(TRIM(COALESCE(admin_note, '')), '')
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'review_id', review_id,
    'status', v_new_status,
    'provider_id', v_provider_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_provider_review(UUID, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.moderate_provider_review(UUID, TEXT, TEXT, UUID) TO service_role;

-- =============================================================================
-- 5. Flutter client RPCs → write/read public.reviews (any plan + accepted lead)
-- =============================================================================
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

  INSERT INTO public.reviews (client_id, provider_id, rating, review_text, status)
  VALUES (
    v_client_id,
    p_provider_id,
    p_rating,
    NULLIF(TRIM(COALESCE(p_body, '')), ''),
    'visible'
  )
  ON CONFLICT (client_id, provider_id) DO UPDATE
    SET rating = EXCLUDED.rating,
        review_text = EXCLUDED.review_text,
        status = 'visible',
        updated_at = NOW();

  PERFORM public.recalculate_provider_rating(p_provider_id);
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
    r.review_text AS body,
    r.created_at,
    COALESCE(pr.full_name, pr.username, 'Client') AS reviewer_name
  FROM public.reviews r
  LEFT JOIN public.profiles pr ON pr.id = r.client_id
  WHERE r.provider_id = p_provider_id
    AND r.status = 'visible'
  ORDER BY r.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
END;
$$;

REVOKE ALL ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_provider_review(UUID, SMALLINT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.list_provider_reviews(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_provider_reviews(UUID, INT) TO authenticated;

-- Legacy admin hide/delete wrappers → moderate_provider_review
CREATE OR REPLACE FUNCTION public.admin_hide_provider_review(p_review_id UUID, p_actor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.moderate_provider_review(p_review_id, 'hide', NULL, p_actor_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_provider_review(p_review_id UUID, p_actor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.moderate_provider_review(p_review_id, 'delete', NULL, p_actor_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_hide_provider_review(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_hide_provider_review(UUID, UUID) TO service_role;
REVOKE ALL ON FUNCTION public.admin_delete_provider_review(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_provider_review(UUID, UUID) TO service_role;

-- =============================================================================
-- 6. Compatibility view: provider_reviews → reviews (Flutter direct SELECT)
-- =============================================================================
-- If a base table still exists, rename it aside once, then expose the view.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'provider_reviews'
      AND table_type = 'BASE TABLE'
  ) THEN
    ALTER TABLE public.provider_reviews RENAME TO provider_reviews_legacy;
  END IF;
EXCEPTION
  WHEN duplicate_table THEN NULL;
  WHEN undefined_table THEN NULL;
END $$;

DROP VIEW IF EXISTS public.provider_reviews;
CREATE VIEW public.provider_reviews AS
SELECT
  r.id,
  r.client_id,
  r.provider_id,
  r.rating,
  r.review_text AS body,
  (r.status <> 'visible') AS is_hidden,
  r.created_at,
  r.updated_at
FROM public.reviews r
WHERE r.status <> 'deleted';

GRANT SELECT ON public.provider_reviews TO authenticated;
GRANT SELECT ON public.reviews TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reviews TO service_role;
GRANT ALL ON public.reviews TO service_role;

-- Recalculate all providers that have reviews (one-time heal)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT DISTINCT provider_id FROM public.reviews LOOP
    PERFORM public.recalculate_provider_rating(r.provider_id);
  END LOOP;
END $$;
