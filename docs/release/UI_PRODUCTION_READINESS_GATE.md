# Cotrainr UI Production Readiness Gate

Status: MANDATORY FOR RELEASE SIGN-OFF
Branch: security/pre-release-hardening
Platform priority: Android first

This document consolidates the final UI/UX checks required before a screen can be considered production-ready. It supplements:
- `UI_10_STATE_AUDIT.md`
- `RESPONSIVE_OVERFLOW_AUDIT_RULE.md`
- `PRIMARY_TABS_UI_UX_DATA_AUDIT.md`

## Mandatory release checks for every reachable screen

### 1. State correctness
Classify every applicable screen/component for:
- Default / normal
- Initial loading
- Refreshing / reloading
- Empty
- Error
- Retry / recovery
- Success
- Disabled / unavailable
- Partial / degraded / cached
- Offline / slow / interrupted

Never present unknown/failed data as an authoritative zero, empty list or success state.

### 2. Duplicate-state / duplicate-work audit
Check for:
- double loading circles
- spinner + skeleton for the same responsibility
- pull-to-refresh plus initial-load skeleton at the same time
- duplicate network/RPC fetches
- duplicate realtime reloads
- duplicate rendered rows/cards
- duplicate CTA/navigation firing
- repeated initialization work

One responsibility should have one dominant loading/refresh treatment.

### 3. Responsive / overflow safety
All requirements in `RESPONSIVE_OVERFLOW_AUDIT_RULE.md` are mandatory, including 320dp width, large text, keyboard, SafeArea, navigation bars, long content and tablet-width safety.

### 4. Visual hierarchy
Verify:
- one obvious primary action per task/screen where applicable
- secondary actions visually subordinate
- destructive actions visually distinct
- headers/section titles/body/meta hierarchy is consistent
- critical data is visually stronger than explanatory metadata
- cards do not compete equally for attention without priority

### 5. Spacing and component consistency
Verify shared conventions for:
- page horizontal margins
- section spacing
- card padding
- corner radius
- button heights
- search fields
- chips
- tabs
- bottom sheets
- loaders
- error/empty states
- icon sizes

Do not create one-off visual patterns when an existing shared component can be used safely.

### 6. Typography
Rules:
- body typography follows the app theme unless a deliberate display style is documented
- Montserrat may be used for intentional page/display headers
- avoid accidental font-family mixing within one hierarchy
- important metadata should not fall below about 11-12sp on mobile
- do not use FittedBox to silently shrink essential text below readable size
- large Android font scale must remain functional
- long dynamic text must wrap or ellipsize deliberately

### 7. Color / contrast / theming
Verify in light and dark mode:
- primary and secondary text contrast
- disabled-state contrast
- selected/unselected control contrast
- destructive/error colors
- success colors
- chip/badge readability
- icon contrast on image covers
- status/navigation bar icon contrast
- no hardcoded light-only/dark-only colors on adaptive surfaces

### 8. Interaction quality
Every interactive element must have appropriate:
- pressed state
- focused state
- selected state where applicable
- disabled state
- loading/busy state
- duplicate-tap protection for async actions
- minimum effective Android touch target around 48x48
- correct haptic use only where action/selection actually occurs

Decorative elements must not animate/haptic like buttons.

### 9. Navigation context
Check:
- root screens do not show unnecessary back arrows
- detail/modal screens do provide a usable back path
- Android system/predictive back behaves correctly
- deep links have safe fallback behavior
- no duplicate pages from rapid navigation
- modal vs full-page presentation is consistent with task depth
- back while async work is in flight cannot corrupt state

### 10. Form UX
For every form/input flow verify:
- clear label/hint
- correct keyboard type
- correct text capitalization
- autofill where applicable
- password visibility semantics
- focus order
- keyboard Next/Done behavior
- validation placement and readable copy
- errors clear or update after correction
- submit button busy/disabled state
- keyboard does not hide focused input/CTA
- partially entered data is not accidentally lost on benign navigation

### 11. Destructive action safety
Actions such as delete, disconnect, cancel, reject, end connection, sign out and account deletion must have:
- confirmation where consequence is material
- correct wording describing actual consequence
- busy/disabled state during request
- success state
- failure state with retry/recovery
- no optimistic UI that becomes false if persistence failed
- Undo only when server semantics actually support undo

### 12. Data truthfulness
UI must distinguish:
- zero
- unavailable
- not loaded
- failed
- empty
- stale/cached

Examples:
- `0 steps` is not the same as `Health Connect unavailable`.
- `No centres` is not the same as centre RPC failure.
- `No messages yet` is not the same as no search matches.
- previous-day meal data must never be labelled as the newly selected date.

### 13. Perceived performance
Verify:
- skeletons only when there is no usable prior content
- refresh preserves healthy existing content where possible
- content does not flash from real data -> zero -> real data
- no avoidable layout jumps
- image placeholders preserve dimensions
- large list entrance animation does not delay interaction
- realtime bursts do not trigger visible repeated refreshes

### 14. Motion discipline
Verify:
- decorative animation respects `MediaQuery.disableAnimationsOf(context)`
- pressed feedback remains immediate
- no animation restarts unnecessarily on every rebuild/scroll
- list stagger is capped
- long animation chains are avoided
- navigation transitions remain consistent
- reduced-motion layout remains spatially identical

### 15. Accessibility
Verify:
- TalkBack reading order
- icon-only controls have semantic labels/tooltips
- selected/expanded/disabled states are exposed
- unread counts/status are not conveyed only by color/dots
- minimum touch targets
- large text
- reduced motion
- meaningful error/retry announcements
- image/avatar semantics where useful

### 16. Image / media states
Every user/remote media surface should deliberately support:
- loading placeholder
- error fallback
- cached image
- broken URL
- local file path failure
- upload progress when uploading
- retry if upload fails
- aspect-ratio preservation
- no layout jump when image resolves

### 17. Scroll / content density
Verify:
- no accidental nested-scroll conflicts
- pinned headers do not overlap content
- no unreachable first/last item
- no excessive dead space on small phones
- no excessive full-width stretching on tablets
- bottom navigation/FAB/CTA does not cover content
- long screens remain scannable and section hierarchy is clear

### 18. State persistence
Where appropriate preserve:
- selected primary tab
- search query
- filters
- scroll position
- chosen date
- unsaved form draft
- selected clients/participants

Do not preserve sensitive transient state longer than needed.

### 19. Localization resilience
English is sufficient for MVP unless product scope changes, but layouts must survive:
- long names
- longer backend copy
- longer status labels
- accessibility text expansion
- non-fixed-width CTA labels

Do not hardcode Row widths around current English strings when content is dynamic.

### 20. System UI / Android integration
Verify:
- edge-to-edge drawing
- status bar icon contrast
- navigation bar contrast
- display cutout/notch safety
- gesture navigation
- 3-button navigation
- keyboard/IME insets
- Android predictive back
- permissions returning from system settings

## Primary-tab scorecard

Legend:
- PASS = code structure is broadly correct; final device/visual validation still required where stated.
- FIX = known code/UX defect exists and is recorded for correction.
- LOCAL VERIFY = behavior cannot be fully signed off without emulator/physical-device testing.

| Area | Home | Discover | Meal Tracker | Messaging | Profile |
|---|---|---|---|---|---|
| 10-state handling | FIX | FIX | FIX | FIX | FIX |
| Duplicate loaders/work | FIX | FIX | FIX | FIX | FIX |
| Data truthfulness | FIX | FIX | FIX | PASS/FIX search-state | FIX |
| Responsive/overflow | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY |
| Typography | FIX minor | PASS/LOCAL | PASS/LOCAL | PASS/LOCAL | PASS/LOCAL |
| Color/theme | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY |
| Motion/reduced motion | FIX | FIX | FIX | PASS AFTER SHARED FIX | FIX/LOCAL |
| Accessibility | FIX | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY |
| Interaction quality | FIX | PASS/FIX | PASS/FIX | PASS/FIX | PASS/LOCAL |
| Perceived performance | FIX | FIX | FIX | FIX | FIX |
| State persistence | PASS/LOCAL | PASS/LOCAL | FIX date race | PASS/LOCAL | PASS/LOCAL |
| Image/media states | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY | LOCAL VERIFY |

## Primary-tab current release blockers / major fixes

### Home
- isolate optional metrics refresh failures from other Home refresh work
- provider goals must not remain in permanent skeleton after failure
- deduplicate/consolidate HealthTrackingService initialization
- avatar/streak must be real actions or non-interactive decoration
- notification bell needs proper 48x48 semantic target
- metric metadata/readability/reduced-motion cleanup

### Discover
- separate initial loading from pull refresh so RefreshIndicator and skeleton do not stack
- centre-specific load failure must not become genuine empty state
- cap list entrance stagger and respect reduced motion
- final narrow-width/large-text/long-content verification

### Meal Tracker
- request-version selected-date loads to prevent stale response overwrite
- add authoritative initial day-loading/error/retry state
- separate real zero-food day from not-loaded state
- add goals error handling
- ensure reduced-motion for ring/page transitions
- verify pinned headers/sheets/keyboard on small devices

### Messaging
- distinguish real empty inbox from search-no-match state
- coalesce realtime INSERT/UPDATE reloads
- physical verification of row overflow, TalkBack and chat keyboard/composer
- shared list fade reduced-motion support is already fixed

### Profile
- eliminate duplicate profile fetch during `_loadAll()`
- separate initial profile skeleton from pull-refresh state
- stop swallowing hub/profile errors as zero/placeholder values
- add degraded/error/retry presentation
- verify long labels/cards and large text

## Visual regression requirement
Before Android production sign-off capture or inspect the five primary tabs in at least:
- light mode / normal text
- dark mode / normal text
- narrow 320dp-class width
- normal 360dp-class width
- large accessibility text
- at least one loading/error/empty state per primary tab

Compare for:
- spacing drift
- text clipping
- inconsistent font/radius/icon sizing
- color/contrast regressions
- bottom navigation overlap
- skeleton/content layout jump

## Final UI sign-off rule
Core UI cannot be marked 100% until:
1. known FIX items are implemented,
2. `flutter analyze` passes touched code,
3. relevant tests pass,
4. responsive/device matrix is exercised,
5. no RenderFlex/layout exceptions occur,
6. TalkBack and large-text spot checks pass,
7. light/dark visual regression pass is complete,
8. every remaining issue is explicitly recorded as CURSOR / LOCAL ACTION REQUIRED rather than silently accepted.
