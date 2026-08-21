-- Public profile RPCs omitted cover_url, so trainer/nutritionist public
-- headers never received the image stored on profiles.cover_url.

DROP FUNCTION IF EXISTS public.get_public_profile(uuid);
CREATE FUNCTION public.get_public_profile(p_user_id uuid)
RETURNS TABLE(
  id uuid,
  username text,
  full_name text,
  avatar_url text,
  role text,
  followers_count integer,
  following_count integer,
  bio text,
  cover_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  RETURN QUERY
    SELECT
      p.id,
      p.username,
      p.full_name,
      p.avatar_url,
      p.role::text,
      p.followers_count,
      p.following_count,
      p.bio,
      p.cover_url
    FROM public.profiles p
    WHERE p.id = p_user_id;
END $$;

REVOKE ALL ON FUNCTION public.get_public_profile(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid) TO authenticated;
ALTER FUNCTION public.get_public_profile(uuid) OWNER TO postgres;

DROP FUNCTION IF EXISTS public.get_public_profiles(uuid[]);
CREATE FUNCTION public.get_public_profiles(p_user_ids uuid[])
RETURNS TABLE(
  id uuid,
  username text,
  full_name text,
  avatar_url text,
  role text,
  followers_count integer,
  following_count integer,
  bio text,
  cover_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  ids uuid[];
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL OR array_length(p_user_ids, 1) = 0 THEN RETURN; END IF;
  ids := p_user_ids[1:LEAST(array_length(p_user_ids, 1), 200)];
  RETURN QUERY
    SELECT
      p.id,
      p.username,
      p.full_name,
      p.avatar_url,
      p.role::text,
      p.followers_count,
      p.following_count,
      p.bio,
      p.cover_url
    FROM public.profiles p
    WHERE p.id = ANY(ids);
END $$;

REVOKE ALL ON FUNCTION public.get_public_profiles(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(uuid[]) TO authenticated;
ALTER FUNCTION public.get_public_profiles(uuid[]) OWNER TO postgres;

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
    'cover_url', (SELECT pr.cover_url FROM public.profiles pr WHERE pr.id = p_user_id),
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
