# Cotrainr Final Code-Blocker Closure Pass

Date: 2026-09-09
Branch: `security/pre-release-hardening`
Method: ReadyForge release-auditor rules

This pass follows Areas 1–19. It distinguishes changes safely committed through GitHub from large-file/local patches that still require Cursor/local verification. Nothing in the latter group is counted as fixed until the patch and tests are completed locally.

## FIXED BY ME

### 1. Home hero production logging + double navigation
File: `lib/widgets/home/hero_header_widget.dart`
Commit: `f143bf3b8129f614b36b44c867d46f4b60aca89b`

Fixed:
- removed release logging of username, avatar URL and cover URL;
- removed image-loading/error `print` calls;
- avatar and notification controls now use callback OR fallback route, never both;
- notification control is a 48x48 touch target;
- added button semantics/notification unread label and tooltip.

Acceptance still requires local `flutter analyze` and device smoke test.

### 2. Temporary reconnect boot marker removed
File: `lib/main.dart`
Commit: `32c6bb6b9b8aa255fc1327cf3461054e9d479617`

Removed the temporary `messaging-reconnect-debug-20260905` marker. Existing boot logging remains behind `kDebugMode` through `_debugLog`.

### 3. Storage exception prints removed
File: `lib/services/storage_service.dart`
Commit: `464a6e17f9171da58b992a8f325ad814bfb8ed06`

Fixed:
- avatar/cover/post upload errors no longer `print` in release;
- upload failures still rethrow unchanged;
- best-effort old-object deletion remains non-fatal;
- chat-media diagnostic path remains routed through the existing controlled messaging logger.

## CURSOR / LOCAL ACTION REQUIRED

### A. Router release diagnostics
File: `lib/router/app_router.dart`
Issue: `debugLogDiagnostics: true` is unconditional.

Required change:
1. import `package:flutter/foundation.dart`;
2. change `debugLogDiagnostics: true` to `debugLogDiagnostics: kDebugMode`.

Acceptance:
- release build has no GoRouter diagnostics;
- debug build retains diagnostics;
- `flutter analyze` passes.

### B. Notification permanent-delete UI lies about Undo
File: `lib/pages/notifications/notification_page.dart`
Confirmed current code:
- DB row is permanently deleted first;
- deleted notification is stored only in local `_deletedNotifications`;
- `_undoDelete()` reinserts only the local UI object;
- comment explicitly says DB delete cannot be undone.

Required MVP change: remove fake Undo rather than adding a new soft-delete model this late.

Exact implementation target:
1. remove `_deletedNotifications` and `_deletedTimestamps` state;
2. remove `_undoDelete`;
3. make `_deleteNotification` await server deletion, remove the row locally only on success, and show a simple `Notification deleted` Snackbar;
4. on delete failure keep the row visible and show `Could not delete notification. Try again.`;
5. simplify `totalCount` to `_notifications.length`;
6. remove `_DeletedNotificationCard` usage and deleted-card list branch;
7. prevent duplicate delete taps while a delete is in flight (per-ID busy set or dismiss confirmation handling).

Acceptance:
- no Undo appears after permanent deletion;
- failed delete never removes the row;
- rapid swipe cannot generate duplicate delete requests;
- refresh does not resurrect/de-sync locally deleted cards.

### C. Notification load failure must not look empty
File: `lib/pages/notifications/notification_page.dart`
Issue: catch block sets `_isLoading=false` and swallows error; when list is empty the UI then shows `No notifications`.

Required change:
1. add `String? _loadError`;
2. clear it when a new load starts;
3. set user-safe copy in catch;
4. if `_loadError != null && _notifications.isEmpty`, render a dedicated error state with Retry;
5. if cached/current rows exist, keep them visible and show a non-destructive error banner rather than replacing them;
6. use debug-only logging instead of release `print`.

Acceptance:
- network/server failure cannot render genuine empty state;
- Retry calls `_loadRealNotifications`;
- existing rows remain usable during refresh failure.

### D. Video Sessions false-empty-on-error + scheduling gate
File: `lib/pages/video_sessions/video_sessions_page_v2.dart`
Confirmed current code:
- `_error` renders only red text;
- Upcoming/Past sections still render beneath it;
- with zero cached sessions a fetch failure shows both an error and `No sessions scheduled` / `No past sessions yet`;
- host Schedule Session remains enabled during unrecovered authoritative-list failure.

Required change:
1. when `_error != null && _sessions.isEmpty`, render one dedicated error state with Retry and do not render Upcoming/Past empty states;
2. disable `Schedule Session` while this unrecovered initial/list error exists;
3. if cached sessions exist, retain them with an inline error/retry banner;
4. Retry calls `_load()`;
5. preserve Google integration degraded-state behavior.

Acceptance:
- list failure never looks like genuine zero sessions;
- user has explicit Retry;
- schedule CTA is disabled only for unrecovered authoritative-list failure, not ordinary offline refresh when cached sessions are present.

### E. Meal Tracker stale-date race / false data ownership
File: `lib/pages/meal_tracker/meal_tracker_page_v2.dart`
Confirmed current code: `_loadDayData()` reads mutable `_selectedDate`, awaits, then unconditionally writes result to UI. Rapid date changes can let an older request finish last and overwrite the final selected date.

Required change:
1. add an integer request generation/token (for example `_dayLoadGeneration`);
2. in `_loadDayData`, capture `final requestedDate = _selectedDate` and `final generation = ++_dayLoadGeneration` before awaiting;
3. call repository using `requestedDate`;
4. after await, before any `setState`, require `mounted`, `generation == _dayLoadGeneration`, and `_dateOnly(_selectedDate) == _dateOnly(requestedDate)`;
5. add explicit `_dayLoading` and `_dayLoadError` state;
6. when selected date changes, do not display prior-date totals/meals as if they belong to the new date; either clear to skeleton/loading or retain them only with an unmistakable loading overlay tied to the old date;
7. add Retry for the selected date;
8. give `_loadGoals()` its own error boundary so goal failure cannot become an unhandled async error.

Acceptance:
- rapidly tap at least 5 dates while responses are delayed/out-of-order: only the final selected date can populate UI;
- failed date load cannot leave old-day values presented as new-day values;
- genuine empty day is distinguishable from not-yet-loaded/error.

### F. Global authenticated route access-state enforcement
Files: `lib/router/app_router.dart` plus a small cached access-state service/provider.
Existing Area 3 issue remains open: global redirect checks session presence but does not re-enforce incomplete/restricted/provider-verification state on every protected deep link.

Required architecture:
- cache server-authoritative access state at startup/auth change;
- incomplete -> `/auth/complete-profile`;
- restricted/suspended/banned -> `/account-restricted`;
- unverified provider -> `/verification`;
- preserve public/recovery/OAuth callback routes;
- avoid async redirect loops by refreshing GoRouter only when cached gate state changes.

Acceptance:
- warm/cold deep links to `/home`, `/messaging`, `/meal-tracker`, `/video` cannot bypass account/onboarding restrictions;
- role/account-state changes force correct route without restart.

### G. Signup predictive/system Back lock
File: `lib/pages/auth/signup_wizard_page.dart`
Existing Area 1 requirement remains open.

Required:
- `_back()` returns immediately when `_isSubmitting || _showAllSet`;
- PopScope cannot pop/step backward in those states;
- normal one-step Back remains before submission.

### H. Messaging client CTA subscription truth
File: `lib/services/messaging_policy_service.dart` and relevant CTA consumer.
Backend send gate now requires active/non-expired client subscription, but frontend policy still primarily reflects block/accepted relationship state.

Required:
- add fail-closed subscription-aware policy;
- Message CTA must not imply send access when server will reject;
- display read-only/subscription-required state rather than optimistic compose access.

### I. Remaining production prints
A default-branch search still finds many legacy `print(...)` call sites. Do not mass-delete blindly because some files are future-disabled code.

Local procedure:
1. `rg -n "\bprint\(" lib test`;
2. classify each hit: active MVP / hidden future / test/dev;
3. active MVP: remove or route through `kDebugMode`/existing controlled logger;
4. hidden future: leave only if feature is compile-safe and unreachable, otherwise convert to debug logging;
5. rerun `rg` and attach remaining justified hits to audit evidence.

### J. `record` and `just_audio` dependency proof
`pubspec.yaml` currently includes both. Indexed code search found no imports, but branch-only dependency proof is insufficient remotely.

Local procedure:
- `rg -n "package:(record|just_audio)|AudioRecorder|AudioPlayer" lib test`;
- `flutter pub deps`;
- if no caller and no planned MVP voice recording/playback path, remove both from `pubspec.yaml`, run `flutter pub get`, analyze, tests and Android release build;
- otherwise KEEP ACTIVE and document the caller.

## REQUIRED LOCAL QUALITY GATE BEFORE AAB

Run from a clean checkout of `security/pre-release-hardening` after applying A–J:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Release signing must be configured locally through ignored `android/key.properties` + keystore. The Gradle build now fails closed for `bundleRelease` without it.

Then install/deliver that exact signed artifact through Play Internal Testing and run the physical-device E2E matrix from `docs/release/AREAS_15_19_READYFORGE_AUDIT.md`.

## CURRENT VERDICT

Code closure is materially improved, but STORE SUBMISSION remains blocked until A–J are implemented/verified where applicable, the signed AAB passes analyze/tests/build, public privacy + external account-deletion URLs exist, Play declarations are complete, and the signed Internal Testing build passes the device/E2E matrix.
