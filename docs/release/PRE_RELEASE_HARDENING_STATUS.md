# Cotrainr Android Pre-Release Hardening Status

Canonical audit branch: `security/pre-release-hardening`

## Rules
- Live Supabase is production truth.
- Never replay old historical migrations into production.
- Every production DB fix is recorded as a new forward migration.
- P0/P1 closes only after inspection, fix, verification, and GitHub recording where applicable.
- Product behaviour must not be changed unless required for correctness, privacy, security, or Play compliance.

## Status legend
- OPEN
- FIXED LIVE
- RECORDED IN GITHUB
- VERIFIED
- CLOSED

## Ground-level release audit

| ID | Severity | Area | Status | Notes |
|---|---|---|---|---|
| P0-01 | P0 | Privileged admin/verification RPC execution | CLOSED | anon/authenticated EXECUTE removed; service_role retained; live verified; forward migration recorded. |
| P0-02 | P0 | Partner operational tables exposed without RLS | CLOSED | RLS enabled; anon/authenticated DML revoked; service_role retained; live verified; forward migration recorded. |
| REL-01 | P0 | Android release used debug signing | RECORDED IN GITHUB | Debug signing fallback removed. Release signing now uses uncommitted `android/key.properties`; real upload keystore still must be generated/configured on the release machine before AAB. |
| REL-02 | P0 | Google Play target API | RECORDED IN GITHUB | Android compile/target SDK set to API 36 for current Play submission requirements. Build verification still required locally. |
| REL-03 | P1 | Signing secret hygiene | CLOSED | `.gitignore` protects key.properties/JKS/keystore files; safe template added. |
| REL-04 | P1 | Generic Flutter package metadata | CLOSED | Cotrainr package description recorded; version remains `1.0.0+1` until final release build sequencing. |
| REL-05 | P1 | Production client logging | IN PROGRESS | Unconditional startup/push/health/water diagnostics in `main.dart` are now debug-only (`5caa26a9`). Router diagnostics and backend upstream-response logging are being audited before closure. |
| HEALTH-01 | P0 | Android health-source correctness | CLOSED | Health Connect/Apple Health remains the only movement source; no sensor fallback was added. Android initialization fails closed when Health Connect is unavailable or no movement permission is usable (`90ffbc39`). Metrics sync no longer persists empty snapshots when the source is unavailable and preserves existing positive daily totals when an individual Health Connect read is denied/transiently empty (`11f9b855`). Initialization now remains resolved after denial/unavailability so background sync does not reopen permission prompts every 30 seconds; explicit Connect/reinitialize is the retry path (`24cd5bd3`). Home already renders cached real data or an unavailable dash rather than a fake measured zero. Regression coverage added in `test/utils/health_metric_display_test.dart` (`f0db81fe`). Local/CI test execution remains part of final build verification. |
| HEALTH-02 | P1 | Health Connect least-privilege permissions | CLOSED | Current health service requests READ only; manifest write permissions removed and read permissions retained. Android integration uses `FlutterFragmentActivity`, Health Connect permission-rationale wiring, and package visibility setup. |
| ROUTE-01 | P1 | Legacy Zoom deep-link/router residue | RECORDED IN GITHUB | Android external Zoom callback intent and active Video Sessions UI wiring are removed. A defensive compatibility callback/redirect remains in `AppLinkHandler` / `app_router.dart`; no current Google Meet flow depends on it. Final dead-code cleanup remains pending. |
| DATA-01 | P0 | Fake Insights fallback series | CLOSED | Positive fabricated fallback arrays were removed. Router fallbacks are now explicit zero/no-data series while `InsightsDetailPage` reloads authoritative repository data. GitHub commit `721c249`. |
| AUTH-01 | P0 | Signup/onboarding role authority and provider verification integrity | CLOSED | Self-declared signup role is no longer sufficient for provider authority. Discovery requires `verified=true`; live DB triggers require a verified trainer/nutritionist for accepted leads and every video-session host. No accepted unverified provider links or sessions with unverified hosts exist. `create-video-session` now also fails early on the live Edge runtime unless `providers.verified=true`, before Google Meet creation. |
| AUTH-02 | P1 | Leaked-password protection | OPEN | Live Supabase advisor still reports leaked-password protection disabled. Current connected Supabase actions do not expose the Auth configuration write needed to enable it. |
| PRIV-01 | P0/P1 | In-app account deletion | FIXED LIVE | Live `delete-account` Edge Function v1 is ACTIVE with JWT verification and derives the account solely from the authenticated JWT. It removes user-owned storage prefixes, cleans non-cascading legacy/partner rows, then deletes `auth.users`. Flutter Privacy & Security now exposes permanent deletion (`e34c830d`) and restricted accounts also retain a deletion path (`7a89ab23`). Destructive E2E verification with a disposable account is still required before CLOSED. |
| RPC-01 | P1 | Anonymous SECURITY DEFINER exposure | CLOSED | ACL hardening reduced anonymous SECURITY DEFINER exposure from 29 to 4: 1 intentional pre-auth username availability RPC + 3 PostGIS-owned functions. |
| RPC-02 | P1 | `get_notification_push` arbitrary-user preference read | CLOSED | Live RPC now service_role-only; anon/authenticated EXECUTE removed; verified and forward migration recorded. |
| RPC-03 | P1 | Internal composite relationship helper client exposure | CLOSED | `conversation_has_accepted_lead(conversations)` accepted caller-supplied composite data without caller binding. No client/RLS dependency required this overload. Live migration `20260908210455_pre_release_restrict_internal_connection_helper` revoked PUBLIC/anon/authenticated EXECUTE and retained service_role. Verified live; forward migration recorded. The safer `(uuid, uuid)` overload remains authenticated-callable and binds the pair to `auth.uid()`. |
| RPC-04 | P1 | Authenticated SECURITY DEFINER caller-binding / IDOR review | IN PROGRESS | Current Supabase advisor reports a broad set of authenticated-callable SECURITY DEFINER functions. Many are intentional app RPC APIs; every sensitive parameterized function is being reviewed for `auth.uid()`/participant/role binding before release. |
| VIEW-01 | P0/P1 | `provider_reviews` SECURITY DEFINER view | CLOSED | View now `security_invoker=true`; anon SELECT removed; authenticated/service_role SELECT retained; live verified and migration recorded. |
| DB-01 | P1 | Mutable function search_path warnings | CLOSED | All 28 advisor-reported mutable function search paths were pinned to `public, pg_catalog`; live security advisor no longer reports `function_search_path_mutable`. Forward migration recorded. |
| EDGE-01 | P1 | `create-video-session` early verification gate deployment | CLOSED | Live Supabase Edge Function `create-video-session` version 41 is ACTIVE with JWT verification enabled and checks provider type + `verified=true` before Google Meet creation. |
| EDGE-02 | P1 | Non-JWT Edge Function authorization | VERIFIED BASELINE | `google-oauth-callback` uses one-time OAuth state/expiry/PKCE; `send-push-notification` uses a mandatory webhook secret; `dispatch-video-session-reminders` uses a mandatory cron secret. All fail closed before privileged work. Logging/payload review continues. |
| EDGE-03 | P1 | Duplicate video-session rejection push path | CLOSED | Live `respond-video-session` v5 directly called FCM after `respond_to_video_session` had already inserted notification rows, while the notifications INSERT webhook is the canonical push authority. Branch source already contained the correct single-authority implementation; deployed live as v6 with JWT verification and re-read to verify the direct FCM path is absent. |
| UI-01 | P1 | Light/dark theme consistency | RECORDED IN GITHUB | Material dark contrast, shared glass/Discover/Profile dark-default token defects fixed in commit `74c59ad9`. Device visual verification pending. |
| UI-02 | P1 | Toggle state visibility | RECORDED IN GITHUB | Shared switch theme now has explicit orange ON, contrasted OFF, state glyphs, outlines, disabled state and pressed/focus feedback in commit `345f05d7`. Custom segmented/chip interaction audit remains in progress. |

## Current release constants
- Android application ID: `com.cotrainr.app`
- Flutter release name: `1.0.0`
- Flutter build number: `1`
- Minimum Android SDK: 26
- Target Android SDK: 36
- Production track target: Android first

## Current production baseline
- `pubspec.lock` is committed; deterministic resolved package versions are available for release-machine builds.
- Release Gradle configuration fails closed when the real upload keystore is absent.
- Android manifest contains no active Zoom callback intent; Google Meet/auth/reset/invite/hydration deep links remain.
- Supabase Flutter client contains the production project URL and anon client key. The anon key is public client configuration, not a service-role secret.
- Initial secret scan found environment-variable references/placeholders for privileged credentials, not an embedded service-role or Firebase private key. Full history/log scan remains in progress.
- Account deletion now has a live JWT-authenticated Edge endpoint and Flutter entry points for normal and restricted accounts; disposable-account E2E verification remains mandatory.

## Live security-advisor snapshot
- Mutable function search-path warning: cleared.
- Anonymous SECURITY DEFINER functions: 4 remaining after ACL hardening (1 intentional app pre-auth helper + 3 PostGIS-owned functions).
- Authenticated SECURITY DEFINER functions: review in progress; do not treat every advisor item as a vulnerability, but client-callable privileged functions must prove caller binding.
- Leaked-password protection: still disabled.
- RLS-with-no-policy findings on intentionally service-only tables are deny-by-default and are not automatically defects.
- PostGIS `spatial_ref_sys` / extension-in-public findings require extension-specific handling and must not be changed blindly during app hardening.

## Performance-advisor handling
The current advisor reports unindexed foreign keys, RLS init-plan opportunities, unused/duplicate indexes and multiple permissive policies. These are triaged by actual production impact. Authorization/schema will not be weakened or churned merely to make the advisor screen clean.

## Release-only local secret files
The following must never be committed:
- `android/key.properties`
- upload keystore (`*.jks` / `*.keystore`)
- local `.env*` except `.env.example`

## Master audit
The full end-to-end matrix and continuing findings are recorded in:
`docs/release/FULL_PRE_RELEASE_AUDIT.md`

## Final closure gates
Before Play production submission:
1. Zero unresolved P0/P1 security or correctness issues.
2. Full authenticated SECURITY DEFINER, RLS/grants and storage review complete.
3. Real upload keystore configured and backed up securely.
4. `flutter analyze` and relevant tests pass locally.
5. Signed release AAB builds and installs through Play internal testing.
6. Fresh Member, Trainer, and Nutritionist E2E passes.
7. Account deletion passes with a disposable user, including verification that storage and non-cascade user rows are removed.
8. Privacy Policy, Terms, account deletion, Data Safety, Health Apps declaration, and permission disclosures match audited runtime behaviour.
9. Notification, messaging, video, health, partner, events, restricted-account and deep-link flows pass real-device tests.
