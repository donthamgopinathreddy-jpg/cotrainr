-- =========================================
-- ADMIN: RPC for users list (no auth.users via PostgREST)
-- SUBSCRIPTIONS: Create if missing, add comp_until
-- APP_SETTINGS: Placeholder table for Settings screen
-- =========================================
-- Idempotent. Service_role only for admin RPCs.
-- =========================================

-- 1) admin_list_users: Returns user list with email (reads auth.users server-side)
-- Retool calls this RPC instead of querying auth.users directly via PostgREST
CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_search_email TEXT DEFAULT NULL,
  p_search_name TEXT DEFAULT NULL,
  p_search_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  role TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ,
  provider_type TEXT,
  verified BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS user_id,
    COALESCE(au.email, '')::TEXT AS email,
    p.role::TEXT AS role,
    p.full_name,
    COALESCE(au.created_at, p.created_at) AS created_at,
    pr.provider_type::TEXT AS provider_type,
    COALESCE(pr.verified, false) AS verified
  FROM public.profiles p
  LEFT JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.providers pr ON pr.user_id = p.id
  WHERE 1=1
    AND (p_search_email IS NULL OR au.email ILIKE '%' || p_search_email || '%')
    AND (p_search_name IS NULL OR p.full_name ILIKE '%' || p_search_name || '%')
    AND (p_search_user_id IS NULL OR p.id = p_search_user_id)
  ORDER BY COALESCE(au.created_at, p.created_at) DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_users(TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_users(TEXT, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(TEXT, TEXT, UUID) TO service_role;
ALTER FUNCTION public.admin_list_users(TEXT, TEXT, UUID) OWNER TO postgres;

COMMENT ON FUNCTION public.admin_list_users(TEXT, TEXT, UUID) IS 'Admin-only: list users with email. Use instead of querying auth.users via PostgREST.';

-- 2) app_settings: Placeholder for Settings screen (support email, terms URL, privacy URL)
CREATE TABLE IF NOT EXISTS public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- No SELECT for authenticated (admin uses service_role). Or allow public read for app config.
DROP POLICY IF EXISTS "Service role can manage app_settings" ON public.app_settings;
CREATE POLICY "Service role can manage app_settings"
  ON public.app_settings FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Seed placeholder keys if empty
INSERT INTO public.app_settings (key, value) VALUES
  ('support_email', ''),
  ('terms_url', ''),
  ('privacy_url', '')
ON CONFLICT (key) DO NOTHING;
