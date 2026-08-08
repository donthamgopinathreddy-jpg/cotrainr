-- Enrich lead_request notification payload only.
-- Preserves monthly quota create_lead_tx behaviour from 20260808_monthly_connection_request_quotas.sql.

CREATE OR REPLACE FUNCTION public.create_lead_tx(p_provider_id uuid, p_message text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
v_client_id uuid;
v_client_role text;
v_client_name text;
v_provider_type text;
v_plan text;
v_month_start date;
v_requests_used int;
v_requests_limit int;
v_requests_unlimited boolean;
v_nutritionist_allowed boolean;
v_new_lead_id uuid;
v_already_counted boolean;
v_remaining int;
BEGIN
v_client_id := auth.uid();
IF v_client_id IS NULL THEN
RETURN jsonb_build_object('error', 'Unauthorized');
END IF;

SELECT role INTO v_client_role FROM public.profiles WHERE id = v_client_id;
IF v_client_role IS DISTINCT FROM 'client' THEN
RETURN jsonb_build_object('error', 'Only clients can create leads');
END IF;

SELECT provider_type::text INTO v_provider_type FROM public.providers WHERE user_id = p_provider_id;
IF v_provider_type IS NULL THEN
RETURN jsonb_build_object('error', 'Provider not found');
END IF;

IF EXISTS (
SELECT 1 FROM public.leads
WHERE client_id = v_client_id
AND provider_id = p_provider_id
AND status IN ('requested', 'accepted')
) THEN
RETURN jsonb_build_object('error', 'Lead already exists');
END IF;

SELECT coalesce((SELECT plan FROM public.subscriptions WHERE user_id = v_client_id LIMIT 1), 'free') INTO v_plan;
v_month_start := date_trunc('month', now())::date;

CASE v_plan
WHEN 'free' THEN
v_requests_limit := 5;
v_requests_unlimited := false;
v_nutritionist_allowed := false;
WHEN 'basic' THEN
v_requests_limit := 15;
v_requests_unlimited := false;
v_nutritionist_allowed := true;
WHEN 'premium' THEN
v_requests_limit := NULL;
v_requests_unlimited := true;
v_nutritionist_allowed := true;
ELSE
v_requests_limit := 5;
v_requests_unlimited := false;
v_nutritionist_allowed := false;
END CASE;

IF v_provider_type = 'nutritionist' AND NOT v_nutritionist_allowed THEN
RETURN jsonb_build_object('error', 'Nutritionist requests require Basic or Premium plan');
END IF;

INSERT INTO public.monthly_usage (user_id, month_start, requests_used)
VALUES (v_client_id, v_month_start, 0)
ON CONFLICT (user_id, month_start) DO NOTHING;

SELECT requests_used INTO v_requests_used
FROM public.monthly_usage
WHERE user_id = v_client_id AND month_start = v_month_start
FOR UPDATE;

v_already_counted := EXISTS (
SELECT 1 FROM public.monthly_provider_requests
WHERE user_id = v_client_id AND provider_id = p_provider_id AND month_start = v_month_start
);

IF NOT v_already_counted AND NOT v_requests_unlimited AND v_requests_used >= v_requests_limit THEN
RETURN jsonb_build_object('error', 'Request limit reached', 'remaining', 0, 'limit', v_requests_limit, 'month_start', v_month_start);
END IF;

BEGIN
INSERT INTO public.leads (client_id, provider_id, provider_type, status, message)
VALUES (v_client_id, p_provider_id, v_provider_type::public.provider_type, 'requested', p_message)
RETURNING id INTO v_new_lead_id;
EXCEPTION WHEN unique_violation THEN
RETURN jsonb_build_object('error', 'Lead already exists');
END;

IF NOT v_already_counted THEN
BEGIN
INSERT INTO public.monthly_provider_requests (user_id, provider_id, month_start, first_lead_id)
VALUES (v_client_id, p_provider_id, v_month_start, v_new_lead_id);

UPDATE public.monthly_usage
SET requests_used = requests_used + 1
WHERE user_id = v_client_id AND month_start = v_month_start;

SELECT coalesce(full_name, username, 'A client') INTO v_client_name
FROM public.profiles WHERE id = v_client_id;

INSERT INTO public.notifications (user_id, type, title, body, data)
VALUES (
p_provider_id,
'lead_request',
'New connection request',
coalesce(v_client_name, 'A client') || ' wants to connect with you',
jsonb_build_object(
'lead_id', v_new_lead_id,
'client_id', v_client_id,
'provider_id', p_provider_id,
'provider_type', v_provider_type,
'actor_id', v_client_id,
'action', 'open_pending_requests'
)
);
EXCEPTION WHEN unique_violation THEN
NULL;
END;
END IF;

SELECT requests_used INTO v_requests_used
FROM public.monthly_usage
WHERE user_id = v_client_id AND month_start = v_month_start;

IF v_requests_unlimited THEN
v_remaining := NULL;
ELSE
v_remaining := GREATEST(0, v_requests_limit - coalesce(v_requests_used, 0));
END IF;

RETURN jsonb_build_object(
'lead_id', v_new_lead_id,
'status', 'requested',
'remaining', v_remaining,
'limit', v_requests_limit,
'unlimited', v_requests_unlimited,
'month_start', v_month_start,
'unique_provider_counted', NOT v_already_counted
);
END;
$fn$;

ALTER FUNCTION public.create_lead_tx(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_lead_tx(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_lead_tx(uuid, text) TO authenticated;
