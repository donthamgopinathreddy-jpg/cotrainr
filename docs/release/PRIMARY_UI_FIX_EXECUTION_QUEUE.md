# Cotrainr Primary UI Fix Execution Queue

Status: IN PROGRESS
Branch: security/pre-release-hardening
Platform: Android first

This file converts the UI audits into an implementation queue. It is authoritative for the remaining primary-tab UI corrections.

## CLOSED — FIXED BY ME

### 1. Reduced-motion shared list/content transitions
File: `lib/widgets/common/fade_slide_in.dart`
Commit: `dc58e0db2e7c07d6b4511fe910051a051a5d330a`

Closed behavior:
- `FadeSlideIn` respects `MediaQuery.disableAnimationsOf(context)`.
- `ContentFade` uses zero-duration switching under reduced motion.
- Layout remains spatially identical when motion is disabled.

### 2. Concurrent Health Connect initialization race
File: `lib/services/health_tracking_service.dart`
Commit: `f0d7dbefb977e0a5bb8a3f9b594c2a39cb67eba6`

Closed behavior:
- `HealthTrackingService.initialize()` now coalesces concurrent callers through a single in-flight Future.
- Provider/notifier/Home callers no longer start parallel initialization/configuration cycles.
- Explicit `reinitializeMetricsSource()` and `dispose()` reset the in-flight guard.

Local verification still required:
- cold start with Health Connect already granted;
- cold start with permission denied;
- permission request shown only once;
- reconnect/reinitialize still works;
- `flutter analyze` and Android device run.

---

# CURSOR / LOCAL ACTION REQUIRED

These files are large and are returned truncated by the GitHub connector. Do not replace them blindly from ChatGPT. Apply the changes locally/Cursor, then run the acceptance matrix and commit to this branch.

## A. Home — client / trainer / nutritionist
Files:
- `lib/pages/home/home_page_v3.dart`
- `lib/pages/trainer/trainer_home_page.dart`
- `lib/pages/nutritionist/nutritionist_home_page.dart`
- `lib/widgets/home_v3/hero_header_v3.dart`
- `lib/widgets/home_v3/unified_metrics_tile_v3.dart`

### A1. Best-effort pull refresh
Change each `_onRefresh()` so metrics sync cannot abort unrelated refreshes.

Required:
- metrics sync has its own try/catch;
- profile/goals/streak/coaching/notification/session/community/client-count work still runs if metrics fail;
- independent requests must not cancel each other;
- preserve good cached values;
- one concise non-blocking degraded message if one or more sections fail;
- refresh indicator completes normally;
- no second full-page/skeleton loader during pull refresh.

### A2. Provider goals error state
Trainer/Nutritionist `_loadGoals()` must not leave `_goalsReady=false` forever after an exception.

Required:
- explicit loading vs failed vs available state;
- retain last-known/default goals only when clearly marked degraded;
- local retry;
- no permanent shimmer after a failed request.

### A3. Coaching nutrition truthfulness
If meal/nutrition data fails, do not generate a false protein-deficit coaching insight from `0` + default goal.

Required:
- add an availability/ready flag for protein-dependent coaching input;
- omit only the unavailable protein insight; retain valid step/water/streak insights.

### A4. BMI action validity
Do not navigate to BMI details when height/weight/BMI is invalid or unavailable.

Acceptance:
- no `0.0` BMI details page from missing profile measurements;
- TalkBack does not announce unavailable BMI as an active button;
- valid BMI navigation unchanged.

### A5. Home hero interaction cleanup
`HeroHeaderV3` currently makes avatar/streak feel tappable without a useful action.

Required choice:
- preferred: if existing navigation callbacks can be cleanly supplied, avatar -> Profile and streak -> meaningful progress/streak surface;
- otherwise remove press animation/haptic and render them as decorative/static.

Notification bell:
- effective 48x48 target;
- button semantics + tooltip;
- semantic label includes unread state/count;
- preserve visual dot.

### A6. Home metric typography / responsiveness
- no important metadata below ~11-12sp;
- prevent `FittedBox` from shrinking meaningful text below readable minimum;
- verify 320dp width + large text;
- no ring/chart/label collision;
- preserve existing metric colors unless contrast fails.

### A7. Home reduced motion
Decorative page/hero/ring/entrance animations become instant/minimal when `MediaQuery.disableAnimationsOf(context)` is true. Preserve normal press feedback.

---

## B. Discover
File: `lib/pages/discover/discover_page.dart`

### B1. Remove double-loading on pull refresh
Current pull refresh activates `RefreshIndicator`, then `_loadRealData()` clears content and shows initial skeletons.

Required:
- separate initial loading and refreshing;
- initial open may show skeleton cards;
- pull refresh preserves current results and uses only the pull indicator;
- apply refreshed result atomically;
- refresh failure keeps old results and shows a non-destructive message/banner;
- search, selected tab and filters remain intact.

### B2. Centre-specific degraded/error state
Partner-centre RPC/network failure must not become `No Partner Centres yet`.

Required:
- track centre fetch error separately;
- provider tabs remain usable;
- Centers tab shows Retry/error when fetch failed;
- genuine successful zero centres still shows the normal empty state.

### B3. Search-empty wording
- search only, zero matches -> `No results for ...` / `Clear search`;
- active filters -> `Clear filters`;
- do not say `No providers available` for a search mismatch.

### B4. Animation cap / reduced motion
- do not use unbounded `260 + index * 60ms` for every row;
- cap stagger to first few visible rows / short total duration;
- disable decorative entrance motion under reduced-motion setting.

### B5. Responsive checks
Verify search + filter + tabs, long provider names/headlines/location/specialties and request controls at 320dp and high font scale.

---

## C. Meal Tracker
File: `lib/pages/meal_tracker/meal_tracker_page_v2.dart`

### C1. BLOCKER — selected-date request race
Refactor day loading to bind each response to the requested date.

Required implementation pattern:
- `_loadDayData(DateTime requestedDate, {bool initial = false})`;
- capture/request generation token;
- before applying response, ensure token/date is still current;
- stale response is ignored;
- `_dayLoading`, `_dayError`, `_hasLoadedDay` or equivalent explicit state.

Acceptance:
- tap Previous/Next quickly 5-10 times; final meals/totals always belong to final selected date;
- force slow response for an old date; it never overwrites new date;
- failed date never displays previous day's values as if they were current.

### C2. Initial day loading vs real zero
- initial fetch -> skeleton/explicit loading;
- successful empty day -> authoritative 0 calories/macros + empty meal rows;
- error -> local error + Retry;
- never use zero as both `not loaded` and `real zero`.

### C3. Goals load error boundary
- catch goal load errors;
- no uncaught init/refresh Future;
- retain prior goals where available;
- indicate degraded/default state if defaults are used.

### C4. Refresh ownership
After adding day loading, pull-to-refresh must preserve existing loaded day content and not show both RefreshIndicator and initial skeletons.

### C5. Responsive/IME
- two pinned headers must not overlap at large text;
- daily summary/macros adapt at 320dp;
- long custom meal names do not overflow;
- bottom sheets/dialogs scroll with keyboard open;
- final controls stay above floating nav/system bottom inset.

### C6. Reduced motion
Ring/page/date decorative animations become instant/minimal when animations are disabled.

---

## D. Profile
File: `lib/pages/profile/profile_page.dart`

### D1. Remove duplicate profile fetch
Current `_loadAll()` starts `_loadProfile()` and `_loadHubData()` in parallel; both call `fetchMyProfile()`.

Required:
- fetch profile once per load/refresh;
- pass same snapshot to identity and hub/progress calculations;
- role/BMI/weight/name all use that snapshot;
- verification may remain a separate request.

Acceptance:
- one profile RPC/fetch per initial Profile load;
- one profile RPC/fetch per pull refresh.

### D2. Do not show identity skeleton during pull refresh
Separate initial loading from refreshing.

Required:
- first load with no data -> skeleton;
- pull refresh -> keep current identity and only show RefreshIndicator;
- refresh failure keeps last good identity.

### D3. Stop swallowing section errors as zero
Add section-level availability/error state for hub/progress data.

Never present fetch failure as authoritative:
- `0` weekly steps;
- `0%` water;
- `—` calorie target;
without indicating unavailable/degraded state.

Add Retry where useful; preserve last good values during refresh failure.

### D4. Responsive
Verify goal Wrap, verification card, professional completion card and action rows at 320dp + high font scale; long labels/subtitles may wrap/grow instead of clipping.

---

## E. Messaging
Files:
- `lib/pages/messaging/messaging_page.dart`
- detailed chat screen during local device pass.

### E1. Search-empty != empty inbox
Required:
- `_allConversations.isEmpty` -> `No messages yet`;
- non-empty source + non-empty search + zero filtered -> `No conversations found` + `Try another name` + Clear search;
- clearing search restores list without refetch.

### E2. Coalesce realtime reloads
Message INSERT/UPDATE and conversation UPDATE can trigger duplicate full-list reloads.

Implement one of:
- 100-250ms debounce/coalescing; OR
- `_reloadInFlight` + `_reloadPending` queue.

Requirements:
- never run concurrent full `fetchConversations()` calls;
- a burst collapses into one final effective reload;
- unread provider invalidation remains correct;
- newest ordering remains correct.

### E3. Responsive row
At 320dp + large font:
- name gets priority;
- preview truncates before time/unread badge is pushed away;
- time and unread badge remain visible;
- 48x48 row tap target;
- TalkBack reads name, preview, time and unread state once (no duplicate child announcements).

### E4. Chat/IME local pass
- composer stays above keyboard;
- attachment sheet scrolls;
- message bubble max width is responsive;
- long URLs/text do not overflow;
- send button loading/disabled state prevents duplicate sends.

---

# Mandatory device/visual acceptance matrix

Run after Cursor/local implementation:

Dimensions/classes:
- ~320dp narrow Android;
- 360dp common Android;
- 393-412dp modern Android;
- one tablet/foldable width.

System/UI variants:
- light mode;
- dark mode;
- normal font scale;
- large accessibility font scale;
- reduced motion;
- gesture navigation;
- 3-button navigation;
- keyboard open on every input-heavy surface;
- offline launch/refresh and connectivity recovery.

Data stress:
- very long username;
- long trainer/nutritionist name;
- long centre name/location;
- long food/custom meal name;
- long message preview;
- 0 data;
- large numeric counts;
- broken image URL;
- slow network;
- failed section fetch while other sections succeed.

Release acceptance:
- no RenderFlex/pixel overflow in Flutter logs;
- no clipped critical controls/text;
- no duplicate loader for one responsibility;
- no stale data under a newly selected date/tab/state;
- no failed request shown as genuine zero/empty;
- no duplicate effective realtime refresh cycle for one message;
- all primary actions have correct pressed/loading/disabled/success/error behavior;
- bottom nav/IME/system insets do not cover controls;
- TalkBack semantics and 48x48 targets pass;
- `flutter analyze` passes for touched files.

Do not mark these items FIXED until the code is implemented locally and the acceptance matrix is run.