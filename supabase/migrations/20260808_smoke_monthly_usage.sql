-- SMOKE TEST: run this alone in a NEW blank Supabase SQL query.
-- If this works, run the full 20260808_monthly_connection_request_quotas.sql next.

CREATE TABLE IF NOT EXISTS public.monthly_usage (user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, month_start date NOT NULL, requests_used integer NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, month_start), CONSTRAINT monthly_usage_requests_used_nonneg CHECK (requests_used >= 0));
