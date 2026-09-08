# Core UI 01.06 — Home shell / bottom navigation root

Status: CURSOR / LOCAL ACTION REQUIRED
Scope: `lib/pages/home/home_shell_page.dart`
Release rule: 10-state UI audit + interaction/accessibility states

## What was inspected
- Role-dependent root shell for Client / Trainer / Nutritionist.
- Lazy page cache and visited-tab behaviour.
- Bottom navigation destinations: Home, Discover/My Clients, Messages, Meals, Profile.
- Role-loading and role-error fallback.
- Retry path for role/profile load.
- unread-message dot behaviour.
- welcome bubble.
- auth/realtime badge invalidation and app-resume invalidation.
- pending Video Session navigation.
- incomplete-onboarding guard.

## 10-state audit
1. Normal/default — PASS. Valid resolved role renders the correct role-specific Home and second tab.
2. Loading — PASS. Unknown role shows a neutral spinner; it does not guess Client.
3. Refreshing/reloading — PASS at shell level. Role retry invalidates `currentUserProvider`; badge providers refresh on realtime/auth/resume. Individual child-page refresh states are audited with their own screens.
4. Empty — N/A at shell level. Empty states belong to Discover/My Clients/Messages/Meals/Profile child pages.
5. Error — PASS for role load. A dedicated account-load error surface is shown instead of a guessed role.
6. Retry/recovery — PASS for role load via `Try Again` and provider invalidation.
7. Success — PASS. Resolved role renders the shell and correct role-dependent tab destinations.
8. Disabled/unavailable — PARTIAL. Same selected tab does not rebuild/navigation-switch unnecessarily. However bottom-nav controls do not expose semantic disabled/selected state to accessibility services.
9. Partial/degraded — PASS WITH LOCAL VERIFY. unread-message provider failure degrades to no dot rather than blocking navigation. Individual page degradation is delegated to each tab audit.
10. Offline/slow/interrupted — PASS for role lookup through the provider error/retry surface; LOCAL VERIFY REQUIRED for reconnect behaviour and realtime badge recovery.

## MAJOR accessibility / interaction-state issue
The bottom navigation is built with icon-only `GestureDetector`s in `_buildNavItem()`.

Current problems:
- No `Semantics(button: true, label: item.label, selected: isActive)` around each destination.
- The visible text label is not rendered, so TalkBack has no explicit destination name from this widget.
- No explicit pressed visual state; only selected/unselected state exists.
- No haptic/Material ink feedback on tab change.
- unread dot is visual-only and is not announced to screen readers.

This does not break sighted navigation but fails the release accessibility/interaction-state standard.

## Required Cursor change
Keep the scope limited to `_buildNavItem()` unless a shared nav component already exists locally.

1. Wrap each nav destination in `Semantics` with:
   - `button: true`
   - `label: item.label`
   - `selected: isActive`
   - for Messages when unread count > 0, include an accessibility value/hint such as `Unread messages` or a count if the provider exposes it safely.
2. Prefer a Material interaction surface (`InkWell`/`InkResponse`) or an equivalent stateful pressed treatment so normal -> pressed -> selected states are visibly distinct.
3. Preserve the existing selected icon and underline indicator.
4. Preserve lazy tab caching and `_goToTab()` behaviour.
5. Do not introduce route pushes for bottom tabs; this shell currently owns tab switching.
6. Add light haptic feedback only on an actual tab change, not when tapping the already-selected tab.
7. Ensure the touch target remains at least 48x48 logical pixels.
8. Do not change the current role-specific second-tab mapping in this item.

## Acceptance criteria
- TalkBack announces `Home`, `Discover` or `My Clients`, `Messages`, `Meals`, and `Profile`.
- TalkBack announces which tab is selected.
- Messages unread indication is not exclusively visual.
- Every tab has normal, pressed, selected and accessibility focus states.
- Tapping the selected tab does not create duplicate navigation or reset the cached page.
- Switching tabs preserves existing lazy `IndexedStack` state.
- Client gets Discover; Trainer/Nutritionist get My Clients.
- `flutter analyze` passes for the touched file.

## LOCAL VERIFICATION REQUIRED
- Android TalkBack swipe navigation through all five tabs.
- Large font/display-size check even though labels are semantic-only in the current design.
- Forced Light and Dark mode selected/unselected/pressed contrast.
- Rapid alternating tab taps.
- Resume after background and verify unread dot refresh.
- Offline -> reconnect while role load initially fails; `Try Again` recovers without restarting the app.
- Client/Trainer/Nutritionist role switch test to ensure cached pages are cleared and second-tab identity updates.
- System navigation bar / gesture-inset check to ensure the floating bottom bar remains reachable and does not overlap content.

## Verdict
Shell async-state handling: CODE PASS.
Bottom-navigation accessibility/pressed-state handling: OPEN — CURSOR / LOCAL ACTION REQUIRED.
Do not mark 01.06 complete until the nav semantics/pressed-state change is implemented and locally verified.