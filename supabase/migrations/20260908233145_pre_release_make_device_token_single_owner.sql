WITH ranked AS (
  SELECT id, row_number() OVER (PARTITION BY token ORDER BY updated_at DESC, created_at DESC, id DESC) rn
  FROM public.device_tokens
)
DELETE FROM public.device_tokens d USING ranked r
WHERE d.id=r.id AND r.rn>1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_device_tokens_token ON public.device_tokens(token);

CREATE OR REPLACE FUNCTION public.claim_device_token_single_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='public','pg_catalog'
AS $$
BEGIN
  IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'invalid_device_token_owner' USING ERRCODE='42501';
  END IF;
  IF NOT public.is_account_active() THEN
    RAISE EXCEPTION 'account_restricted' USING ERRCODE='42501';
  END IF;
  DELETE FROM public.device_tokens
  WHERE token=NEW.token AND user_id<>NEW.user_id;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_device_token_single_owner() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS claim_device_token_single_owner_trg ON public.device_tokens;
CREATE TRIGGER claim_device_token_single_owner_trg
BEFORE INSERT OR UPDATE OF token,user_id ON public.device_tokens
FOR EACH ROW EXECUTE FUNCTION public.claim_device_token_single_owner();
