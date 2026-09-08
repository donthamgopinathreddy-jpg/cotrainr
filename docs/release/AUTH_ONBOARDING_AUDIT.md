# Cotrainr Authentication / Onboarding Release Audit

Status: IN PROGRESS — CODE AUDIT COMPLETE, LOCAL/DASHBOARD ITEMS OPEN
Branch: security/pre-release-hardening
Area: 04 Authentication / onboarding
Target: 100%

## Scope
Email/password login, OAuth login, email signup, social signup completion, forgot/reset password, referral entry, username availability, legal acceptance, post-auth routing, permissions, complete-profile recovery, account restriction, session/logout behavior, provider verification gating, phone OTP scope, responsive/accessibility states.

## PASS — implemented and structurally sound
- Email/password sign-in uses Supabase `signInWithPassword`, 15s timeout, duplicate-submit guard, slow-network hint, mapped errors, keyboard submit and authoritative `/auth/continue` routing.
- Google, Apple and Microsoft/Azure OAuth buttons are wired through `signInWithOAuth` with `cotrainr://auth-callback`.
- OAuth/new-user completion is supported by social-mode signup wizard and `complete_cotrainr_profile` rather than trusting user-editable JWT metadata for final authorization.
- Forgot password uses generic success copy (`If an account exists...`) to avoid account enumeration.
- Password reset deep link waits for a recovery session and signs out after password update so the recovery session is not reused as a normal signed-in session.
- Username availability fails closed on RPC/network failure and does not treat an unknown response as available.
- Email signup requires at least 8 chars plus uppercase, lowercase, number and special character in the client wizard.
- Legal version values are recorded and `record_legal_acceptance` is required after authenticated email signup; social completion passes legal versions through the completion RPC.
- Post-auth continuation is bounded by timeout and has explicit Retry rather than hanging indefinitely.
- Previously hardened complete-profile and restricted-account flows remain in place.
- Previously hardened permissions page no longer allows an early null-force crash while permission statuses are still being checked.

## BLOCKER — signup predictive/system Back is unsafe during final submission
File: `lib/pages/auth/signup_wizard_page.dart`

Confirmed current code:
- `_back()` has no `_isSubmitting` / `_showAllSet` guard.
- `PopScope.canPop` is only `_step == 0`.
- `onPopInvokedWithResult` calls `_back()` whenever Flutter did not pop.

Impact:
- system/predictive Back can change wizard step or leave the route while final account creation / legal acceptance / goals/referral/provider setup is still in flight;
- All Set can also receive Back as if it were an editable wizard step.

CURSOR / LOCAL ACTION REQUIRED:
1. Begin `_back()` with `if (_isSubmitting || _showAllSet) return;`.
2. Set `canPop: !_isSubmitting && !_showAllSet && _step == 0`.
3. In `onPopInvokedWithResult`, do not call `_back()` while `_isSubmitting || _showAllSet`.
4. Preserve normal single-step Back for steps 1–6 before submission.
5. Preserve route Back from step 0 when idle.
6. Do not change signup backend behavior.

Acceptance:
- predictive/system Back during Finish does nothing;
- Back during All Set does nothing until Continue;
- steps 1–6 go exactly one step backward;
- step 0 returns to previous auth screen;
- no duplicate signup/RPC/referral operations;
- `dart format` + `flutter analyze` + Android predictive-Back test.

## MAJOR — password reset app-bar fallback route is wrong
File: `lib/pages/auth/reset_password_page.dart`

Confirmed:
- `CotrainrAppBar(fallbackRoute: '/login')`
- router login path is `/auth/login`.

Required:
- change fallback to `/auth/login`;
- while `_loading` is true, prevent Back from abandoning the password mutation or otherwise guarantee the update cannot produce ambiguous navigation;
- add tooltips/semantics for password visibility icon buttons if shared component does not already supply them.

Acceptance:
- open reset screen as a direct/deep-link entry with no back stack and press Back/app-bar Back: user lands on `/auth/login`, never an unmatched route;
- while Update password is in flight, repeated Back/tap cannot submit/navigate twice.

## MAJOR — phone OTP is NOT implemented
Repo search found no release auth flow using phone `signInWithOtp` + `verifyOTP` / SMS OTP.

Current implemented auth methods:
- email/password;
- Google OAuth;
- Apple OAuth;
- Microsoft/Azure OAuth;
- email password reset.

Product decision required before release:
- If phone OTP is part of Android MVP, implement it and test new/existing user, invalid/expired OTP, resend/rate limit, country code, offline/timeout, post-auth completion, account restriction and duplicate account/identity behavior.
- If phone OTP is not required for v1 Android launch, explicitly remove it from the release checklist/marketing and track it as post-launch scope.

Do not mark auth 100% while the release checklist still claims phone OTP exists.

## MAJOR — leaked-password protection is disabled in live Supabase Auth
Live security advisor on 2026-09-08 reports `auth_leaked_password_protection` disabled.

Supabase current guidance recommends leaked-password rejection as part of password security. This is a hosted Auth configuration item, not a database migration.

MANUAL DASHBOARD ACTION REQUIRED:
- Supabase Dashboard -> Authentication -> Providers/Email password security -> enable leaked password protection if the current project plan supports it.
- Re-run security advisor and verify the warning is gone.
- If unavailable on the current plan, record that constraint and retain the app-side/server minimum password-strength policy.

Do not change this through SQL.

## MAJOR — password policy is inconsistent between login and signup/reset
Files:
- `login_page.dart`: password validator only rejects `<6` chars before trying sign-in.
- `signup_wizard_page.dart`: requires >=8 + upper/lower/number/special.
- `reset_password_page.dart`: currently only checks >=8 characters client-side.

Interpretation:
- Login should generally accept any historical password allowed by the server, so the loose login validator is acceptable and should not block existing users.
- New password creation/reset should align with the server Auth password policy.

Required:
- verify live Supabase Auth minimum length/required-character configuration;
- align signup and reset-password UI guidance/validation with the server policy;
- do not enforce a stricter reset rule than the server without deliberate product decision;
- surface Supabase WeakPassword errors clearly.

## MAJOR — email-confirmation branch needs physical verification
Email signup tries immediate `signInWithPassword` when `signUp` returns no session. If email confirmation is enabled, this should fall through to `Account created! Please check your email to confirm.` and `/auth/login`.

Physical/live test required:
- new email signup with confirmation enabled;
- confirmation link cold start and warm app;
- confirmation link after app process death;
- already-confirmed/expired link;
- duplicate-email signup response does not reveal whether the account exists;
- successful confirmation routes through `/auth/continue`, not blind `/home`.

## MAJOR — OAuth provider configuration must be verified live
Flutter buttons alone do not prove provider readiness.

Manual/live checks:
- Google provider enabled and redirect allow-list contains `cotrainr://auth-callback`;
- Apple provider credentials/configuration valid for the eventual iOS launch even though Android is first;
- Azure/Microsoft provider enabled with correct callback/tenant configuration;
- cancelled OAuth returns app to usable login state;
- provider error does not strand `_isLoading`;
- same-email OAuth identity linking behavior matches intended account model.

Supabase documentation notes automatic linking may link OAuth identities with the same verified email. Test this deliberately with an existing email/password account.

## PASS WITH LOCAL VERIFY — forgot password privacy and UX
File: `lib/widgets/auth/forgot_password_sheet.dart`

Good:
- validates email format locally;
- disables duplicate submission;
- generic success wording avoids account enumeration;
- error mapping does not expose whether the address exists;
- keyboard-aware constrained/scrollable dialog.

Local checks:
- barrier dismiss while request is active should not cause confusing duplicate requests when reopened;
- reduced motion should be applied to dialog state transition;
- narrow phone + large font + keyboard open.

## PASS WITH LOCAL VERIFY — post-auth resolver
File: `lib/pages/auth/post_auth_continue_page.dart`

Good:
- session missing -> Welcome;
- bounded resolver timeout;
- explicit error + Retry;
- refuses resolver self-loop `/auth/continue`;
- routes through authoritative destination.

Test:
- client complete -> Home;
- provider incomplete/verification-required -> expected verification destination;
- incomplete profile -> Complete Profile;
- restricted/suspended/deleted account -> restricted handling;
- offline and recovered network;
- token refresh/session expiration while page is open.

## ROLE / AUTHORITY RULE
Never authorize client/provider/admin capability from `user_metadata`. Role/verification/entitlement decisions must come from server-authoritative profile/provider/subscription data or trusted app metadata/RPCs. Existing signup comments correctly state role is set by trusted server flow; preserve that rule.

## 10-state auth requirement
Each auth screen must deliberately cover applicable:
1. default
2. loading/action in flight
3. retry/recovery
4. empty validation
5. error
6. success
7. disabled
8. partial/degraded
9. offline/slow
10. interrupted/back/deep-link lifecycle

Also verify keyboard, autofill, password manager, large text, light/dark, reduced motion, 320dp width, TalkBack, duplicate taps, predictive Back and process death.

## Android E2E authentication matrix before sign-off
- email login success/wrong password/nonexistent/generic error/offline/timeout;
- email signup new/duplicate/weak password/username conflict/legal unchecked;
- social signup Google new + existing;
- Microsoft new + existing;
- Apple where supported/configured;
- OAuth cancel/error/cold-start callback;
- password-reset request, expired link, valid link, update failure/success;
- logout then protected deep link;
- stale/expired access token + refresh token;
- incomplete onboarding recovery;
- restricted/deleted/suspended account;
- provider verification route;
- phone OTP only if retained in v1 scope.

## Current Area 04 verdict
NOT 100% READY.

Code foundation is strong, but release closure requires:
1. signup Back blocker fixed;
2. reset fallback route fixed + in-flight Back behavior checked;
3. explicit product decision/implementation for phone OTP;
4. live OAuth/email-confirmation configuration tests;
5. leaked-password protection dashboard decision/action;
6. password-policy alignment with live Auth config;
7. physical Android E2E matrix.

No database DDL was changed during this audit.