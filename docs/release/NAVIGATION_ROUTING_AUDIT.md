# Cotrainr Area 03 — Navigation / Routing Audit

Status: CODE AUDIT COMPLETE / LOCAL DEVICE VERIFICATION REQUIRED
Branch: security/pre-release-hardening
Platform: Android first

Scope: GoRouter route graph, auth redirects, Home shell/tab behavior, deep links, OAuth/recovery callbacks, dynamic route parameters, route fallback behavior, predictive/system back, duplicate navigation, transitions and Android intent filters.

## PASS — architecture

- `GoRouter` starts at `/splash`; Splash owns first auth decision.
- `refreshListenable: goRouterAuthRefresh` re-evaluates protected routes on auth/session changes.
- Logged-out users are redirected away from protected routes.
- Logged-in users entering public login/signup routes are sent through `/auth/continue` rather than blindly to `/home`.
- Reset-password route is explicitly exempted from normal auth redirects so recovery links can complete.
- Post-auth resolution routes remain reachable only in the states that need them.
- Google Meet OAuth callback paths are normalized to `/video?...` so custom-scheme completion cannot become an unmatched Flutter page.
- Non-UUID `/video/session/:id` values are rejected back to `/video`.
- Legacy video create/join/room routes normalize to the current Video Sessions page.
- Disabled Quest/AI Planner routes fail closed to Home while source code/data remain retained.
- Home shell validates tab index before applying it; invalid `?tab=` values fall back to Home.
- Home uses an `IndexedStack` and lazy page cache, so primary tab state is preserved while switching tabs.
- Android MainActivity uses `singleTask`, which is correct for callback/deep-link delivery into an existing task.
- Flutter automatic deep-link routing is disabled because `app_links` owns custom-scheme callbacks; this avoids duplicate competing routers.
- Android manifest contains explicit filters for hydration, invite, Google Meet OAuth, auth callback and reset-password.

## FIXED BY ME — duplicate deep-link delivery

File: `lib/widgets/app_link_handler.dart`
Commit: `43cae9b9accc41cafa9cfd69521463006da7d2b7`

Problem:
- `getInitialLink()` and `uriLinkStream` can deliver the same URI during cold start/resume.
- `_handleUri` had no idempotency/deduplication, so the same auth/OAuth/invite navigation could fire twice.

Fix:
- Remember the last handled exact URI and timestamp.
- Ignore an identical URI delivered again within 2 seconds.
- Legitimate later deliveries remain accepted.

Acceptance:
- one Google OAuth callback => one route transition;
- one auth callback => one post-auth continuation;
- one reset link => one recovery flow;
- repeated intentional link later still works.

## MAJOR — direct-entry metric routes fabricate authoritative-looking zero data

File: `lib/router/app_router.dart`
Routes:
- `/insights/steps`
- `/insights/water`
- `/insights/calories`
- `/insights/distance`
- `/bmi`

Confirmed behavior:
- when `state.extra` is missing, Insights routes construct seven zero values; Steps also defaults goal to 10,000 and Water to 2.5.
- `/bmi` constructs `BmiDetailsArgs(bmi: 0, bmiStatus: '')` when no extra exists.

Impact:
- a restored route, malformed internal navigation, deep link or future notification can display zero as if it were real user data.
- violates the permanent UI/data-truthfulness rule: unknown/unavailable must not become authoritative zero.

CURSOR / LOCAL ACTION REQUIRED:
Choose one safe behavior per route:
1. preferred: detail screen loads its authoritative data from repository/provider using current user/date; or
2. if that architecture is not ready, redirect missing/invalid `extra` to `/home` and show no fabricated metric detail.

Do NOT preserve fake zero fallback.

Acceptance:
- direct `adb shell am start ... /insights/steps` equivalent cannot render fake zero history;
- internal Home tap still opens real details;
- unavailable data shows unavailable/error, not zero.

## MAJOR — dynamic IDs are not validated consistently

Video session IDs are validated, but these routes accept arbitrary strings:
- `/providers/:providerId`
- `/providers/:providerId/review`
- `/clients/:id`
- `/nutritionist/clients/:id`
- `/messaging/chat/:conversationId`
- `/events/:eventId`

Risk:
- malformed deep links can push detail screens into repository/RPC calls with invalid identifiers;
- error handling becomes inconsistent and can result in empty/broken-looking pages instead of an explicit invalid-link recovery state.

CURSOR / LOCAL ACTION REQUIRED:
- Add shared UUID validation helper for routes whose DB keys are UUIDs.
- Confirm `eventId` actual key format before applying UUID rule; do not assume if events use a different identifier.
- Invalid parameter => branded invalid-link/not-found page or safe parent route, never a fake detail screen.
- Keep route validation independent of RLS; authorization remains backend-enforced.

Acceptance:
- malformed provider/client/chat URLs recover cleanly without RPC spam/crash;
- valid IDs continue unchanged;
- unauthorized valid IDs still fail safely through backend policy.

## MAJOR — no explicit branded router error surface

`GoRouter` currently has no app-specific `errorBuilder` / `errorPageBuilder` / exception recovery page.

Impact:
- unmatched or malformed routes can expose framework/default error UI instead of a Cotrainr recovery surface.

CURSOR / LOCAL ACTION REQUIRED:
- Add one lightweight branded route-error page.
- Copy: `We couldn't open this page.`
- Primary action: `Go to Home`.
- Secondary action: Back only when router can pop.
- Use theme-aware surfaces and normal responsive/accessibility rules.
- Do not display raw exception/route internals to production users.

Acceptance:
- navigate to an unknown route; no framework-looking error page;
- Home recovery works logged in;
- logged-out protected/unmatched flow resolves safely to Welcome as appropriate.

## MINOR / RELEASE CONFIG — GoRouter diagnostics always enabled

Confirmed:
`debugLogDiagnostics: true`

Required:
- Set to `kDebugMode` (requires Flutter foundation import) or `false` for release.
- Do not emit detailed navigation diagnostics unconditionally in production.

This is a small change but lives in the large router file; apply together with the router fixes above.

## HOME SHELL / PRIMARY TABS

### PASS
- 5 stable tab indices: Home / Discover-or-My Clients / Messages / Meals / Profile.
- invalid initial index is rejected.
- revisiting a tab preserves its cached widget/state.
- programmatic Home shortcuts use `_goToTab` without pushing duplicate route pages.
- role changes clear cached tab pages so provider/client UI is rebuilt correctly.

### OPEN UI/navigation accessibility
Previously recorded in Core UI audit:
- bottom navigation uses icon-only `GestureDetector` controls;
- labels exist in `NavigationItem` but are not rendered/exposed through Semantics;
- selected state and unread status are not announced to TalkBack.

CURSOR / LOCAL ACTION REQUIRED:
- Semantics button with `label`, `selected`, `enabled` and unread hint where applicable;
- 48dp target + pressed feedback;
- keep current no-text visual design if desired; semantic label is mandatory.

### Back behavior
Recommended Android behavior for the root Home shell:
- switching tabs should NOT create a back-stack entry per tab;
- system Back from a root tab should exit/background the app rather than cycling through prior tabs.

Current local `_goToTab` architecture matches that product behavior. Verify predictive back on Android 14+ physically.

## AUTH / ONBOARDING NAVIGATION

### PASS
- auth callbacks use `/auth/continue` rather than `/home`.
- incomplete-profile guard uses authoritative post-auth destination logic.
- logout/session invalidation causes GoRouter refresh.

### OPEN — signup predictive/system back while submission is in flight
Already recorded in Core UI 01.03:
- `SignupWizardPage` must block system/predictive back while `_isSubmitting` or `_showAllSet`.
- normal wizard step-back must still work before submission.

This remains CURSOR / LOCAL ACTION REQUIRED until implemented and device-tested.

## DEEP LINKS / ANDROID

### PASS in code/manifest
- custom schemes are explicitly scoped.
- Google Meet callback path matches AppLinkHandler.
- auth callback and reset-password filters exist.
- invite custom scheme and HTTPS app-link filter exist.
- hydration deep link exists.

### LOCAL / EXTERNAL VERIFICATION REQUIRED — HTTPS App Link
Manifest declares:
`https://www.cotrainr.com/invite?...` with `android:autoVerify="true"`.

Release sign-off requires verifying the live domain serves:
`https://www.cotrainr.com/.well-known/assetlinks.json`
with the production package `com.cotrainr.app` and the SHA-256 fingerprint of the actual Play/upload/app-signing certificate as appropriate.

The repository alone cannot prove the live association file is deployed correctly.

Device acceptance:
- `adb shell pm get-app-links com.cotrainr.app`
- HTTPS invite opens Cotrainr directly after verification rather than browser chooser.
- wrong/unverified domain does not hijack unrelated links.

## OAuth callback lifecycle

LOCAL VERIFY:
- cold app -> Google OAuth -> callback -> Video Sessions exactly once;
- warm app/background -> callback exactly once;
- OAuth error parameter appears as recoverable Video Sessions state;
- system Back after callback returns to correct previous/root behavior;
- no black frame/unknown route.

## Password recovery

LOCAL VERIFY:
- cold-start recovery link;
- warm-app recovery link;
- expired/invalid recovery URL;
- session establishment timeout;
- recovery does not get redirected to Home before password reset completes.

## Invite links

LOCAL VERIFY:
- logged-out custom-scheme invite -> signup with referral code;
- logged-out HTTPS verified app link -> same;
- logged-in invite stores pending referral safely without kicking user into signup;
- malformed/missing code does not crash or create empty referral.

## Transition consistency

PASS at router layer:
- standard pages use shared `Motion.standardPageTransition` through `_fadeSlidePage`.
- auth transition is consistently defined.

LOCAL VERIFY:
- Android predictive-back animation does not conflict with custom transitions;
- reduced-motion behavior remains acceptable. Shared content fades were fixed previously, but route transition helpers themselves do not currently branch on `MediaQuery.disableAnimationsOf(context)` because the transition builder receives route context. If device testing shows excessive motion with Android Remove Animations enabled, consolidate route transitions around an accessibility-aware helper.

## Standalone duplicates vs shell destinations

Routes `/messaging` and `/meal-tracker` coexist with the corresponding Home-shell tabs. This is acceptable for deep-link/detail entry only if callers intentionally choose between:
- root tab: `/home?tab=2` Messages, `/home?tab=3` Meals;
- standalone full-page route when a back stack is intended.

CURSOR audit requirement:
- search callers for `/messaging` and `/meal-tracker`.
- primary navigation must not push a second copy of a root tab on top of Home.
- convert accidental root navigation to `_goToTab` or `/home?tab=N` as appropriate.

## Area 03 verdict

CODE ARCHITECTURE: STRONG / MOSTLY PASS
FIXED BY ME: duplicate deep-link delivery
OPEN BEFORE 100%:
1. remove fabricated zero fallback for Insights/BMI direct entry;
2. dynamic-id validation + safe invalid-link recovery;
3. branded router error page;
4. disable GoRouter diagnostics in release;
5. Signup submission predictive-back guard;
6. Home nav semantics from Area 01;
7. verify standalone route callers do not duplicate root tabs;
8. physical Android predictive-back/deep-link/OAuth/recovery tests;
9. live HTTPS App Link assetlinks verification.

Area 03 must remain below 100% until Cursor/local implementation and physical Android deep-link/back verification pass.