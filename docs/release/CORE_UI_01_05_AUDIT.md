# 01.05 Post-auth / Complete-profile / Restricted-account UI audit

Status: CODE AUDIT PASS AFTER FIX / LOCAL VISUAL VERIFY
Branch: security/pre-release-hardening

## Scope
- `lib/pages/auth/post_auth_continue_page.dart`
- `lib/pages/auth/complete_profile_page.dart`
- `lib/pages/auth/account_restricted_page.dart`

## 10-state UI audit

### PostAuthContinuePage
1. Normal/default — N/A; this route is a resolver surface.
2. Loading — PASS; fullscreen Cotrainr loader while destination resolves.
3. Refreshing — N/A; explicit retry replaces refresh semantics.
4. Empty — N/A; no collection/data-empty state exists.
5. Error — PASS; timeout and mapped auth errors render through the loader.
6. Retry — PASS; retry clears error/slow state, restarts slow timer and resolves again.
7. Success — PASS; successful resolution navigates to the authoritative destination.
8. Disabled — PASS by design; there are no competing actions while loading.
9. Partial/degraded — PASS; a self-resolving `/auth/continue` result is treated as a recoverable error instead of looping.
10. Offline/slow — PASS; 3-second slow hint plus bounded network timeout.

### CompleteProfilePage
1. Normal/default — PASS; incomplete onboarding renders `SignupWizardPage(mode: social)`.
2. Loading — PASS; fullscreen loader while onboarding state is checked.
3. Refreshing — N/A; explicit retry is the recovery action.
4. Empty — N/A; server onboarding state is boolean/structured rather than a collection.
5. Error — PASS; timeout and mapped failures render explicitly.
6. Retry — PASS; loader retry calls `_check()`.
7. Success — PASS; incomplete users enter the social completion wizard, completed users are routed through the post-auth destination resolver.
8. Disabled — PASS by design; no competing action is exposed during the guard check.
9. Partial/degraded — PASS; completed-user redirect protects against deep-linking back into onboarding.
10. Offline/slow — FIXED; the second `PostAuthDestination.resolve()` call was previously unbounded and could leave the user on a permanent loader. It now uses `PostAuthDestination.networkTimeout`, allowing the existing timeout/error/retry UI to recover.

Code fix commit: `1361812257ebc4dacfb1f70112222f8fe37679ee`.

### AccountRestrictedPage
1. Normal/default — PASS after authoritative profile status has loaded.
2. Loading — FIXED; first load now shows a neutral progress state instead of immediately rendering the default suspended copy before the server answers.
3. Refreshing — PASS; Check again shows `Checking…` and disables competing actions.
4. Empty — N/A; no collection state.
5. Error — FIXED; initial profile/status load failure now renders an explicit connection/status-check error instead of silently falling back to suspended UI.
6. Retry — FIXED; explicit Try again action re-runs the authoritative profile check; Sign out remains available from the error state.
7. Success — PASS; unrestricted accounts route back through `/auth/continue`; restricted accounts render the authoritative restriction copy.
8. Disabled — PASS; checking/deleting disable competing actions and account deletion prevents duplicate submission.
9. Partial/degraded — PASS; moderation notes are intentionally not exposed; only safe public restriction status/title/message is rendered.
10. Offline/slow — PASS after fix; status RPC is bounded to 15 seconds and failures now expose retry rather than misleading restriction content.

Code fix commit: `8bc56ae4abc3631a8b52b659206e918746f78512`.

## Additional interaction checks
- Account deletion has destructive confirmation and a deleting spinner.
- Duplicate delete requests are guarded by `_deleting`/`_busy`.
- Restricted-account refresh and sign-out are disabled while busy.
- Post-auth and complete-profile surfaces never expose a manual route that bypasses the authoritative destination resolver.

## LOCAL VERIFICATION REQUIRED
- Force offline mode on PostAuthContinue and verify slow hint -> error -> retry -> successful route.
- Force CompleteProfile second destination resolution to timeout and verify retry does not hang.
- Restricted account: initial slow network must show neutral loader, not suspended/banned content before server response.
- Restricted account: failed status load must show Try again + Sign out.
- Restricted account: Check again changing from restricted -> active must route through `/auth/continue`.
- Delete account: cancel, success and failure states on a physical Android device.
- Small Android viewport, large text, forced light/dark, TalkBack and Android back navigation.

## Result
No remaining code-level BLOCKER/MAJOR UI-state defect was found within 01.05 after the two fixes above. Device-dependent verification remains open and must not be counted as completed until local testing passes.
