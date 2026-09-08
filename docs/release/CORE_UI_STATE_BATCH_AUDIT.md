# Cotrainr Consolidated Core UI State Audit

Status: IN PROGRESS
Branch: security/pre-release-hardening
Scope: Primary Android MVP UI surfaces audited together using the mandatory 10-state rule.

## Mandatory states
Default/normal; loading; refreshing; empty; error; retry; success; disabled/unavailable; partial/degraded/cached; offline/slow/interrupted.
Cross-cutting: pressed/selected/focus, keyboard, duplicate action prevention, back/navigation during work, stale data, destructive actions, permissions, small viewport/large text, light/dark, reduced motion, TalkBack/touch targets, role-specific visibility.

## Already audited earlier
01.01 Splash/Welcome — CODE PASS; local visual/device verification remains.
01.02 Login — CODE PASS AFTER FIX; local device/accessibility verification remains.
01.03 Signup Wizard — OPEN / CURSOR-LOCAL: lock Android/system back during final submission and after All Set.
01.04 Permissions — CODE PASS AFTER FIX; OPEN policy/device: Health Required vs Skip consistency, lifecycle refresh from Settings/Health Connect, Android 13+ photo/files strategy.
01.05 Post-auth/Complete profile/Restricted account — CODE PASS AFTER FIX; local offline/back/accessibility verification remains.
01.06 Home shell/bottom nav — OPEN / CURSOR-LOCAL: bottom-nav semantics/selected state/pressed feedback/unread announcement.
01.07 Client Home — OPEN / CURSOR-LOCAL: refresh must degrade section-by-section instead of aborting on metrics sync failure; streak error boundary; BMI unavailable state; coaching availability state.

## Remaining primary MVP UI surfaces — consolidated pass

### Trainer Home
State coverage present: normal, loading skeleton/name state, pull-to-refresh, empty recent-clients state through ProviderClientsSummary, cached/live metrics, notification/session/provider-practice async data, selected/pressed semantics in shared client summary.
OPEN / CURSOR-LOCAL:
- `_onRefresh()` awaits `metricsSyncServiceProvider.syncNow()` before all other refreshes and has no local error boundary. Offline metrics sync aborts profile/goals/streak/coaching/client/session/event refresh. Match the Client Home degraded-refresh rule: catch metrics sync failure, continue independent refreshes, expose section error only where applicable.
- `_loadGoals()` has no try/catch; a failure can leave goals loading forever and surface an unhandled async error. Add bounded failure state or mark goals unavailable while keeping the screen usable.
- `_loadData()` catches all failure but only clears name loading; it silently retains zero/default metrics/BMI with no explicit data-error state. Do not represent failed provider/profile/metrics fetches as real zero values.
- BMI tap must be disabled or show unavailable guidance when height/weight/BMI are not valid.
- `_safeSection()` currently collapses render failures to `SizedBox.shrink()`, producing unexplained missing UI. Use a compact recoverable section-error surface instead of silent disappearance for release-critical sections.

### Nutritionist Home
Same architecture and same OPEN requirements as Trainer Home:
- isolate metrics-sync failure from whole refresh;
- add goals failure recovery;
- do not silently convert failed profile/metrics loads into zero/default data;
- guard invalid BMI navigation;
- replace silent `_safeSection()` disappearance with explicit degraded state for important sections.

### Provider Clients summary / recent clients
PASS at shared-component level for loading skeleton, empty state, normal state, pressed feedback, semantics, request unread semantic text, next-session state and minimum touch targets.
LOCAL VERIFY: large text, TalkBack reading order, request count changes while screen is visible, next-session long client names.

### Discover / Centres root
Strong coverage exists: initial loading, explicit error message, location-denied/browse degraded state, empty result logic, filtering/search, submitting-provider busy set, request-status states, entitlement unknown/degraded state, provider/centre data separation.
OPEN / CURSOR-LOCAL:
- Partner-centre load failure is swallowed and the Centres tab stays empty. Distinguish `no centres` from `centres failed to load`; provide a retry/degraded message without breaking provider results.
- Location resolution can prompt on page load; physical Android verification must confirm denied/denied-forever/service-off states do not repeatedly prompt and that browse-without-location remains usable.
- Verify filtered-empty copy differs from true-empty copy and gives a clear `Clear filters`/recovery route.
- Verify search/filter controls, tabs and connect/request controls expose selected/busy/disabled semantics and 48dp targets.

### Messaging conversation list
PASS in code for initial loading, explicit load error, Retry CTA, pull-to-refresh, true empty list, search-filtered list, realtime refresh, optimistic unread clear followed by authoritative mark-read/refetch.
OPEN / CURSOR-LOCAL:
- Search-empty currently reuses `No messages yet`; when conversations exist but search has no match, show `No conversations match your search` plus Clear search. Do not misrepresent filtered-empty as account-empty.
- Realtime background refetch failure is not surfaced because `showLoading:false` leaves prior list visible; add a non-destructive degraded indicator/snackbar only if repeated/background refresh fails, while retaining cached conversations.
- Verify clear-search IconButton tooltip/semantics and conversation-tile semantics/pressed state on TalkBack.

### Meal Tracker root
Normal data, date switching, custom-meal empty lists, add-food persistence errors, edit-goals validation/error/success and picker flows exist.
OPEN / CURSOR-LOCAL:
- Initial `_loadDayData()` has no dedicated loading state; zeros/empty meals are visible while DB data is still loading. Add an initial/day-switch loading/skeleton state so real zero intake is distinguishable from not-yet-loaded.
- `_loadDayData()` failure only shows a SnackBar while stale/zero content remains. Add persistent section/day error with Retry; preserve last successfully loaded day as cached data where safe.
- `_loadGoals()` has no error handling and can fail unhandled. Provide goal-unavailable/degraded state rather than silently retaining defaults as if authoritative.
- Date changes can race if user taps days quickly; ensure latest selected-date request wins and older responses cannot overwrite the current day.
- Verify all save/delete/add actions prevent duplicate taps while persistence is in flight and expose success/failure consistently.

### Profile / Account hub
Normal identity, profile loading placeholder, pull-to-refresh, unavailable metrics shown as em dash in several places, provider verification variants and role-specific actions exist.
OPEN / CURSOR-LOCAL:
- `_loadProfile()` swallows errors and renders fallback `Loading...`/`@loading` or stale state without explicit error/retry. Add a persistent profile identity error/degraded state and Retry.
- `_loadHubData()` swallows all errors and leaves zeros/defaults (`0 days`, `0 weekly steps`, `0% water`, etc.) that can be mistaken for real data. Track availability per hub data group and show `—`/unavailable or cached-last-known state instead of false zero on fetch failure.
- `_loadAll()` uses `Future.wait`; if either child throws in future refactors, refresh can terminate. Keep independent section refresh resilience.
- Verification status fetch failure currently leaves `notSubmitted`, which can falsely tell an already-submitted provider to verify again. Represent verification status as loading/unknown/error until authoritative fetch succeeds.

### Notifications
Normal list, initial loading, actionable lead busy states, action success/failure snackbars, preference filtering and mark-read-after-success logic exist.
BLOCKER/MAJOR OPEN / CURSOR-LOCAL:
- Load failure only clears `_isLoading`; there is no `_loadError`. An empty previous list can therefore render the normal empty state after a network/database failure. Add explicit load error + Retry and preserve cached notifications on background refresh failure.
- Delete is a hard database delete, but `_undoDelete()` restores the item only in local UI and explicitly cannot restore the DB row. This is misleading success/data consistency. Either implement a real server-side soft-delete/restore or remove the Undo affordance. Never display a restored notification that is already permanently deleted server-side.
- Replace production `print(...)` error logging with controlled debug/sanitized logging in the later production logging audit.
- Verify destructive delete failure before removing from UI; current delete flow awaits repository delete but needs explicit failure handling so a failed delete does not produce ambiguous UI.

### Video Sessions root
PASS in code for initial loading, empty upcoming, empty past, normal list, pull-to-refresh, Google integration loading/unknown/degraded state, join failure message, schedule success message and role-specific host CTA.
OPEN / CURSOR-LOCAL:
- `_error` renders as red text only; no visible Retry action is attached to the load failure. Add a clear Retry CTA that invokes `_load()` while keeping pull-to-refresh as secondary recovery.
- When list load fails, Upcoming/Past empty surfaces are still rendered below the error, which can imply `no sessions` rather than `failed to load`. Suppress authoritative empty-state copy while `_error != null`, or explicitly label cached/stale content.
- Schedule Session remains visible while list load is in error; verify whether creating is safe when role was resolved but list failed. Disable if role/session prerequisites are unknown.
- Google connection and OAuth callback busy/back lifecycle require physical-device verification.

## Global UI-state findings to apply once, then inherit everywhere
1. Never use numeric zero as a network-failure fallback for user metrics unless zero is known authoritative.
2. Filtered-empty != true-empty. Search/filter pages need distinct copy and a clear-filter recovery action.
3. Background refresh failure should preserve cached content and expose a non-destructive degraded state; it must not blank the screen.
4. Initial load failure needs explicit Retry. Pull-to-refresh alone is not enough when the screen is already in an error state.
5. Async section failures must not abort unrelated sections on composite Home/Profile screens.
6. Destructive-action Undo must be real at the persistence layer or must not be offered.
7. Every icon-only root action/tab requires Semantics/tooltip/selected or busy state as applicable.
8. Every primary CTA that starts async work must prevent duplicate taps and system-back races where duplicate persistence/navigation is possible.
9. Loading, unavailable and real-empty/zero states must be visually distinguishable.
10. Physical Android verification remains mandatory for predictive back, TalkBack, large font, keyboard, permission lifecycle, OAuth/deep links, slow/offline transitions, light/dark and minimum touch targets.

## Batch verdict
Core UI happy paths are substantially built, but the UI-state audit is NOT 100% closed. The branch now contains exact Cursor/local fixes for all material state gaps found in the primary MVP surfaces. Do not mark Core UI 100% until these are implemented and device-verified.

Highest-priority UI-state fixes before release:
- Notifications error-vs-empty and fake Undo.
- Home/Trainer/Nutritionist refresh isolation and false-zero handling.
- Signup system-back lock.
- Permissions Required-vs-Skip/lifecycle consistency.
- Home-shell bottom-nav semantics/pressed/selected state.
- Meal Tracker initial/day error state and request-race protection.
- Profile explicit failure/unavailable states.
- Video Sessions load Retry/error-vs-empty state.
