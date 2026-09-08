# Cotrainr Light / Dark Theme Release Audit

Status: CODE AUDIT PASS AFTER FIXES / LOCAL VISUAL VERIFICATION REQUIRED
Branch: security/pre-release-hardening
Area: 02 — Light / Dark theme
Target: 100% after device matrix verification

## Scope

This audit covers:
- root ThemeData and ColorScheme
- theme mode selection and persistence
- status/navigation system bars
- app bars, cards, inputs, buttons, dividers, switches
- selected/pressed/disabled appearance controls
- Home/Discover/Meal Tracker/Messaging/Profile theme architecture
- semantic/status/accent colors vs accidental hard-coded light/dark colors
- theme switching without typography/layout jumps
- accessibility text scaling and reduced motion interaction
- light/dark verification on narrow/large-text Android configurations

## FIXED BY ME

### 1. Accessibility text scale was globally capped at 1.2x
File: `lib/main.dart`

Previous behavior:
- MaterialApp builder replaced the platform text scaler with a clamp of 0.8–1.2.
- Users with larger Android accessibility font settings did not receive their requested size.
- The cap could hide overflow/layout defects during testing.

Fix:
- Removed the global text-scale clamp.
- Cotrainr now preserves the platform text scaler.

Commit: `54c88051f71d0b40a5fd96a782a2b03bf76b5528`

### 2. Theme selection did not persist across app restart
Files:
- `lib/theme/theme_mode_provider.dart`
- `lib/main.dart`
- `lib/widgets/profile/appearance_toggle.dart`

Previous behavior:
- `themeModeProvider` always initialized to `ThemeMode.system`.
- Selecting Light or Dark was in-memory only.

Fix:
- Persist System/Light/Dark using SharedPreferences.
- Restore saved mode before `runApp` to avoid a System-theme flash on launch.
- Keep persistence failure non-fatal and fall back to System.
- Persist both appearance segmented-control changes and icon-cycle changes.

Commits:
- `c2ef4d68a0d8566cc1829cb63b794ca09b8af667`
- `4e3b1691459ba1bafe683f7d95c6a06c39b95799`
- `cfffa983b040bb6b942ae1ecca63e31601d1e3e2`

### 3. Appearance control accessibility / motion
File: `lib/widgets/profile/appearance_toggle.dart`

Fix:
- 48dp effective target.
- Semantics label/value/selected state.
- Tooltip reflects current mode.
- Ink response instead of bare GestureDetector for segmented options.
- Sliding indicator honors `MediaQuery.disableAnimationsOf(context)`.
- Replaced old `withOpacity` calls in edited paths with `withValues`.

Commit: `cfffa983b040bb6b942ae1ecca63e31601d1e3e2`

### 4. AppBar typography changed when toggling dark mode
File: `lib/theme/app_theme.dart`

Previous behavior:
- Light AppBar: Montserrat 28 / w800.
- Dark AppBar: Poppins 24 / bold.
- Switching theme changed title geometry and hierarchy.

Fix:
- Dark AppBar now uses the same Montserrat 28 / w800 / 0.4 tracking as light mode.
- Foreground color remains brightness-appropriate.

Commit: `e13a322137a46380291781961b545f903406341b`

## PASS — ROOT THEME ARCHITECTURE

### ColorScheme
- Light `onPrimary`/`onSecondary` use white against dark primary/secondary surfaces.
- Dark primary/secondary are light foreground-like colors and their `onPrimary`/`onSecondary` correctly use dark background, preventing white-on-white Material states.
- `onSurface`, `onBackground`, error and divider treatment are brightness-aware.

### System UI
File: `lib/main.dart`
- transparent status bar
- light icons in dark mode
- dark icons in light mode
- dark navigation bar in dark mode
- white navigation bar in light mode
- navigation icon brightness follows theme
- divider transparent

PASS at code level. Physical Android verification still required for gesture navigation and 3-button navigation.

### Core themed components
File: `lib/theme/app_theme.dart`
- scaffold background: mode-aware
- cards: mode-aware
- app bars: mode-aware
- inputs: mode-aware fill/border/hint/focus/error
- icons: mode-aware
- dividers: mode-aware
- switches: explicit selected/off/disabled/pressed states
- global Poppins body hierarchy retained
- Montserrat display/AppBar hierarchy retained consistently

### Account/Profile hub
File: `lib/theme/account_hub_theme.dart`
- page/card/text colors are resolved from brightness/ColorScheme.
- switch states have explicit contrast in light/dark.
- status colors (danger, subscription, message, goal) are semantic and intentionally theme-agnostic.

### Home premium theme
File: `lib/widgets/home_v3/home_premium_theme.dart`
- explicit paired light/dark surfaces and text.
- metric palettes intentionally vary by mode.
- semantic metric colors are retained rather than inverted.
- shadows/tracks are mode-aware.

## PRIMARY TAB THEME VERDICT

### Home — CODE PASS / LOCAL VERIFY
- Uses `HomePremiumTheme`, `DesignTokens`, current brightness and semantic metric colors.
- Hero photographic scrim intentionally uses white foreground in both modes; this is content-overlay styling, not a light-theme leak.
- Metric/status accent colors remain semantic.

Local verify:
- secondary text contrast on gradient metric cards
- hero username/bell contrast for arbitrary cover images
- large text after removing global 1.2x clamp
- disabled/unavailable metric state in both modes

### Discover — CODE PASS WITH LOCAL VERIFY
- Root scaffold derives from ColorScheme.
- text/borders use theme-aware DesignTokens.
- Discover orange and white-on-accent CTA text are intentional brand/accent colors.
- location/error/empty/loading surfaces follow theme-aware tokens.

Local verify:
- provider card chip contrast
- disabled/request-busy controls
- filter bottom sheet in light/dark
- location-denied banner
- partner centre card/offers

### Meal Tracker — CODE PASS WITH LOCAL VERIFY
- Page has explicit dark background and context-resolved light/dark surfaces/text.
- meal semantic icon colors remain stable across modes.
- RefreshIndicator background uses theme-aware surface.

Local verify:
- pinned header transitions when switching theme
- macro/ring contrast
- add/edit food sheets/dialogs
- calendar picker
- failure/degraded states once the state fixes are implemented

### Messaging — CODE PASS WITH LOCAL VERIFY
- Messaging list architecture already uses theme-aware surface/text tokens.
- unread/status/accent colors are semantic.
- shared fade/content transitions now honor reduced motion.

Local verify:
- conversation unread badge contrast
- search field focus/clear states
- ChatScreen bubbles for sender/receiver
- deleted-message tombstone
- attachment/file/audio cards
- composer disabled/sending/error states

### Profile — CODE PASS WITH LOCAL VERIFY
- Account hub uses `AccountHubTheme` and ColorScheme.
- Appearance controls now persist and are accessibility-aware.

Local verify:
- verification cards
- subscription/status cards
- settings pages
- integrations/Health Connect rows
- destructive Account/Delete/Sign out states

## INTENTIONAL HARD-CODED COLORS — DO NOT AUTO-REPLACE

The following are not theme defects by themselves:
- `Colors.white` used as foreground over known dark/accent/photo backgrounds.
- black scrims/shadows over cover photography.
- semantic red/green/amber/blue status colors.
- metric-specific colors for steps/calories/water/distance.
- purple Video Sessions accent.
- Discover orange accent.

Only replace a hard-coded color when its meaning is actually a light/dark surface/text dependency or it fails contrast in the target state.

## CURSOR / LOCAL DEVICE VERIFICATION REQUIRED

Run the complete reachable Android MVP UI in both Light and Dark and include all mandatory states from the 10-state audit.

Required matrix:
1. Light mode, normal font.
2. Dark mode, normal font.
3. System mode while Android system theme is light.
4. System mode while Android system theme is dark.
5. Change system theme while Cotrainr is foregrounded and while backgrounded/resumed.
6. Restart app after selecting Light; verify it stays Light.
7. Restart app after selecting Dark; verify it stays Dark.
8. Select System, restart; verify it follows Android theme.
9. Large accessibility font scale now that the 1.2x cap is removed.
10. 320dp narrow device plus large text.
11. Gesture navigation and 3-button navigation.
12. Keyboard-open forms/sheets in both themes.
13. Reduced motion enabled.

For every root/primary screen verify:
- no white-on-white or black-on-black
- no low-contrast secondary text
- no stale light surface after live theme switch
- no stale dark surface after live theme switch
- no theme-switch typography/layout jump
- status bar/nav bar icons stay visible
- selected/pressed/disabled states remain distinguishable
- error/success/warning colors remain legible
- images/logos are not incorrectly inverted or recolored
- snackbars/dialogs/sheets/date pickers are readable
- no RenderFlex/pixel overflow exposed by the newly restored large text scale

## FINAL AREA 02 VERDICT

**CODE AUDIT PASS AFTER FIXES.**

The major root defects found in this area were fixed: accessibility text-scale suppression, non-persistent appearance choice, weak appearance-control semantics/reduced-motion handling, and AppBar typography changing between themes.

Area 02 is **not marked 100% production-verified until the Android light/dark device matrix above passes**, because contrast, system UI and overflow are visual/runtime properties that cannot be fully proven from repository inspection alone.
