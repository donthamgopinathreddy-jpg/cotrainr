-- Diagnostic queries for Discover trainer visibility.
-- Run in Supabase SQL editor as a privileged role (service_role / dashboard).
-- Uses actual schema: providers, provider_locations, profiles, verification_submissions.

-- A) Totals by discoverability gates
SELECT
  COUNT(*) FILTER (WHERE provider_type = 'trainer') AS trainers_total,
  COUNT(*) FILTER (WHERE provider_type = 'trainer' AND verified) AS trainers_verified,
  COUNT(*) FILTER (
    WHERE provider_type = 'trainer' AND verified AND discoverable
  ) AS trainers_verified_discoverable,
  COUNT(*) FILTER (
    WHERE provider_type = 'trainer'
      AND verified
      AND discoverable
      AND EXISTS (
        SELECT 1
        FROM public.provider_locations pl
        WHERE pl.provider_id = providers.user_id
          AND pl.is_active
          AND pl.geo IS NOT NULL
      )
  ) AS trainers_with_active_geo
FROM public.providers;

-- B) Per-trainer exclusion + submission status (Retool vs Discover)
SELECT
  p.user_id,
  pr.full_name,
  p.provider_type::text AS role,
  p.verified,
  p.discoverable,
  (
    SELECT vs.status
    FROM public.verification_submissions vs
    WHERE vs.user_id = p.user_id
    ORDER BY vs.submitted_at DESC
    LIMIT 1
  ) AS latest_submission_status,
  EXISTS (
    SELECT 1
    FROM public.provider_locations pl
    WHERE pl.provider_id = p.user_id
      AND pl.is_active
      AND pl.geo IS NOT NULL
  ) AS has_coordinates,
  CASE
    WHEN p.provider_type <> 'trainer' THEN 'not_trainer'
    WHEN p.verified IS NOT TRUE THEN 'not_verified'
    WHEN p.discoverable IS NOT TRUE THEN 'not_discoverable'
    WHEN NOT EXISTS (
      SELECT 1 FROM public.profiles pr2 WHERE pr2.id = p.user_id
    ) THEN 'missing_profile'
    ELSE 'eligible'
  END AS exclusion_reason
FROM public.providers p
LEFT JOIN public.profiles pr ON pr.id = p.user_id
WHERE p.provider_type = 'trainer'
ORDER BY exclusion_reason, pr.full_name;

-- C) Drift: Retool approved but Discover still blocked
SELECT
  vs.user_id,
  pr.full_name,
  vs.status AS submission_status,
  p.verified,
  p.discoverable
FROM public.verification_submissions vs
LEFT JOIN public.providers p ON p.user_id = vs.user_id
LEFT JOIN public.profiles pr ON pr.id = vs.user_id
WHERE vs.status = 'approved'
  AND (p.user_id IS NULL OR p.verified IS NOT TRUE OR p.discoverable IS NOT TRUE);

