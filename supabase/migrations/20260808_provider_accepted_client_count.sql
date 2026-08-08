-- Public accepted-client count for provider profiles.
-- Direct leads SELECT is RLS-limited to participants, so viewers saw 0/—.

CREATE OR REPLACE FUNCTION public.get_provider_accepted_client_count(p_provider_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(*)::integer
  FROM public.leads
  WHERE provider_id = p_provider_id
    AND status = 'accepted';
$$;

ALTER FUNCTION public.get_provider_accepted_client_count(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_provider_accepted_client_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_provider_accepted_client_count(uuid) TO authenticated;
