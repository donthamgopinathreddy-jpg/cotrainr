# Cotrainr Cursor / Local Action Queue

This file records release-audit findings that are proven from the hardening branch but cannot be safely implemented or fully verified from the current remote tooling. Do not mark an item complete until the acceptance criteria are satisfied locally and the resulting code is committed back to `security/pre-release-hardening`.

## 01 Core UI / screens

### 01.03 Signup Wizard — submission-time back navigation
Status: CURSOR / LOCAL ACTION REQUIRED
Severity: MAJOR UX / state integrity
Affected file: `lib/pages/auth/signup_wizard_page.dart`
Affected surface: final onboarding submission and bottom navigation

#### Issue
While `_isSubmitting == true`, the Next/Finish action is disabled via:

`onNext: _isSubmitting ? null : _next`

but Back is still passed as:

`onBack: _back`

`_back()` itself also has no `_isSubmitting` guard. This means the user can move backward in the wizard while account creation/finalization is still in flight.

#### Required change
Make backward navigation unavailable while `_isSubmitting` is true.

Preferred implementation:
- Pass `onBack: _isSubmitting ? null : _back` if `OnboardingBottomActions` supports a nullable callback.
- If it does not, update `OnboardingBottomActions` to support a disabled Back state and render that state visibly disabled.
- Add a defensive first line in `_back()`:
  `if (_isSubmitting) return;`
- Ensure Android system back / PopScope cannot change wizard step during submission. The existing PopScope delegates to `_back()` for internal steps, so the defensive `_back()` guard is required even if the button is disabled.

#### Expected behaviour
Once the user taps Finish and submission begins:
- Finish shows loading state.
- Back cannot be tapped.
- Android system back cannot move to a previous onboarding step.
- No page/step state changes occur until submission succeeds or fails.
- On failure, controls become enabled again.

#### Acceptance criteria
1. Reach final signup step with valid data.
2. Tap Finish.
3. While loading, repeatedly tap Back and Android system back.
4. Confirm wizard remains on the final step and no duplicate navigation/state mutation occurs.
5. Simulate an auth/network failure and confirm Back/Finish re-enable afterward.
6. Run `flutter analyze` and fix any resulting warnings/errors.
7. Test on a physical Android device or emulator.

#### Additional local visual verification for 01.03
- Small-screen overflow across all 7 steps.
- Large system font / text scaling.
- Keyboard visibility and scroll reachability on credentials, name, phone and custom specialty fields.
- Light and dark mode.
- Role/specialty chips selected/unselected/disabled states.
- Goals + legal checkbox states.
- Height/weight unit toggles.
- Social-signup prefilled email read-only appearance.
- All Set success screen and Continue action.
