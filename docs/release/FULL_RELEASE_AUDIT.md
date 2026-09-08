# Cotrainr Android Full Release Audit

Status: IN PROGRESS
Branch: security/pre-release-hardening
Platform gate: Android first
Production backend truth: live Supabase project nvtozwtuyhwqkqvftpyi

## Sign-off rule
A feature is not PASS because a screen exists. PASS requires the production path to be traced across UI -> interaction -> state/provider -> service/RPC/Edge Function -> authorization/RLS -> database/storage -> failure/loading/empty states -> release configuration. Local-only checks are explicitly marked LOCAL VERIFICATION REQUIRED.

## Audit order
1. App boot, splash, session restoration and routing
2. Authentication and role onboarding
3. Client / Trainer / Nutritionist shells and navigation
4. Global UI theme, light/dark mode and interaction states
5. Discover and public profiles
6. Connection Model B and subscriptions/entitlements
7. Messaging
8. Meal tracker, hydration and health metrics
9. Video Sessions and Google Meet
10. Notifications and reminders
11. Nearby / partner centres / member pass / offers
12. Community events retained for MVP
13. Profile, settings, legal and account deletion
14. Android permissions, deep links, lifecycle and background behaviour
15. Supabase tables, RLS, grants, views, RPCs, triggers, storage and Edge Functions
16. Secret/config/logging/privacy audit
17. Dead code, obsolete UI, retired integrations and dependency cleanup
18. Performance/reliability
19. Local Flutter analysis/tests/release build
20. Signed AAB and Play Internal Testing

## Severity
- BLOCKER: security/privacy/data loss/crash/release rejection/core flow unusable
- MAJOR: important feature broken or materially misleading UX
- MINOR: polish/non-critical inconsistency
- POST-LAUNCH: safe improvement that does not block release

## Current verified fixes
- Privileged admin/verification RPC execution hardened.
- Partner operational tables protected with RLS.
- Android release debug-signing fallback removed; permanent upload keystore remains local-only.
- compileSdk/targetSdk recorded at 36; local release build remains required.
- Health source fail-closed and Android Health Connect permissions reduced to read-only MVP needs.
- Fake Insights fallback series removed.
- Signup/onboarding provider authority hardened.
- Anonymous/private RPC ACL waves applied and recorded.
- Notification preference arbitrary-user read hardened.
- provider_reviews view security corrected.
- Mutable function search_path wave corrected.
- create-video-session live function verifies provider before Meet creation.
- Global light/dark shared-widget corrections recorded.
- Shared SwitchTheme now gives explicit ON/OFF/disabled/pressed state in light and dark mode.

## Current open release gates
### BLOCKER / MAJOR review
- Full authenticated SECURITY DEFINER RPC authorization review is not complete. The current Supabase advisor reports 46 authenticated-callable SECURITY DEFINER functions. Many are intentional app RPCs, but each must be checked for internal caller/ownership authorization rather than accepted from the grant alone.
- Full repository/config/history secret exposure review remains open.
- Full deployed Edge Function JWT/auth/error/secret review remains open.
- Account deletion end-to-end data/privacy verification remains open.
- Production environment / debug / sensitive logging review remains open.
- Custom segmented/chip/tab/button interaction-state audit remains open.
- Complete screen-by-screen light/dark visual audit remains open.

### External/manual configuration
- Supabase leaked-password protection is currently reported disabled by the live security advisor. Enable in Supabase Auth settings if the project plan supports it, then rerun the advisor.

### LOCAL VERIFICATION REQUIRED
- flutter analyze
- flutter test
- Android forced Light-mode visual pass
- Android forced Dark-mode visual pass
- Fresh-install and upgrade-path tests
- Permanent Play upload keystore + android/key.properties
- Signed release AAB
- Play Internal Testing
- Physical-device Health Connect, notification, OAuth/deep-link and background/lifecycle tests

## Current Supabase advisor interpretation
- auth_leaked_password_protection: OPEN manual configuration warning.
- anon SECURITY DEFINER: is_username_available is intentional pre-auth functionality but must remain narrow; remaining st_estimatedextent overloads are PostGIS-owned and should not be modified blindly.
- authenticated SECURITY DEFINER: requires per-function authorization review; this is not automatically a vulnerability and is not automatically safe.
- RLS-enabled/no-policy service tables: keep deny-by-default where service-only is intentional; user_integrations_zoom remains a cleanup candidate pending complete dependency proof.
- spatial_ref_sys / PostGIS extension findings are extension-owned; do not mutate blindly.

## Cleanup safety rules
- Never delete historical migrations.
- Never remove hidden CoCircle/Quest backend merely because the MVP UI hides it; future-feature and health-startup dependencies must be preserved.
- Do not remove QuestSyncInitializer without replacing its health startup responsibility.
- Zoom runtime/database residue may be removed only after app, Edge Function, FK, trigger, view, grant and dependency checks prove it orphaned.
- Live Supabase remains production truth; any production DDL cleanup requires a new forward migration in GitHub.

## Release verdict
NOT READY FOR STORE SUBMISSION YET.
Reason: remaining production security/authz audit, complete E2E wiring audit, privacy/deletion verification, local compile/test/device gates, signing and Play Internal Testing are still open.
