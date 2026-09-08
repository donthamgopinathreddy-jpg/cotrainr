# Cotrainr Primary Tabs UI / UX / Data Audit

Status: IN PROGRESS
Branch: security/pre-release-hardening
Scope: Home (client/trainer/nutritionist), Discover, Meal Tracker, Profile, Messaging.

This audit extends the mandatory 10-state rule. In addition to default/loading/refreshing/empty/error/retry/success/disabled/degraded/offline states, every primary tab is checked for duplicate loading indicators, duplicate refresh/data work, duplicate visual elements, stale or misleading data, typography, color/contrast, motion, interaction feedback, accessibility and simple release-safe UX corrections.

## Global rules for the five primary tabs

1. A pull-to-refresh must have one dominant refresh treatment. Do not show the RefreshIndicator and simultaneously replace healthy existing content with an initial-load spinner/skeleton unless the content truly became unusable.
2. Initial loading and refreshing are separate states. Initial loading may use skeletons; refreshing should normally preserve usable content and show only the pull indicator or a small local progress state.
3. A failed fetch must never be rendered as an authoritative zero, empty list, or default value when the app does not know the real value.
4. Async requests triggered by rapid date/tab/search/filter changes must be request-versioned/cancelled so an older response cannot overwrite the newest selection.
5. Realtime events that can occur in pairs (for example message INSERT plus conversation UPDATE) must coalesce/debounce full-list reloads.
6. Interactive-looking controls must perform an action. Decorative items must not animate like buttons.
7. Important icon-only controls need Semantics/tooltip and at least a 48x48 effective touch target.
8. Respect MediaQuery.disableAnimationsOf(context). Decorative entrance/stagger/ring/scale animations should become instant or minimal when reduced motion is enabled.
9. Body typography follows the app Poppins theme; Montserrat is acceptable for deliberate display/page headers. Plus Jakarta Sans on Home is a deliberate exception only if retained as a documented Home brand style. Do not mix fonts accidentally within the same hierarchy.
10. Avoid metadata below 11-12sp on mobile. FittedBox must not silently shrink important text below readable size.

## Shared fix completed by audit

### Reduced-motion support for shared Messaging/list fades — FIXED BY ME
File: `lib/widgets/common/fade_slide_in.dart`

Problem:
- `FadeSlideIn` and `ContentFade` always animated even when Android accessibility reduced-motion/disable-animations is enabled.

Fix:
- Read `MediaQuery.disableAnimationsOf(context)`.
- Use zero-duration transitions when reduced motion is enabled.
- Skip translation/fade work in `FadeSlideIn` under reduced motion.
- Use zero-duration `AnimatedSwitcher` in `ContentFade` under reduced motion.

Commit: `dc58e0db2e7c07d6b4511fe910051a051a5d330a`.

## Home — Client / Trainer / Nutritionist

### What is already good
- Client Home has section-specific profile and metrics errors with Retry rather than one whole-page failure.
- Health values use availability-aware display (`—`) for unavailable platform metrics rather than blindly showing zero in the primary metric values.
- Pull-to-refresh preserves the page rather than replacing the whole page with a screen loader.
- Trainer/Nutritionist client summary already uses skeletons, empty copy, Semantics, pressable cards and meaningful 44-48px targets.
- Existing metric/goals content remains visible during refresh, which avoids a second page loader.

### MAJOR — refresh chain can abort on one metrics sync failure
Files:
- `lib/pages/home/home_page_v3.dart`
- `lib/pages/trainer/trainer_home_page.dart`
- `lib/pages/nutritionist/nutritionist_home_page.dart`

Current pattern:
- `_onRefresh()` awaits `metricsSyncServiceProvider.syncNow()` before the remaining refresh work.
- Trainer/Nutritionist use the same pattern.

Impact:
- Offline/Health/DB sync failure can prevent profile/goals/streak/coaching/event/session/client-count refresh work from running.
- One optional subsystem therefore blocks unrelated Home recovery.

CURSOR / LOCAL ACTION REQUIRED:
- Wrap metrics sync in its own try/catch and continue with independent refresh tasks.
- Run independent refreshes with guarded futures so one rejection does not cancel the rest.
- Preserve a metrics-specific error/retry surface rather than turning the whole Home refresh into a failure.
- Do not reset good cached content to zero on failure.

Acceptance:
- Pull refresh offline completes visually and leaves cached Home usable.
- Profile refresh can succeed when metrics sync fails.
- Metrics failure is local to metrics.
- No uncaught Future from RefreshIndicator.

### MAJOR — provider goal load lacks an error boundary
Files:
- trainer/nutritionist Home `_loadGoals()`.

Current behavior:
- Goal calls are awaited without try/catch.
- `_goalsReady` may remain false indefinitely after an exception, leaving a permanent metrics skeleton.

Required:
- Catch goal-load failure.
- Distinguish unavailable goals from loading.
- Either retain last known goals or show a local goal error/retry state.
- Never leave a permanent loading skeleton after the request has failed.

### MAJOR — repeated HealthTrackingService initialization can run concurrently
Files:
- `lib/providers/health_tracking_provider.dart`
- Home pages
- `lib/services/health_tracking_service.dart`

Confirmed call sites:
- provider factory calls `service.initialize()`;
- `DailyMetricsNotifier._initialize()` calls `initialize()` again;
- each Home page calls `healthTrackingServiceProvider.initialize()` again post-frame.

`HealthTrackingService.initialize()` is idempotent only after `_isInitialized` becomes true; there is no in-flight Future lock. Multiple calls arriving before completion can enter initialization concurrently.

Risk:
- duplicate Health Connect configuration/permission work;
- unnecessary startup work;
- possible duplicated permission UX/races.

CURSOR / LOCAL ACTION REQUIRED:
- Add an in-flight initialization Future/mutex in `HealthTrackingService` OR choose exactly one startup owner and remove redundant callers.
- Preserve singleton behavior and explicit reinitialize/connect semantics.

Acceptance:
- concurrent callers await the same initialization Future;
- one OS permission/configure sequence per initialization cycle;
- no repeated permission dialog from Home/provider/notifier races.

### MAJOR — Home hero contains interactive-looking elements with no useful action
File: `lib/widgets/home_v3/hero_header_v3.dart`

Confirmed:
- avatar has press-down scale animation but no `onTap` action;
- streak badge has press animation and haptic only; it performs no navigation/action;
- notification icon is a 24px GestureDetector without explicit Semantics/tooltip/minimum target.

Required UX correction:
- Either make avatar open Profile and streak open the relevant streak/progress view, OR remove press animation/haptic and render them as non-interactive decoration.
- Convert notification control to an accessible IconButton/InkResponse or equivalent 48x48 semantic target.
- Semantics should announce notification status when unread count > 0.

### MINOR / ACCESSIBILITY — Home metrics typography can become too small
File: `lib/widgets/home_v3/unified_metrics_tile_v3.dart`

Confirmed sizes include 9-10sp source-note text and 11sp secondary text, some inside `FittedBox` which can shrink further.

Required:
- Treat 11-12sp as practical minimum for readable metadata.
- Avoid FittedBox shrinking source/metric labels below the intended minimum; prefer ellipsis/flexible layout.
- Verify contrast for secondary text at alpha 0.75 in light and dark modes.

### Motion
- Home page/hero/metric animations do not consistently use reduced-motion state.
- Do not remove useful pressed feedback; only suppress decorative entrance/carousel/ring motion when accessibility motion reduction is enabled.

## Discover

### Good
- Explicit initial skeleton state.
- Explicit whole-load error state and retry.
- Search/filter-specific empty states are differentiated from genuine no-provider state.
- Location-unavailable browsing degrades gracefully instead of blocking all results.
- Provider request actions track submitting providers, which prevents duplicate request/cancel taps.

### MAJOR — double refresh UI
File: `lib/pages/discover/discover_page.dart`

Confirmed:
- `RefreshIndicator.onRefresh` calls `_loadRealData()`.
- `_loadRealData()` sets `_isLoading = true`, clears providers/centres, and the build swaps content for `_DiscoverLoadingHeader` + four skeleton cards.

Impact:
- pull-to-refresh shows the Android refresh spinner AND replaces all current content with initial-load skeletons.
- current usable data disappears unnecessarily.

CURSOR / LOCAL ACTION REQUIRED:
- Add `showLoading`/refresh mode or separate `_initialLoading` and `_refreshing` state.
- Initial open: skeletons are correct.
- Pull refresh: preserve current cards and use only RefreshIndicator; update atomically when new data arrives.
- On refresh failure, preserve old cards and show non-destructive error/snackbar/banner.

### MAJOR — partner centre fetch failure is silently converted to a real empty state
Confirmed inner catch around `listForDiscover()` leaves `_centers` empty and continues.

Impact:
- user can see `No Partner Centres yet` even when centres actually exist but the RPC/network failed.

Required:
- track a centre-specific error/degraded flag;
- if providers succeed but centres fail, preserve provider tabs and show a centre-only Retry/error state when Centers is selected;
- do not label backend failure as genuine zero centres.

### MINOR — list entrance animation grows with item index and ignores reduced motion
Confirmed duration: `260 + (index * 60)` ms.

Impact:
- later rows can animate for unnecessarily long durations;
- every newly built offscreen row repeats entrance motion;
- reduced-motion setting is ignored.

Required:
- cap stagger (for example only first 3-4 rows or max ~420ms total);
- disable decorative list entrance when `MediaQuery.disableAnimationsOf(context)` is true.

### UX suggestion
- When search text alone yields zero results, keep the `Clear search` wording rather than generic `Clear filters` unless filters are actually active.
- Preserve search query and selected tab during background refresh.

## Meal Tracker

### Good
- Pull-to-refresh exists.
- write actions generally use success/error SnackBars and persistence before final success feedback.
- add/update/delete food mutations recompute totals.
- custom meal duplicate names are prevented.
- date/calendar and meal interactions use haptic feedback.

### BLOCKER/MAJOR DATA PRESENTATION — selected-date race and stale-day display
File: `lib/pages/meal_tracker/meal_tracker_page_v2.dart`

Confirmed:
- `_selectDate()` updates `_selectedDate` immediately and then launches `_loadDayData()`.
- `_loadDayData()` reads mutable `_selectedDate` and has no request generation/token.
- rapid day taps can have overlapping requests; an older slower request can apply after the newer one.
- while the new date is loading, the previous day's meals/totals remain visible under the newly selected date.
- on failure, only a SnackBar is shown; stale prior-day data can remain under the selected failed date.

CURSOR / LOCAL ACTION REQUIRED:
- capture requested date at call time: `_loadDayData(DateTime requestedDate)`.
- increment a request generation or compare requestedDate to current selection before applying response.
- add `_dayLoading` and `_dayError` states.
- while switching dates, never label prior-day data as the new date. Use a compact skeleton/disabled content state or preserve old data only with an explicit `Updating…` overlay that cannot be mistaken for the selected date.
- on failure, show an inline Retry for the selected date; do not leave stale data appearing authoritative.

Acceptance:
- rapidly tap Previous/Next 5-10 times; final displayed totals/meals always match final selected date.
- forced slow network cannot allow old response to overwrite newer date.
- failed selected date clearly shows unavailable/error, not previous date's values.

### MAJOR — no deliberate initial day-loading state
- goals/totals start at defaults/zero while async loads run.
- this makes a real zero-food day indistinguishable from `not loaded yet`.

Required:
- initial day skeleton/loading state for summary + meals;
- separate goals loading from day-data loading;
- only show authoritative 0 calories/0 macros once the day fetch succeeded and returned empty.

### MAJOR — `_loadGoals()` has no error boundary
- an exception can become an uncaught async failure from init/refresh.
- add error handling and retain last known/default goals with a visible degraded state where appropriate.

### Double loading
- Current pull-to-refresh does NOT intentionally create a second page spinner, which is good.
- After adding `_dayLoading`, make sure refresh does not show both RefreshIndicator and initial skeletons; only date changes/initial load should use day skeletons.

### Motion/accessibility
- ring animation (650ms), page fade and date-change animation ignore reduced-motion.
- make decorative ring/fade instant under disableAnimations while preserving direct interaction feedback.

## Profile

### MAJOR — duplicate profile fetch on every initial load and refresh
File: `lib/pages/profile/profile_page.dart`

Confirmed:
- `_loadAll()` runs `Future.wait([_loadProfile(), _loadHubData()])`.
- `_loadProfile()` calls `_profileRepo.fetchMyProfile()`.
- `_loadHubData()` independently calls `_profileRepo.fetchMyProfile()` again.

Impact:
- two identical profile requests in parallel;
- avoidable DB/RPC cost and inconsistent snapshot risk if one returns later.

CURSOR / LOCAL ACTION REQUIRED:
- fetch profile once in `_loadAll()` and pass the snapshot to the identity + hub-data loaders, OR cache one in-flight request.
- verification status may remain a separate request.

Acceptance:
- one profile RPC/request per initial page load/pull refresh.
- identity, role, BMI/weight calculations use the same snapshot.

### MAJOR — pull refresh can show double loading representation
Confirmed:
- RefreshIndicator is active during `_loadAll()`.
- `_loadProfile()` immediately sets `_isLoadingProfile = true`, causing the identity area to switch back to its loading state/skeleton while the refresh indicator is also visible.

Required:
- separate initial load from refresh (`_hasLoadedProfile` / `_refreshing`).
- preserve current identity during pull refresh; only use skeleton on first load when no profile is available.

### MAJOR — errors are swallowed and can look like real zero/empty data
Confirmed catches in `_loadProfile`, `_loadVerificationStatus`, `_loadHubData` are empty.

Impact examples:
- weekly steps can remain `0`;
- water can remain `0%`;
- calorie target can remain `—`/0;
- username may remain loading/fallback;
without telling the user whether these are real or unavailable.

Required:
- add section-level degraded/error state and Retry.
- never label failed progress loads as authoritative zero.
- preserve prior good values during refresh failures.

### Typography/interactions
- primary Profile actions use shared Hub components and are structurally consistent.
- verify every action row has pressed/focus semantics through the shared PressableCard/Hub components during device pass.
- keep page-level display typography consistent with the existing Account Hub design; do not add another font family.

## Messaging

### Good
- explicit initial loading circle.
- explicit error + Retry.
- pull-to-refresh calls `_loadConversations(showLoading: false)`, so it avoids a second full-page loading spinner.
- conversation IDs are de-duplicated before rendering.
- newest activity ordering is reasserted locally.
- stale unread badge is refreshed after chat return.
- reduced-motion support in shared `FadeSlideIn`/`ContentFade` has now been fixed by this audit.

### MAJOR UX — search-empty state is mislabeled as an empty inbox
Confirmed:
- `_filteredConversations.isEmpty` always renders `No messages yet` and `Your conversations ... will appear here.`
- this is also used when `_allConversations` has chats but the search query has no match.

CURSOR / LOCAL ACTION REQUIRED:
- if search query is non-empty and `_allConversations` is non-empty, show `No conversations found` + `Try another name` and a Clear search action.
- reserve `No messages yet` for a genuinely empty conversation collection.

### MAJOR PERFORMANCE/REFRESH — realtime events can trigger duplicate full-list reloads
Confirmed architecture:
- MessagingPage subscribes to conversation UPDATE and separately to message INSERT/UPDATE.
- both callbacks call `_loadConversations(showLoading: false)`.
- normal message delivery can cause message INSERT and a conversation `last_message_at` UPDATE, resulting in two near-simultaneous full conversation reloads.

Required:
- coalesce/debounce realtime reloads (small 100-250ms window) OR use a single queued `_reloadInFlight` + `_reloadPending` mechanism.
- do not allow concurrent full conversation fetches.
- keep unread invalidation coalesced with the final reload.

Acceptance:
- one incoming message results in at most one effective rendered-list refresh cycle.
- burst of messages does not start N overlapping `fetchConversations()` operations.
- newest message/order/unread remains correct.

### DATA/PERFORMANCE — conversation fetch is N+1 heavy
Repository currently fetches per conversation:
- last message;
- unread IDs/count;
- other participant public profile.

This is not a UI correctness blocker for a small MVP list, but combined with duplicate realtime reloads it can create visible refresh latency and battery/network cost.

POST-LAUNCH or backend optimization:
- replace with one server RPC/view returning conversation preview + unread count + counterpart fields, after RLS/security review.
- Do not optimize this by weakening RLS or exposing private profile fields.

### Interaction/accessibility
- search field has focused border and clear button.
- verify ConversationTile provides one semantic button label including counterpart + unread count + preview; if not, add it locally.
- ensure rapid double tap cannot push the same ChatScreen twice before first navigation begins.

## Duplicate-element / duplicate-loader verdict

Confirmed real duplicates to fix:
1. Profile: duplicate `fetchMyProfile()` request.
2. Discover refresh: RefreshIndicator + initial skeleton replacement simultaneously.
3. Profile refresh: RefreshIndicator + identity initial-loading state simultaneously.
4. Messaging realtime: potentially two full reloads for the same logical incoming message event.
5. Health/Home startup: multiple concurrent calls to the same HealthTrackingService initialization path.

Not currently considered a harmful duplicate:
- Home hero username shimmer plus remote avatar image placeholder: these represent two independently loading resources, not the same operation. The avatar placeholder should preferably be a static/skeleton placeholder rather than another prominent circular spinner if visual testing feels busy.
- Home RefreshIndicator plus section-level error cards: valid, because the errors are persistent states rather than simultaneous loaders.

## Easy release-safe UX improvements

Priority A (before release):
- Discover refresh preserves cards instead of swapping to skeletons.
- Meal date loading becomes request-versioned and never displays stale prior-day data as the new day.
- Profile stops duplicate fetch and stops presenting failed values as real zeros.
- Messaging distinguishes search-no-result from no-conversations.
- Home hero icon/press affordances become real actions or non-interactive decoration.
- coalesce Messaging realtime reloads.

Priority B (polish, low risk):
- cap Discover stagger animation and respect reduced motion.
- respect reduced motion in Home/Meal/Profile decorative animations.
- increase Home metric source-note text to readable minimum.
- replace tiny avatar network circular loader with a neutral skeleton/static placeholder if physical testing shows excessive simultaneous spinners.

## Cursor execution instruction

Implement the Priority A items as narrowly as possible. Do not redesign the visual identity, change product behavior, alter subscription/connection rules, or change backend authorization while fixing UI states. Preserve existing colors unless a contrast issue is proven. Run `dart format` on touched files and `flutter analyze`; then device-test light/dark, large text, TalkBack, offline/slow network, rapid repeated taps, and pull-to-refresh.

Do not mark any Cursor item fixed until the code is pulled into `security/pre-release-hardening` and verified.
