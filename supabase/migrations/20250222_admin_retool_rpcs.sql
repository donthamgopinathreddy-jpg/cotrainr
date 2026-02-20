-- =========================================
-- ADMIN RETOOL RPCs (Supabase REST-only mode)
-- =========================================
-- RPCs for Providers, Leads, Subscriptions, App Insights, Settings, comp_until
-- All service_role only. Idempotent.
-- =========================================

-- 1) admin_list_providers
CREATE OR REPLACE FUNCTION public.admin_list_providers()
RETURNS TABLE (
  user_id UUID,
  provider_type TEXT,
  verified BOOLEAN,
  specialization TEXT[],
  experience_years INTEGER,
  hourly_rate NUMERIC,
  created_at TIMESTAMPTZ,
  full_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pr.user_id,
    pr.provider_type::TEXT,
    pr.verified,
    pr.specialization,
    pr.experience_years,
    pr.hourly_rate,
    pr.created_at,
    p.full_name
  FROM public.providers pr
  LEFT JOIN public.profiles p ON p.id = pr.user_id
  ORDER BY pr.created_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_providers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_providers() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_providers() TO service_role;
ALTER FUNCTION public.admin_list_providers() OWNER TO postgres;

-- 2) admin_list_leads
CREATE OR REPLACE FUNCTION public.admin_list_leads(
  p_status TEXT DEFAULT NULL,
  p_provider_type TEXT DEFAULT NULL,
  p_date_from TIMESTAMPTZ DEFAULT NULL,
  p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  client_id UUID,
  provider_id UUID,
  provider_type TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  client_name TEXT,
  provider_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id,
    l.client_id,
    l.provider_id,
    l.provider_type::TEXT,
    l.status::TEXT,
    l.created_at,
    pc.full_name AS client_name,
    pp.full_name AS provider_name
  FROM public.leads l
  LEFT JOIN public.profiles pc ON pc.id = l.client_id
  LEFT JOIN public.profiles pp ON pp.id = l.provider_id
  WHERE 1=1
    AND (p_status IS NULL OR l.status::TEXT = p_status)
    AND (p_provider_type IS NULL OR l.provider_type::TEXT = p_provider_type)
    AND (p_date_from IS NULL OR l.created_at >= p_date_from)
    AND (p_date_to IS NULL OR l.created_at <= p_date_to)
  ORDER BY l.created_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_leads(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_leads(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_leads(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;
ALTER FUNCTION public.admin_list_leads(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO postgres;

-- 3) admin_list_subscriptions
CREATE OR REPLACE FUNCTION public.admin_list_subscriptions()
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  role TEXT,
  plan TEXT,
  status TEXT,
  provider TEXT,
  current_period_end TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  comp_until TIMESTAMPTZ,
  effective_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.user_id,
    p.full_name,
    p.role::TEXT,
    COALESCE(s.plan::TEXT, 'free') AS plan,
    COALESCE(s.status::TEXT, 'inactive') AS status,
    COALESCE(s.provider::TEXT, 'manual') AS provider,
    s.current_period_end,
    s.expires_at,
    s.comp_until,
    GREATEST(
      COALESCE(s.current_period_end, s.expires_at, '1970-01-01'::timestamptz),
      COALESCE(s.comp_until, '1970-01-01'::timestamptz)
    ) AS effective_until,
    s.updated_at
  FROM public.subscriptions s
  LEFT JOIN public.profiles p ON p.id = s.user_id
  ORDER BY s.updated_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_subscriptions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_subscriptions() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_subscriptions() TO service_role;
ALTER FUNCTION public.admin_list_subscriptions() OWNER TO postgres;

-- 4) admin_app_insights
CREATE OR REPLACE FUNCTION public.admin_app_insights(p_days INTEGER DEFAULT 7)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_interval INTERVAL;
BEGIN
  v_interval := (p_days || ' days')::INTERVAL;
  RETURN jsonb_build_object(
    'total_users', (SELECT COUNT(*) FROM public.profiles),
    'total_clients', (SELECT COUNT(*) FROM public.profiles WHERE role = 'client'),
    'total_trainers', (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'trainer'),
    'total_nutritionists', (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'nutritionist'),
    'verified_trainers', (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'trainer' AND verified),
    'verified_nutritionists', (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'nutritionist' AND verified),
    'pending_verifications_count', (SELECT COUNT(*) FROM public.verification_submissions WHERE status = 'pending'),
    'leads_requested_count', (SELECT COUNT(*) FROM public.leads WHERE status::TEXT = 'requested' AND created_at >= NOW() - v_interval),
    'accepted_leads_count', (SELECT COUNT(*) FROM public.leads WHERE status::TEXT = 'accepted' AND created_at >= NOW() - v_interval),
    'subscriptions_active_basic_count', (SELECT COUNT(*) FROM public.subscriptions WHERE plan::TEXT = 'basic' AND status::TEXT IN ('active','trialing')),
    'subscriptions_active_premium_count', (SELECT COUNT(*) FROM public.subscriptions WHERE plan::TEXT = 'premium' AND status::TEXT IN ('active','trialing')),
    'subscriptions_trialing_count', (SELECT COUNT(*) FROM public.subscriptions WHERE status::TEXT = 'trialing'),
    'subscriptions_past_due_count', (SELECT COUNT(*) FROM public.subscriptions WHERE status::TEXT = 'past_due')
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_app_insights(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_app_insights(INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_app_insights(INTEGER) TO service_role;
ALTER FUNCTION public.admin_app_insights(INTEGER) OWNER TO postgres;

-- 5) admin_get_app_settings
CREATE OR REPLACE FUNCTION public.admin_get_app_settings()
RETURNS TABLE (key TEXT, value TEXT, updated_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT a.key, a.value, a.updated_at FROM public.app_settings a;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_app_settings() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_app_settings() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_app_settings() TO service_role;
ALTER FUNCTION public.admin_get_app_settings() OWNER TO postgres;

-- 5b) admin_update_app_setting (for Settings screen)
CREATE OR REPLACE FUNCTION public.admin_update_app_setting(p_key TEXT, p_value TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.app_settings (key, value, updated_at)
  VALUES (p_key, p_value, NOW())
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_setting(TEXT, TEXT) TO service_role;
ALTER FUNCTION public.admin_update_app_setting(TEXT, TEXT) OWNER TO postgres;

-- 6) admin_grant_comp
CREATE OR REPLACE FUNCTION public.admin_grant_comp(p_user_id UUID, p_comp_until TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id, comp_until, updated_at)
  VALUES (p_user_id, p_comp_until, NOW())
  ON CONFLICT (user_id) DO UPDATE SET comp_until = EXCLUDED.comp_until, updated_at = NOW();
  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

-- Note: subscriptions has user_id UNIQUE (or PK). ON CONFLICT (user_id) works.

REVOKE ALL ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) TO service_role;
ALTER FUNCTION public.admin_grant_comp(UUID, TIMESTAMPTZ) OWNER TO postgres;

-- 7) admin_remove_comp
CREATE OR REPLACE FUNCTION public.admin_remove_comp(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.subscriptions SET comp_until = NULL, updated_at = NOW() WHERE user_id = p_user_id;
  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_remove_comp(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_remove_comp(UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_comp(UUID) TO service_role;
ALTER FUNCTION public.admin_remove_comp(UUID) OWNER TO postgres;
