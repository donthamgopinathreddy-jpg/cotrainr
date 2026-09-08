# Cotrainr Light / Dark Mode Audit

Audit branch: `security/pre-release-hardening`

Date: 2026-09-08

## Scope

Repository-wide source review focused on Flutter UI theme correctness before Android production release. The audit checked the global theme wiring, Material color-scheme contrast, system-bar behavior, direct black/white usage, legacy dark-default `DesignTokens` aliases, shared reusable widgets, and reachable MVP surfaces.

## Global theme wiring

`MaterialApp.router` already supplies both `AppTheme.lightTheme` and `AppTheme.darkTheme` and consumes `themeModeProvider`. System status/navigation icon brightness is derived from the effective theme. No forced light-only or dark-only app mode was found in the production root.

## Fixes applied in this wave

### THEME-01 — Dark Material foreground contrast

`AppTheme.darkTheme.colorScheme` used white as `primary` while also setting `onPrimary` to white, and a light grey `secondary` with white `onSecondary`. Material components that consume the color scheme directly could therefore enter white-on-white or low-contrast states.

Fixed:
- `onPrimary` -> `DesignTokens.darkBackground`
- `onSecondary` -> `DesignTokens.darkBackground`

The existing dark button styling remains unchanged.

### THEME-02 — Theme-aware glass surfaces

`GlassCard` used the legacy dark-only `DesignTokens.glassCardColor`. It now uses `DesignTokens.glassCardColorOf(context)` while preserving the existing theme-aware border.

### THEME-03 — Legacy Discover controls

`DiscoverTabIndicator` and `DiscoverSearchBar` used legacy dark-default values (`surface`, `textPrimary`, `textSecondary`, `borderColor`, `cardShadow`). They now resolve all neutral surfaces/text/borders through their context-aware equivalents.

Deliberate white text/icons on the orange selected gradient are retained because those are semantic contrast colors, not theme bugs.

### THEME-04 — Shared profile header

`ProfileHeader` mixed theme-aware card framing with dark-default text, button surfaces and borders. All neutral UI values now come from `surfaceOf`, `textPrimaryOf`, `textSecondaryOf` and `borderColorOf`.

Black image overlays and white avatar/gradient foregrounds are intentionally retained because they are image/brand contrast treatments and must not invert with theme.

## Repository-wide audit rules used

The following are considered defects when used for neutral UI without an explicit semantic reason:
- `DesignTokens.textPrimary`
- `DesignTokens.textSecondary`
- `DesignTokens.surface`
- `DesignTokens.borderColor`
- `DesignTokens.glassCardColor`
- fixed `Colors.black` text on a theme-controlled surface
- fixed `Colors.white` surface/text on a theme-controlled surface

The following are not automatically defects and were retained where appropriate:
- white foregrounds on orange/purple/green gradients
- white foregrounds on photographs with dark overlays
- black translucent shadows and image overlays
- semantic success/error/warning colors
- explicit light/dark branches where both states are handled

## Legacy / hidden UI

Search also finds older V1/V2, Quest and CoCircle widgets that still contain dark-default token aliases. These surfaces are not part of the current Android MVP navigation and overlap with the separate dead-code/obsolete-UI cleanup audit. They are intentionally not cosmetically modernized in this release wave until that cleanup decides whether to delete them. This avoids spending release risk on code that may be removed.

Examples include older `bmi_card_v2`, `streak_card_v2`, early Discover content-card variants, and hidden CoCircle/Quest presentation widgets.

## Cursor/local sync

Cursor should pull `security/pre-release-hardening` and preserve these changes exactly. It should not manually recreate or reinterpret the theme fixes. After syncing, local release verification should include:

1. `flutter analyze`
2. `flutter test`
3. Run Android in forced Light mode and forced Dark mode.
4. Check Client, Trainer and Nutritionist shells.
5. Check auth/onboarding, Discover, Messages, Meals, Profile/Settings, Video Sessions, notifications, Insights/BMI and partner-centre/member-pass flows.
6. Specifically inspect Material focus/pressed/selected/disabled states and modal/bottom-sheet contrast.

## Release status

Theme source audit: FIXED / RECORDED for production-reachable and shared theme infrastructure.

Device visual verification: PENDING local Android run. A source audit cannot prove pixel-level contrast, system font rendering, keyboard overlays, OEM navigation bars or every runtime state without running the app.
