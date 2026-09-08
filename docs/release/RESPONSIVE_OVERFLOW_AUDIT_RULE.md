# Cotrainr Responsive / Overflow Release Audit Rule

Status: MANDATORY FOR ALL REMAINING UI AUDITS
Branch: security/pre-release-hardening
Platform priority: Android first

This is a permanent extension of the Cotrainr UI release gate. No screen may be signed off only because it looks correct on one phone size.

## Required responsive checks for every reachable release screen

Each screen/component must be classified PASS / FIXED BY ME / CURSOR-LOCAL REQUIRED / NOT APPLICABLE for the applicable items below.

1. No RenderFlex overflow, yellow/black overflow stripes, clipped controls, clipped cards, or text painted outside bounds.
2. Width adaptation on narrow phones. Required code/device targets: about 320dp, 360dp, 393-412dp and a wider phone class.
3. Height adaptation on short screens and tall screens. No bottom CTA, sheet action, or critical content may become unreachable.
4. Large text / font scaling. Verify at normal scale and at least one high Android accessibility font scale. Text must wrap, ellipsize only where information loss is acceptable, or allow the container to grow.
5. Keyboard open state. Forms, search, dialogs and bottom sheets must remain usable with IME visible; focused inputs and primary actions must not be permanently hidden.
6. System insets / SafeArea. Verify status bar, gesture navigation, 3-button navigation, display cutout/notch where available, and bottom inset handling.
7. Bottom navigation overlap. Scroll content, floating controls, snackbars, sheets and bottom CTAs must not sit under the floating Home navigation bar.
8. Orientation. Portrait is the release-critical orientation. If landscape is not product-supported, it must still fail safely without crashes/overflow; otherwise make it adaptive.
9. Tablet / large-width safety. Even if Android phone is launch target, layouts must not stretch destructively on larger widths. Prefer centered/max-width content where a full-width card becomes visually excessive.
10. Image adaptation. Cover/avatar/food/centre/provider images must preserve aspect ratio using appropriate BoxFit and must have loading/error fallbacks without layout jumps.
11. Dynamic lists. Long names, usernames, centre names, specialties, messages, food names, notification bodies and translated/expanded strings must not overflow fixed Rows.
12. Fixed-size widgets. Any fixed height/width must be justified and tested with large text. Avoid fixed-height text containers where content can expand.
13. Sheets/dialogs. Use isScrollControlled / scrollable content where needed. Verify keyboard + small-height combinations.
14. Pinned headers/slivers. Verify no overlap, jump, duplicate pinned area, or inaccessible first/last list item.
15. Touch targets after adaptation. Responsive compression must never shrink important controls below roughly 48x48 effective Android touch area.
16. Loading/error/empty states themselves must be responsive; not just the happy path.
17. Reduced-motion layouts must remain identical spatially when entrance animations are skipped.
18. RTL/very long text is not a launch localization requirement unless enabled, but Rows must not assume short labels where backend/user content can be long.

## Primary-tab high-risk areas already identified

### Home
- `HeroHeaderV3` uses a fixed 158px cover height and an 86px avatar. Verify 320dp width + large text so `Welcome back`, username, avatar and notification control do not collide.
- Home metrics contain 9-11sp metadata and `FittedBox`; prevent text shrinking below readable size and verify no metric label/ring/chart collision on 320dp width.
- Floating bottom navigation requires at least the existing bottom content spacer; verify final Home cards and snackbars are not obscured with gesture and 3-button navigation.
- Provider client summary must handle long client names and large counts without Row overflow.

### Discover
- Search field + filter control + segmented tabs are high-risk on narrow width and high font scale.
- Provider cards must handle long names, headlines, specialties, location strings and request-button labels without overflow.
- Empty/error/loading skeleton states must fit short screens.
- Cap entrance animation separately from layout; animation must not mask or create temporary overflow.

### Meal Tracker
- Two pinned headers (page header + day navigator) must be checked on small-height devices and large text for overlap.
- Daily summary macro rows/rings and meal tiles must wrap or adapt at 320dp.
- Reorderable meal tiles, add-food controls and long custom meal names need overflow protection.
- Calendar/dialog/bottom sheets must remain scrollable with keyboard visible.
- 140px bottom spacer must be validated against Home floating nav on gesture and 3-button navigation.

### Profile
- Goal/stat Wrap is structurally safer, but verify large text and long goal labels.
- Action rows must not clip subtitles/labels.
- Verification/professional cards need small-width and large-text checks.
- Preserve current profile during refresh; skeleton + refresh indicator must not produce vertical jump that exposes content under the nav.

### Messaging
- Search field, conversation row name/preview/time/unread badge combination is high-risk on 320dp and large text.
- Conversation preview should truncate before timestamp/unread badge is pushed offscreen.
- Empty/search-empty/error states need short-height scrollability.
- Keyboard behavior in ChatScreen belongs to the Messaging detailed audit: composer must stay above IME, attachments/sheets must not overflow, message bubbles must max-width responsively.

## Local/device matrix required before Android release sign-off

At minimum verify on emulator/physical configurations representing:
- 320 x ~568dp-class small phone
- 360 x ~800dp-class common Android
- 393/412 x tall modern Android
- one large-width phone/foldable or tablet-width emulator
- normal font scale
- large accessibility font scale
- gesture navigation
- 3-button navigation
- keyboard open in all input-heavy screens
- light mode and dark mode
- reduced motion enabled

## Acceptance gate

A screen is not release-complete until:
- Flutter logs show no RenderFlex/overflow/layout exceptions during tested flows;
- no critical content/control is clipped or unreachable;
- no bottom-nav/IME/system-inset overlap exists;
- long real-world data and large text remain readable;
- loaders/errors/empty/success states are as adaptive as the normal state;
- any unresolved issue is recorded as CURSOR / LOCAL ACTION REQUIRED with exact screen, condition, expected behavior and verification steps.

This rule applies to all previously audited screens during final device verification and to every UI audit from this point forward.