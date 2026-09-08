# Cotrainr End-to-End Production Release Audit

Status: IN PROGRESS
Platform target: Android first
Branch: `security/pre-release-hardening`
Production backend: Supabase `nvtozwtuyhwqkqvftpyi`

This is the release sign-off register. A feature is not considered release-ready because its screen exists; its UI, interaction states, wiring, authorization, backend, failure states and production configuration must all be verified.

## Severity
- P0 BLOCKER — security/privacy/data-loss/release-signing issue. Do not release.
- P1 MAJOR — core flow broken or materially misleading. Fix before release.
- P2 MINOR — polish/reliability issue that may ship only if explicitly accepted.
- POST — safe post-launch improvement.

## Audit waves

### Wave 0 — Baseline and known blockers
- [x] Android release debug-signing fallback removed.
- [ ] LOCAL: generate permanent Play upload keystore and configure untracked `android/key.properties`.
- [x] compile/target SDK raised to 36 in hardening work.
- [ ] LOCAL: `flutter analyze`.
- [ ] LOCAL: automated tests.
- [ ] LOCAL: signed release AAB build.
- [ ] PLAY: Internal Testing install/upgrade test.
- [ ] P0/P1: final secret/configuration exposure scan.
- [ ] P0/P1: final Supabase public surface/RLS/RPC/Storage/Edge Function authorization audit.
- [ ] P1: account deletion data-lifecycle verification.
- [ ] P1: production environment/dev-bypass/logging audit.

### Wave 1 — App shell, navigation and interaction states
- [x] MaterialApp light/dark themes wired.
- [x] Shared light/dark token corrections applied.
- [x] Shared Switch states made visually explicit (ON/OFF/disabled/pressed).
- [ ] Reachable route inventory by Client / Trainer / Nutritionist.
- [ ] Back-navigation/root-destination audit.
- [ ] Deep-link/app-link audit.
- [ ] Custom segmented controls/chips/tabs selected/pressed/disabled states.
- [ ] CTA normal/pressed/loading/disabled/error states.
- [ ] Icon-only touch target/ripple/contrast audit.
- [ ] Keyboard/safe-area/overflow audit.
- [ ] Empty/loading/error/offline states.

### Wave 2 — Authentication and onboarding
- [ ] Email/password signup/login/logout/session restoration.
- [ ] Forgot/reset password.
- [ ] Social OAuth providers actually enabled for launch.
- [ ] Phone OTP if retained for launch.
- [ ] Username availability and duplicate handling.
- [ ] Role authority: client cannot self-promote to verified provider.
- [ ] Incomplete onboarding recovery.
- [ ] Trainer/nutritionist verification states and enforcement.
- [ ] Leaked-password protection — currently requires Supabase Dashboard action.

### Wave 3 — Core product wiring
- [ ] Discover and public profiles.
- [ ] Model B connection allowance/request/accept/end/restore.
- [ ] Messaging and conversation authorization.
- [ ] Meal tracker and hydration.
- [ ] Health metrics / Health Connect permission and unavailable states.
- [ ] Video Sessions / Google Meet OAuth/create/list/detail/join/respond/cancel/edit.
- [ ] Notifications/reminders/action handling.
- [ ] Nearby centres / location denial and failure handling.
- [ ] Partner offers / Cotrainr Pass / membership verification.
- [ ] Profile/settings/privacy/security.
- [ ] Community event surface retained for release.

### Wave 4 — Backend and data integrity
- [ ] Public tables and grants.
- [ ] RLS policy ownership/cross-user tests.
- [ ] SECURITY DEFINER function-by-function authorization review.
- [ ] Views/security_invoker review.
- [ ] Trigger and constraint integrity.
- [ ] Storage bucket/policy audit.
- [ ] Edge Function JWT/custom-auth audit.
- [ ] OAuth state/PKCE/redirect validation.
- [ ] FCM/device-token ownership and cleanup.
- [ ] Account deletion cascade/anonymization/storage cleanup.
- [ ] Obsolete live Zoom objects dependency audit before removal.

### Wave 5 — Repository/security/configuration
- [ ] Secrets and credentials in current tree.
- [ ] Sensitive debug logging.
- [ ] localhost/dev/test endpoints and bypass flags.
- [ ] Firebase/Supabase production project consistency.
- [ ] Android manifest permissions and exported components.
- [ ] Dependency/lockfile review.
- [ ] Dead routes/screens/providers/services/assets.
- [ ] Preserve historical migrations and intentionally hidden future features.

### Wave 6 — Release candidate
- [ ] Fresh install.
- [ ] Upgrade install.
- [ ] Client E2E.
- [ ] Trainer E2E.
- [ ] Nutritionist E2E.
- [ ] Permission denial/recovery tests.
- [ ] Background/terminated notification tests.
- [ ] OAuth/deep-link tests.
- [ ] Account deletion test account.
- [ ] Play Data Safety / Health declaration / Privacy / Terms match actual behaviour.

## Current live Supabase advisor baseline — 2026-09-08
- Leaked password protection: WARN, disabled. Manual Dashboard action remains.
- 13 RLS-enabled/no-policy tables. These are being treated as deny-by-default/service-only until each caller is verified; no permissive policies will be added merely to silence the advisor.
- Anonymous SECURITY DEFINER: `is_username_available(text)` plus three PostGIS-owned `st_estimatedextent` overloads. Username availability is intentional pre-auth surface but remains in the final authorization review.
- Authenticated SECURITY DEFINER: advisor reports 46 callable functions. This is not automatically a defect; each application RPC must prove caller/ownership/role checks before sign-off.
- `public.spatial_ref_sys` RLS and PostGIS-in-public findings are extension-owned and will not be modified blindly.

## Known release records already completed
- Privileged admin/verification RPC execution hardened.
- Partner operational table exposure hardened.
- Signing secret hygiene hardened; local upload key still required.
- Generic Flutter package metadata corrected.
- Health source fail-closed behaviour and Health Connect least privilege corrected.
- Fake Insights fallback data removed.
- Signup/onboarding role authority hardened.
- Anonymous privileged RPC exposure reduced.
- Notification preference arbitrary-user read fixed.
- Provider reviews view security corrected.
- Mutable function search paths hardened.
- `create-video-session` production Edge Function verifies provider status before Meet creation.
- Light/dark shared theme defects corrected.
- Shared switch state visibility corrected.

## Rules for fixes
1. Production Supabase is the backend truth.
2. Never replay historical migrations into production.
3. DB changes require a new forward migration record.
4. Never delete a table/function/file solely because its name looks old.
5. Hidden CoCircle/Quest infrastructure is future-facing unless proven obsolete; `QuestSyncInitializer` must not be removed without tracing health startup.
6. Historical migration files are retained.
7. Every remote-safe fix goes on this branch and is recorded here or in `PRE_RELEASE_HARDENING_STATUS.md`.
8. Anything requiring compilation/emulator/device/Play Console is marked LOCAL or PLAY rather than guessed as passed.
