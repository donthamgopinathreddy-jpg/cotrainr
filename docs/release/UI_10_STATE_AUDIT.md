# Cotrainr 10-State UI Release Audit

Status: IN PROGRESS
Branch: security/pre-release-hardening
Scope: Every reachable Android release screen and every important async/interactive component.

## Mandatory 10-state rule
Every audited screen/component must classify each state below as PASS, FIXED BY ME, CURSOR / LOCAL ACTION REQUIRED, or NOT APPLICABLE. A screen does not need to visibly render every state when the state cannot occur, but every applicable async/action state must be deliberately handled.

1. Default / normal
2. Loading / initial fetch
3. Refreshing / reloading
4. Empty / no data
5. Error / failed request
6. Retry / recovery
7. Success / completed action
8. Disabled / unavailable action
9. Partial / degraded / cached data
10. Offline / slow / interrupted request

Cross-cutting checks on every applicable screen:
- pressed / selected / focused states
- keyboard open and keyboard dismissal
- duplicate action / double tap prevention
- navigation/back while work is in flight
- stale/cached data handling
- destructive confirmation where applicable
- permission denied/permanently denied where applicable
- small viewport and large text
- light/dark mode
- reduced motion
- TalkBack/semantics and touch targets
- role-specific visibility/access

## Revisit — 01.01 App root + splash + welcome

### State matrix
1. Default / normal — PASS. Splash and Welcome have explicit normal surfaces.
2. Loading / initial fetch — PASS. Splash is the startup/loading surface and keeps the native splash until Flutter paints.
3. Refreshing / reloading — NOT APPLICABLE. There is no user-refreshable data on Splash/Welcome.
4. Empty / no data — NOT APPLICABLE. These are static entry surfaces.
5. Error / failed request — PASS WITH DEGRADED FALLBACK. Startup exceptions fall back to `/welcome`; runner image has a fallback asset.
6. Retry / recovery — PARTIAL / LOCAL VERIFY. Recovery is by continuing to Welcome and retrying auth/navigation from there; there is no explicit startup Retry CTA, which is acceptable because startup failures currently fail open to the unauthenticated entry surface rather than trapping the user.
7. Success / completed action — PASS. Startup exits to pending recovery/video/message route, post-auth resolver, or Welcome.
8. Disabled / unavailable action — PASS. Welcome buttons use `_busy` to prevent duplicate navigation.
9. Partial / degraded / cached data — PASS. Startup tolerates missing/failed secondary state and falls back to Welcome; splash image has asset fallback.
10. Offline / slow / interrupted — PASS / LOCAL VERIFY. Slow startup hint appears after 4 seconds; startup exception fails to Welcome. Physical offline launch remains local verification.

### Remaining verification
- LOCAL: offline cold start, slow Supabase initialization, signed-in cached session, password-recovery deep link, reduced motion, small viewport/large text, light/dark Welcome.

Verdict: CODE PASS. No new release defect found in revisit.

## Revisit — 01.02 Login

### State matrix
1. Default / normal — PASS.
2. Loading / initial fetch — NOT APPLICABLE for screen entry; authentication loading is handled by the Sign In/OAuth busy state.
3. Refreshing / reloading — NOT APPLICABLE.
4. Empty / no data — PASS as form-empty state with validation on submit.
5. Error / failed request — PASS. Auth errors map to inline `_formError`; timeout has an explicit mapped error.
6. Retry / recovery — PASS. Editing clears `_formError`; user can submit again after loading resets.
7. Success / completed action — PASS. Button success state is shown before authoritative `/auth/continue` navigation.
8. Disabled / unavailable action — PASS AFTER FIX. Sign In, OAuth, password visibility, Forgot password, and Sign Up now lock consistently during authentication.
9. Partial / degraded / cached data — NOT APPLICABLE for credentials form.
10. Offline / slow / interrupted — PASS / LOCAL VERIFY. 3-second slow hint, 15-second timeout, loading lock, and error recovery are present. Physical offline/OAuth-cancel behaviour remains local verification.

### Cross-cutting
- keyboard-aware scroll: PASS
- keyboard drag dismissal: PASS
- duplicate submit prevention: PASS
- OAuth icon semantics: PASS AFTER FIX
- password visibility semantics: PASS AFTER FIX
- back navigation during loading: LOCAL VERIFY

Verdict: CODE PASS AFTER FIX. No new code defect found in revisit.

## Revisit — 01.03 Create Account / Signup Wizard

### State matrix
1. Default / normal — PASS across the seven wizard steps.
2. Loading / initial fetch — PASS/PARTIAL. Username availability, legal-version load, social profile prefill and final submission all have asynchronous paths; username checking and final submit are visibly represented, while legal-version/social-prefill loading is intentionally background/resume-safe.
3. Refreshing / reloading — NOT APPLICABLE as a list refresh; username availability re-check is implemented when the value changes or final validation runs.
4. Empty / no data — PASS. Required credential/role/goal states validate and block progression; optional referral/phone are explicitly optional.
5. Error / failed request — PASS/PARTIAL. Username availability fails closed, signup maps errors, conflicts return to step 0, and legal/referral secondary failures are intentionally non-fatal. Some validation is SnackBar-based rather than inline, which is acceptable but requires device visual verification.
6. Retry / recovery — PASS/PARTIAL. Username can be edited/rechecked, conflicts return to the credential step, signup can be retried after `_isSubmitting` resets. Android back race remains open.
7. Success / completed action — PASS at UI level through `OnboardingAllSetView` only after persistence path succeeds.
8. Disabled / unavailable action — PARTIAL / OPEN. Bottom Back/Next/Finish lock during `_isSubmitting`, but Android/system back is not locked during submit or All Set.
9. Partial / degraded / cached data — PASS. Social onboarding hydrates existing profile values; optional referral/goals initialization failures do not invalidate a created account; existing values are preserved on resume.
10. Offline / slow / interrupted — PASS/PARTIAL. 3-second slow hint, RPC/auth timeouts and mapped errors exist. Interrupted system-back state is the open MAJOR defect.

### OPEN — CURSOR / LOCAL ACTION REQUIRED
The previously recorded MAJOR remains valid:
- `_back()` must immediately return when `_isSubmitting || _showAllSet`.
- `PopScope` must not pop or step backward while submitting or after success.
- Predictive/system back must be verified on Android.

Additional local verification from 10-state revisit:
- username availability RPC offline/error then edit/retry
- signup timeout then retry without duplicate account creation
- email-conflict and username-taken return-to-step-0 visual state
- SnackBar visibility with keyboard open
- social prefill partial-profile state
- All Set cannot be re-entered twice by rapid CTA tap/navigation

Verdict: OPEN because the system-back interaction defect is still unresolved locally.

## Revisit — 01.04 Permissions + onboarding success

### State matrix
1. Default / normal — PASS.
2. Loading / initial fetch — PASS AFTER FIX. `_isChecking` now represents the initial permission-status scan and locks actions.
3. Refreshing / reloading — PARTIAL / CURSOR-LOCAL VERIFY. Returning from device Settings does not visibly show a dedicated refresh state; verify whether lifecycle/resume causes permission statuses to refresh. If it does not, add a resume-triggered `_checkPermissions()` without prompting.
4. Empty / no data — NOT APPLICABLE; permission rows are static configuration.
5. Error / failed request — PARTIAL. Health request/check exceptions degrade to denied and can open settings. Other platform permission/status calls need physical-device verification for thrown platform exceptions.
6. Retry / recovery — PASS/PARTIAL. Permanently denied state offers Open Settings; denied permissions can be requested again. Status refresh after returning from Settings must be verified locally.
7. Success / completed action — PASS. Granted rows show success visual state and onboarding navigates to the role destination.
8. Disabled / unavailable action — PASS AFTER FIX for checking/requesting states. Product-policy contradiction remains for Health Required vs Skip.
9. Partial / degraded / cached data — OPEN POLICY DECISION. The app health layer can degrade when Health is unavailable, but Permissions UI currently labels Health as Required while Skip bypasses enforcement.
10. Offline / slow / interrupted — PARTIAL. Permission operations are local OS flows rather than network flows; interrupted/background/resume behaviour must be tested on device. Notification token registration is unawaited after permission grant and should be covered later under Notifications/backend wiring.

### OPEN — CURSOR / LOCAL ACTION REQUIRED
1. Resolve Health Required vs Skip contradiction exactly as recorded in FULL_RELEASE_AUDIT.md.
2. Verify lifecycle refresh after returning from App Settings / Health Connect. If statuses do not refresh automatically, add `WidgetsBindingObserver` (or equivalent lifecycle handling) and invoke `_checkPermissions()` on resume without re-prompting.
3. Verify Android 13+ photos/files permission strategy. `Permission.storage` may not represent modern photo-picker access and must match the actual picker implementation and manifest declarations.
4. Exercise thrown/denied/permanently-denied platform cases and ensure `_isRequesting` never remains stuck indefinitely after an exception.

### Onboarding All Set
- normal: PASS
- loading: NOT APPLICABLE; shown only after persistence success
- error/retry: NOT APPLICABLE inside this success-only view
- success: PASS
- disabled/duplicate CTA: LOCAL VERIFY. Rapid double tap should not create a duplicate navigation stack or re-enter onboarding.
- reduced motion: PASS in code

Verdict: CODE PASS AFTER EXISTING FIX, but policy and lifecycle/device verification remain OPEN.

## Audit rule going forward
Every subsequent Core UI screen and every later release category must include this 10-state classification. A screen cannot be marked complete merely because its happy path looks correct.
