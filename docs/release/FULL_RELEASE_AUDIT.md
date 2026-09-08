# Cotrainr Android Full Release Audit

Status: IN PROGRESS
Branch: security/pre-release-hardening
Platform gate: Android first
Production backend truth: live Supabase project nvtozwtuyhwqkqvftpyi

## Sign-off rule
A feature is not PASS because a screen exists. PASS requires the production path to be traced across UI -> interaction -> state/provider -> service/RPC/Edge Function -> authorization/RLS -> database/storage -> failure/loading/empty states -> release configuration. Local-only checks are explicitly marked LOCAL VERIFICATION REQUIRED.

## Locked release order
1. Core UI / screens — 90% baseline — IN PROGRESS
2. Light / Dark theme — 88% baseline
3. Navigation / routing — 88% baseline
4. Authentication / onboarding — 82% baseline
5. Discover / profiles — 88% baseline
6. Connections / Model B — 90% baseline
7. Messaging — 85% baseline
8. Meal / water tracking — 85% baseline
9. Health metrics — 82% baseline
10. Video Sessions / Google Meet — 82% baseline
11. Notifications / reminders — 65% baseline
12. Partner centres / Pass / offers — 80% baseline
13. Backend / database — 88% baseline
14. RLS / security hardening — 82% baseline
15. Privacy / account deletion — 70% baseline
16. Android production configuration — 80% baseline
17. Code / legacy cleanup — 70% baseline
18. Physical-device / E2E verification — 50% baseline
19. Play Store release work — 45% baseline

## Severity
- BLOCKER: security/privacy/data loss/crash/release rejection/core flow unusable
- MAJOR: important feature broken or materially misleading UX
- MINOR: polish/non-critical inconsistency
- POST-LAUNCH: safe improvement that does not block release

## 01 Core UI / screens
### 01.01 App root + splash + welcome — CODE AUDIT PASS / LOCAL VISUAL VERIFY
Checked on the hardening branch:
- App root uses MaterialApp.router with the shared light/dark themes and system UI overlay derived from effective brightness.
- Native splash is preserved until Flutter splash paints, with a 2-second native-splash failsafe.
- Flutter splash has SafeArea-aware positioning, responsive clamps, image fallback, reduced-motion handling, startup slow hint, and disposes all timers/controllers.
- Startup navigation waits for a minimum splash duration and routes signed-in users through the authoritative post-auth resolver rather than blindly to Home.
- Password recovery and pending message/video deep-link startup paths are explicitly preserved.
- Welcome uses SafeArea, responsive logo sizing, disabled button state while navigation is busy, haptic feedback and reduced-animation handling.
- No code-level BLOCKER/MAJOR UI defect found in these first surfaces.

LOCAL VERIFICATION REQUIRED for 01.01:
- Small Android phone / large font visual overflow check.
- Forced light and dark mode visual check (splash intentionally branded black).
- Reduced-animation accessibility check.
- Cold start signed-out, signed-in and password-recovery launch check.

Next single Core UI item: Login screen visual/state audit. Do not advance to category 02 until Core UI reachable screens are exhausted.

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
- create_lead_tx now requires the target provider to be currently verified.
- update_lead_status_tx now rechecks provider verification at acceptance time.
- Global light/dark shared-widget corrections recorded.
- Shared SwitchTheme now gives explicit ON/OFF/disabled/pressed state in light and dark mode.

## Current open release gates
### BLOCKER / MAJOR review
- Full authenticated SECURITY DEFINER RPC authorization review is not complete.
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

## Cleanup safety rules
- Never delete historical migrations.
- Never remove hidden CoCircle/Quest backend merely because the MVP UI hides it; future-feature and health-startup dependencies must be preserved.
- Do not remove QuestSyncInitializer without replacing its health startup responsibility.
- Zoom runtime/database residue may be removed only after app, Edge Function, FK, trigger, view, grant and dependency checks prove it orphaned.
- Live Supabase remains production truth; any production DDL cleanup requires a new forward migration in GitHub.

## Release verdict
NOT READY FOR STORE SUBMISSION YET.
Reason: remaining production security/authz audit, complete E2E wiring audit, privacy/deletion verification, local compile/test/device gates, signing and Play Internal Testing are still open.
