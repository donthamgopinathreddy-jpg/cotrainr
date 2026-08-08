-- Manual / CI SQL diagnostics for monthly connection quotas.
-- Run in Supabase SQL editor after applying
-- 20260808_monthly_connection_request_quotas.sql
--
-- Cases covered (product rules E–N): free/basic limits, ultimate unlimited,
-- calendar-month reset, unique provider re-request, nutritionist plan gate.
-- Replace :client_id / :provider_* with real UUIDs when exercising live.

-- Schema sanity
SELECT to_regclass('public.monthly_usage') AS monthly_usage,
       to_regclass('public.monthly_provider_requests') AS monthly_provider_requests;

SELECT proname, pg_get_function_identity_arguments(oid)
FROM pg_proc
WHERE proname = 'create_lead_tx';

-- Current month boundary used by create_lead_tx
SELECT date_trunc('month', now())::date AS month_start;

-- Inspect own usage (as authenticated client)
-- SELECT * FROM public.monthly_usage WHERE user_id = auth.uid();
-- SELECT * FROM public.monthly_provider_requests WHERE user_id = auth.uid();

/*
Expected RPC error strings (create_lead_tx):
  - Unauthorized
  - Only clients can create leads
  - Provider not found
  - Lead already exists
  - Nutritionist requests require Basic or Premium plan
  - Request limit reached

Expected success shape:
  { lead_id, status: requested, remaining, limit, unlimited, month_start,
    unique_provider_counted }

E Free: 5 unique providers succeed; 6th distinct provider → Request limit reached
F Basic: 15 succeed; 16th fails
G Ultimate (plan=premium): unlimited=true; no quota rejection
H New calendar month: new month_start row; allowance resets
I Accepted leads untouched across month boundary
J Conversations remain; messaging independent of monthly_usage
L Free + nutritionist provider → Nutritionist requests require Basic or Premium plan
M Double-tap same provider while requested → Lead already exists (no second quota)
N Cancel/decline then re-request same provider same month → unique_provider_counted=false
   (no second monthly_usage increment; no second lead_request notification)
*/
