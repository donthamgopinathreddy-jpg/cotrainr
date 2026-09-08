# Cotrainr Android Full Release Audit

Status: IN PROGRESS
Branch: security/pre-release-hardening
Platform gate: Android first
Production backend truth: live Supabase project nvtozwtuyhwqkqvftpyi

## Sign-off rule
A feature is not PASS because a screen exists. PASS requires the production path to be traced across UI -> interaction -> state/provider -> service/RPC/Edge Function -> authorization/RLS -> database/storage -> failure/loading/empty states -> release configuration. Local-only checks are explicitly marked LOCAL VERIFICATION REQUIRED.

Audit outcomes:
- FIXED BY ME — safe change made, verified and recorded.
- CURSOR / LOCAL ACTION REQUIRED — exact issue and acceptance criteria recorded; never count as fixed until locally implemented/verified.
- PASS — NO CHANGE REQUIRED — inspected with no release-relevant defect found.

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

### 01.02 Login screen — CODE AUDIT PASS AFTER FIX / LOCAL VISUAL VERIFY
Checked:
- SafeArea + scrollable keyboard-aware layout.
- Email/password validation and inline error states.
- Sign In loading, slow-network hint and success state.
- OAuth Google / Apple / Microsoft controls.
- Forgot-password and Sign Up secondary navigation.
- Password visibility control.
- Reduced-animation entry handling.

Fixed during audit:
- Forgot-password and Sign Up remained interactive during an in-flight password/OAuth login. They are now ignored and visibly dimmed while authentication is running, preventing navigation away from the active login transaction.
- Password visibility control is now disabled while login is in progress and exposes Show password / Hide password tooltips.
- Google, Apple and Microsoft icon-only OAuth buttons now expose explicit accessibility button labels and disabled semantics while loading.

Verification:
- Hardening-branch source read-back confirms loading locks, dimmed secondary actions, password tooltip/disabled state and OAuth semantics are present.
- No authentication/backend behaviour was changed in this UI item.

LOCAL VERIFICATION REQUIRED for 01.02:
- Small Android phone + keyboard open.
- Large text scaling up to app clamp.
- TalkBack labels for Google / Apple / Microsoft and password visibility.
- Forced light and dark mode visual pass.
- Rapid double-tap / back navigation during loading.

### 01.03 Create Account / signup wizard — CURSOR / LOCAL ACTION REQUIRED
Code inspection covered the seven-step signup wizard, credential validation, username availability state, email conflict state, password requirement chips, personal details, age/gender, height, weight, role/specialty, goals/legal acceptance, submit loading state and all-set success surface.

MAJOR interaction-state issue found in `lib/pages/auth/signup_wizard_page.dart`:
- `OnboardingBottomActions` correctly disables its Back button while `_isSubmitting`, but Android/system back is handled separately by `PopScope`.
- Current `PopScope.canPop` is only `_step == 0` and `onPopInvokedWithResult` calls `_back()` whenever the route did not pop.
- `_back()` itself has no `_isSubmitting` guard. On steps 1-6, Android back can therefore move the wizard backward while the final signup transaction is in flight.
- After successful signup `_showAllSet` becomes true, but the same PopScope remains active. Because the wizard is still at the final step, Android back can call `_back()`, decrement `_step`, and expose the signup wizard again after the account has already been created.

Required Cursor change — keep scope limited to this navigation-state defect:
1. In `_back()`, immediately return when `_isSubmitting || _showAllSet`.
2. Change PopScope so route popping is not allowed while `_isSubmitting` or `_showAllSet`. A suitable rule is `canPop: !_isSubmitting && !_showAllSet && _step == 0`.
3. In `onPopInvokedWithResult`, do not call `_back()` when `_isSubmitting` or `_showAllSet`; only step backward during the editable wizard state.
4. Preserve the existing bottom Back-button loading disable behaviour.
5. Do not change signup backend logic, role authority, legal recording, referral handling or post-success destination as part of this fix.

Acceptance criteria:
- During final `Finish` submission, Android system back / predictive back cannot leave the current step or reveal an earlier step.
- While `OnboardingAllSetView` is displayed, Android system back cannot return to the completed wizard.
- Before submission, Android back on steps 1-6 still moves exactly one wizard step backward.
- On step 0, normal route back still works when no submission/success state is active.
- No duplicate signup request is created.
- `flutter analyze` passes for the touched file.

LOCAL VERIFICATION REQUIRED for 01.03 after Cursor fix:
- Android predictive/system back on every wizard step.
- Back while Finish shows loading/slow hint.
- Back after All Set appears.
- Small phone + keyboard open on credential/personal-info steps.
- Large text and forced light/dark visual pass.
- Password visibility semantics/touch target check.

Status: OPEN — do not count 01.03 as fixed until Cursor/local implementation and verification are completed.

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
- Login secondary actions now lock during authentication; OAuth icon buttons have explicit accessibility labels.
- Global light/dark shared-widget corrections recorded.
- Shared SwitchTheme now gives explicit ON/OFF/disabled/pressed state in light and dark mode.

## Current open release gates
### BLOCKER / MAJOR review
- Signup wizard Android/system back must be locked during submission and after All Set success; exact Cursor/local instructions are recorded in 01.03.
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
