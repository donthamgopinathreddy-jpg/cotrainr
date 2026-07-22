-- Verification pipeline diagnostics
-- Compare Retool workflow status vs Discover source of truth.
--
-- Source of truth for Discover: providers.verified + providers.discoverable
-- Workflow state for Retool:     verification_submissions.status

-- 1) Drift: approved in Retool but not discoverable
SELECT
  vs.id AS submission_id,
  vs.user_id,
  pr.full_name,
  au.email,
  vs.provider_type::text,
  vs.status AS submission_status,
  vs.reviewed_at,
  vs.reviewer_id,
  p.verified AS providers_verified,
  p.discoverable AS providers_discoverable,
  CASE
    WHEN p.user_id IS NULL THEN 'missing_providers_row'
    WHEN p.verified IS NOT TRUE THEN 'providers_verified_false'
    WHEN p.discoverable IS NOT TRUE THEN 'providers_discoverable_false'
    ELSE 'in_sync'
  END AS drift_reason
FROM public.verification_submissions vs
LEFT JOIN public.providers p ON p.user_id = vs.user_id
LEFT JOIN public.profiles pr ON pr.id = vs.user_id
LEFT JOIN auth.users au ON au.id = vs.user_id
WHERE vs.status = 'approved'
ORDER BY vs.reviewed_at DESC NULLS LAST;

-- 2) Single trainer dump (replace UUID)
-- SELECT
--   'verification_submissions' AS src,
--   vs.id::text,
--   vs.status,
--   vs.provider_type::text,
--   vs.reviewed_at::text,
--   vs.reviewer_id::text
-- FROM public.verification_submissions vs
-- WHERE vs.user_id = '<TRAINER_USER_ID>'::uuid
-- UNION ALL
-- SELECT
--   'providers',
--   p.user_id::text,
--   CASE WHEN p.verified THEN 'verified=true' ELSE 'verified=false' END,
--   p.provider_type::text,
--   CASE WHEN p.discoverable THEN 'discoverable=true' ELSE 'discoverable=false' END,
--   NULL
-- FROM public.providers p
-- WHERE p.user_id = '<TRAINER_USER_ID>'::uuid
-- UNION ALL
-- SELECT
--   'profiles',
--   pr.id::text,
--   pr.role,
--   pr.full_name,
--   NULL,
--   NULL
-- FROM public.profiles pr
-- WHERE pr.id = '<TRAINER_USER_ID>'::uuid;

-- 3) Recent approve audit entries
SELECT
  created_at,
  action,
  actor_id,
  target_id AS submission_id,
  details
FROM public.admin_audit_log
WHERE action = 'approve_verification'
ORDER BY created_at DESC
LIMIT 20;

-- 4) Manual repair for one trainer (if needed after inspecting drift)
-- SELECT set_config('app.allow_verified_update', 'true', true);
-- UPDATE public.providers
-- SET verified = true, discoverable = true
-- WHERE user_id = '<TRAINER_USER_ID>'::uuid;
-- SELECT set_config('app.allow_verified_update', '', true);
