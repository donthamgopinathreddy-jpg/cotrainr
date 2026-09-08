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
| HEALTH-01 | P0 | Android health-source correctness | CLOSED | Health Connect/Apple Health remains the only movement source; no sensor fallback was added. Android initialization fails closed when Health Connect is unavailable or no movement permission is usable (`90ffbc39`). Metrics sync no longer persists empty snapshots when the source is unavailable and preserves existing positive daily totals when an individual Health Connect read is denied/transiently empty (`11f9b855`). Initialization now remains resolved after denial/unavailability so background sync does not reopen permission prompts every 30 seconds; explicit Connect/reinitialize is the retry path (`24cd5bd3`). Home already renders cached real data or an unavailable dash rather than a fake measured zero. Regression coverage added in `test/utils/health_metric_display_test.dart` (`f0db81fe`). Local/CI test execution remains part of final build verification. |
| HEALTH-02 | P1 | Health Connect least-privilege permissions | CLOSED | Current health service requests READ only; manifest write permissions removed and read permissions retained. Android integration uses `FlutterFragmentActivity`, Health Connect permission-rationale wiring, and package visibility setup. |
| ROUTE-01 | P1 | Legacy Zoom deep-link/router residue | RECORDED IN GITHUB | Android external Zoom callback intent and active Video Sessions UI wiring are removed. A defensive compatibility callback/redirect remains in `AppLinkHandler` / `app_router.dart`; attempted cleanup was blocked by the connected GitHub write guard. No current Google Meet flow depends on it. |
| DATA-01 | P0 | Fake Insights fallback series | CLOSED | Positive fabricated fallback arrays were removed. Router fallbacks are now explicit zero/no-data series while `InsightsDetailPage` reloads authoritative repository data. GitHub commit `721c249`. |
| AUTH-01 | P0 | Signup/onboarding role authority and provider verification integrity | CLOSED | Self-declared signup role is no longer sufficient for provider authority. Discovery requires `verified=true`; live DB triggers require a verified trainer/nutritionist for accepted leads and every video-session host. No accepted unverified provider links or sessions with unverified hosts exist. `create-video-session` now also fails early on the live Edge runtime unless `providers.verified=true`, before any Google Meet space is created. |
| RPC-01 | P1 | Anonymous SECURITY DEFINER exposure | CLOSED | ACL hardening reduced anonymous SECURITY DEFINER exposure from 29 to 4. `rpc_resolve_login_identifier` is now service_role-only (`5747fbe8`), and unused legacy `check_user_id_availability` is no longer app-callable (`8f873629`). The sole intentional app-owned anonymous RPC is `is_username_available`, which validates format and returns only an availability boolean for pre-auth signup. The other three advisor findings are PostGIS-owned `st_estimatedextent` overloads and are left to extension-specific handling. Targeted authenticated helpers with user/session IDs were inspected and bind sensitive checks to `auth.uid()` where required. |
| RPC-02 | P1 | `get_notification_push` arbitrary user preference read | CLOSED | Live RPC now service_role-only; anon/authenticated EXECUTE removed; verified and forward migration recorded. |
| VIEW-01 | P0/P1 | `provider_reviews` SECURITY DEFINER view | CLOSED | View now `security_invoker=true`; anon SELECT removed; authenticated/service_role SELECT retained; live verified and migration recorded. |
| DB-01 | P1 | Mutable function search_path warnings | CLOSED | All 28 advisor-reported mutable function search paths were pinned to `public, pg_catalog`; live security advisor no longer reports `function_search_path_mutable`. Forward migration recorded. |
| AUTH-02 | P1 | Leaked-password protection | OPEN | Live Supabase advisor still reports leaked-password protection disabled. Current connected Supabase actions do not expose the Auth configuration write needed to enable it. |
| EDGE-01 | P1 | `create-video-session` early verification gate deployment | CLOSED | Live Supabase Edge Function `create-video-session` version 41 is ACTIVE with JWT verification enabled and checks `providers.provider_type` + `providers.verified=true` before Google Meet creation. Live deployment was re-read and verified after deployment. |

## Current release constants
- Android application ID: `com.cotrainr.app`
- Flutter release name: `1.0.0`
- Flutter build number: `1`
- Minimum Android SDK: 26
- Target Android SDK: 36
- Production track target: Android first

## Live security-advisor snapshot
- Mutable function search-path warning: cleared.
- Anonymous SECURITY DEFINER functions: 4 remaining after ACL hardening (down from 29): 1 intentional pre-auth username availability RPC + 3 PostGIS-owned functions.
- Leaked-password protection: still disabled.
- RLS-with-no-policy findings on intentionally service-only tables are deny-by-default and are not automatically defects.
- PostGIS `spatial_ref_sys` / extension-in-public findings require extension-specific handling and must not be changed blindly during app hardening.

## Release-only local secret files
The following must never be committed:
- `android/key.properties`
- upload keystore (`*.jks` / `*.keystore`)
- local `.env*` except `.env.example`

## Final closure gates
Before Play production submission:
1. Zero unresolved P0/P1 security or correctness issues.
2. Real upload keystore configured and backed up securely.
3. Signed release AAB builds and installs through Play internal testing.
4. Fresh Member, Trainer, and Nutritionist E2E passes.
5. Privacy Policy, Terms, account deletion, Data Safety, Health Apps declaration, and permission disclosures match audited runtime behaviour.
6. Notification, messaging, video, health, partner, events, and restricted-account flows pass real-device tests.
