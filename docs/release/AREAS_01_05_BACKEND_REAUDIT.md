# Areas 01-05 Backend Re-Audit

Branch: `security/pre-release-hardening`
Production truth: live Supabase `nvtozwtuyhwqkqvftpyi`
Scope: reopen Areas 1-5 and trace UI -> routing/state -> service/RPC -> RLS/storage -> live data rules.

## Area 1 — Core UI / screens
Backend recheck completed for the primary app shell dependencies already used by Home/Profile/Discover/Auth.

PASS / VERIFIED:
- Authenticated reads for current profile are routed through `get_my_profile()` and server-side `auth.uid()`.
- Home health/meal persistence is covered by the later Areas 8-9 live RLS fixes; failed writes can no longer target another user's rows.
- Provider verification state is server-authoritative and does not default to trainer on lookup failure.

OPEN / CURSOR-LOCAL from existing UI audit remains unchanged:
- Home refresh isolation, goals failure handling, duplicate health initialization, hero interactions, responsive/accessibility/device verification.

## Area 2 — Light / Dark theme
No Supabase authorization or persistence dependency is required for the current theme implementation. Theme correctness remains a Flutter/UI concern.

PASS — backend not applicable.

Still requires the existing complete light/dark visual/device audit. Do not invent a server dependency for theme state unless product later requires cross-device theme sync.

## Area 3 — Navigation / routing
MAJOR — authenticated route guard is incomplete.

Confirmed in `lib/router/app_router.dart`:
- global redirect checks only whether `Supabase.auth.currentSession` exists for protected routes;
- `/auth/continue` uses the authoritative `PostAuthDestination.resolve()` path, but that resolver is not re-run for every protected deep link;
- therefore an authenticated user whose onboarding is incomplete, or whose account is restricted, can deep-link directly to `/home`, `/messaging`, `/meal-tracker`, `/centres`, etc. instead of being forced through the onboarding/restriction gate.

Backend RLS still limits data access, but navigation is materially inconsistent with the server account/onboarding state.

CURSOR / LOCAL ACTION REQUIRED:
1. Add a cached async account-gate state that is refreshed on sign-in, token refresh, profile/onboarding completion, moderation status change and app resume as appropriate.
2. Global router redirect must use that resolved state for protected routes:
   - unauthenticated -> `/welcome`
   - incomplete -> `/auth/complete-profile`
   - restricted -> `/account-restricted`
   - provider not verified -> `/verification`
   - fully eligible -> protected route allowed
3. While gate state is unresolved, route through `/auth/continue` rather than assuming Home access.
4. Preserve password recovery and Google OAuth callback exceptions.
5. Do not perform uncontrolled network calls directly inside every synchronous GoRouter redirect; use a refreshable cached gate/controller.

Acceptance:
- incomplete authenticated account cannot deep-link to Home/Messages/Meals/Discover;
- suspended/banned account cannot deep-link to protected routes;
- unverified trainer/nutritionist is redirected to verification;
- verified/complete account can deep-link normally;
- OAuth/password recovery still work;
- predictive back has no redirect loop.

## Area 4 — Authentication / onboarding
Live backend authority inspected:
- `complete_cotrainr_profile` checks `auth.uid()`, active account status, valid role, completeness, required DOB/gender/height/weight/goals/specialty, current legal versions and freezes username/role on continuation.
- `update_my_profile` strips `role`, `email`, `id`, account-status and moderation-controlled fields and requires active account.
- `get_onboarding_state` is server-derived and checks profile completeness, legal acceptance and provider specialties.
- `record_legal_acceptance` verifies current legal versions and current authenticated user.
- inspected auth-sensitive functions do not use `user_metadata` for authorization.
- private auth/profile RPCs inspected are not executable by `anon` except intentional pre-auth username availability.

Auth data snapshot at audit time:
- 15 Auth users / 15 profiles;
- 14 email identities and 1 Google identity observed;
- no invalid stored profile role observed;
- one profile is missing DOB and is correctly expected to remain incomplete under server onboarding state.

IMPORTANT CONFIG / IMPLEMENTATION GATES:
- repository search found no phone `signInWithOtp` / `verifyOTP` implementation. Phone OTP is therefore NOT currently implemented in Flutter.
- Google OAuth code exists. Apple and Microsoft buttons/code must still be tested against actual Supabase Auth provider configuration; SQL identity counts do not prove provider enablement/disablement.
- Supabase leaked-password protection remains a manual Auth configuration warning from the security advisor.

Verification submission backend fix applied live in this re-audit:
- removed generic active-account INSERT policy that could OR around ownership;
- verification submission now requires current user ownership, active account, pending status and provider type matching authoritative profile role.

Verification document storage fix applied live:
- removed generic storage INSERT/UPDATE policies that bypassed folder ownership;
- verification uploads/updates now require the current user's folder plus active account;
- verification-docs bucket remains private with 10 MiB limit and image MIME allow-list.

## Area 5 — Discover / public profiles
Discover RPCs inspected:
- `discover_providers` filters to `verified=true` and `discoverable=true`;
- `nearby_providers` also filters verified/discoverable providers and hides exact geography for private home locations;
- `get_public_provider_profile` requires authentication and applies discoverability/relationship/request visibility rules.

BLOCKERS FIXED BY ME in live Supabase:
1. `provider_locations` permissive active-account write policies could allow cross-user insert/update/delete. Replaced with owner + active-account policies.
2. `provider_certifications` had the same permissive write bypass. Replaced with owner + active-account policies; insert remains limited to unverified/pending status and existing trigger prevents self-verification.
3. `verification_submissions` generic active-account insert could bypass owner/pending constraints. Removed and replaced with authoritative owner/role-matching policy.
4. `providers` raw SELECT exposed all provider rows to any authenticated user, including unverified/non-discoverable rows. Replaced with own row OR verified+discoverable OR current requested/accepted relationship visibility.
5. `providers` insert/update allowed provider type independent of profile role. New policies require trainer profile -> trainer provider type or nutritionist profile -> nutritionist provider type.

Existing `protect_providers_verified` trigger was verified live and continues preventing users from self-setting `providers.verified`.

## Live migrations created
- `20260908231648_pre_release_harden_provider_profile_and_verification_rls`
- `20260908231811_pre_release_harden_storage_object_ownership`

Git mirrors:
- `supabase/migrations/20260908231648_pre_release_harden_provider_profile_and_verification_rls.sql`
- `supabase/migrations/20260908231811_pre_release_harden_storage_object_ownership.sql`

Verification queries after migration:
- broad provider/location/certification/verification write policies: 0
- broad provider raw SELECT policy: 0
- generic storage write policies that bypass ownership: 0
- verification upload owner+active policy: present
- avatar upload owner+active policy: present

## Revised Areas 1-5 verdict
Area 1: backend dependencies checked; UI/local issues remain.
Area 2: backend N/A; visual/theme audit remains.
Area 3: MAJOR route-gate issue remains Cursor/local.
Area 4: server onboarding/auth authority substantially sound after verification/storage fixes; phone OTP absent; OAuth provider config/device testing remains.
Area 5: live provider/discover RLS and provider authority materially hardened; UI refresh/error/responsive tasks from earlier audit remain.

Do not mark Areas 1-5 fully release-ready until the Area 3 protected-route gate and remaining local UI/device/Auth-provider checks are completed.
