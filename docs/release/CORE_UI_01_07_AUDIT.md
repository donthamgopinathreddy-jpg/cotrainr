# Core UI 01.07 — Client Home root UI audit

Branch: `security/pre-release-hardening`
Screen: `lib/pages/home/home_page_v3.dart`
Outcome: **CURSOR / LOCAL ACTION REQUIRED**

## Scope
Client Home root only. Child feature screens are audited separately. This pass applies the permanent 10-state UI rule: normal, loading, refreshing, empty, error, retry, success, disabled/unavailable, partial/degraded, offline/slow. Interaction/accessibility checks are also required where relevant.

## What is already correct
- Home is wrapped in `RefreshIndicator` with an always-scrollable scroll view.
- Profile has explicit initial loading passed into `HeroHeaderV3` and a visible section error with retry when profile RPC fails.
- Metrics preserve cached/live values and show `—` when steps/calories/distance are unavailable rather than inventing data.
- Metrics failure exposes `HomeSectionError` with a retry path.
- Goal-dependent coaching insights are withheld until goals have finished loading.
- Water add uses optimistic UI and rolls back when persistence returns null.
- Profile/avatar/cover updates prefer the reactive provider so edited images do not remain stale.
- Notification badge is refreshed after returning from Notifications.
- Pull-to-refresh attempts to reload profile, badge, streak, goals, metrics, coaching data and community event.
- Page controllers/listeners are disposed.

## 10-state matrix
1. **Normal/default — PASS.** Populated Home renders profile, event, metrics, BMI, quick access, centres and navigation hints.
2. **Loading — PARTIAL PASS.** Profile and goals expose loading semantics; health metrics can use live/cached/degraded values. Other sections own their own loading states and are audited separately.
3. **Refreshing — FAIL / MAJOR.** `_onRefresh()` begins with `await ref.read(metricsSyncServiceProvider).syncNow();` outside an error boundary. If sync throws (common offline/degraded case), the method exits before the remaining `Future.wait` reloads run. One failed subsystem therefore prevents unrelated Home sections from refreshing.
4. **Empty/no data — PARTIAL PASS.** Health values use unavailable dash states rather than fake values. Profile absence becomes an error/retry state. Child-section empty states are audited separately.
5. **Error — PARTIAL PASS.** Profile and metrics visibly expose errors. `_loadStreak()` has no try/catch and `_loadCoachingData()` silently retains default protein values on failure.
6. **Retry/recovery — PARTIAL PASS.** Profile and metrics have direct retry. Global pull-to-refresh exists but is currently fail-fast because of the unguarded metrics sync.
7. **Success/completed action — PASS.** Successful refresh updates state; successful water persistence replaces the optimistic value with authoritative returned value.
8. **Disabled/unavailable — PARTIAL FAIL.** BMI remains tappable even when `_heightCm`/`_weightKg` are unavailable and `_bmi` is still the default `0.0`; this can open a details screen with invalid/incomplete BMI inputs. Metrics unavailable values correctly render as `—`.
9. **Partial/degraded — FAIL / MAJOR for refresh orchestration.** Independent Home data domains should fail independently. Current `_onRefresh` couples all later refresh work to the first metrics sync call. Coaching-data failure is silent and may leave zero protein as if it were real data.
10. **Offline/slow/interrupted — FAIL / MAJOR for refresh.** Offline `syncNow()` can abort the entire pull-to-refresh. There is no Home-level refresh failure message indicating that some data could not be updated.

## CURSOR / LOCAL ACTION REQUIRED

### A. Make Home pull-to-refresh best-effort, not fail-fast — MAJOR
Affected function: `_onRefresh()` in `lib/pages/home/home_page_v3.dart`.

Required change:
1. Do not let `metricsSyncServiceProvider.syncNow()` abort the rest of the refresh.
2. Wrap metrics sync in its own try/catch and continue refreshing the other independent Home domains.
3. Execute the remaining reloads even if one subsystem fails. Prefer independent guarded futures or `Future.wait` over wrappers that absorb/report individual errors.
4. Preserve each section's existing error flags/retry UI.
5. If one or more refresh operations fail, show one concise non-blocking Home refresh message such as `Some data couldn’t be refreshed. Pull down to try again.` Do not replace already-cached valid data with zeros.
6. Always call `dailyMetricsProvider.notifier.refresh()` and invalidate `homeCommunityEventProvider` after the best-effort refresh attempt, unless the widget is disposed.
7. Avoid duplicate refresh execution if the user repeatedly pulls while a refresh is already active; `RefreshIndicator` normally serializes its own gesture, but verify no parallel service sync is created.

Acceptance criteria:
- Airplane mode + pull-to-refresh does not throw and does not prevent profile/goals/streak/community-event refresh attempts.
- Existing cached values remain visible when a network/health source is unavailable.
- A failed metrics sync does not suppress unrelated section refreshes.
- Successful sections update even when another section fails.
- User receives a concise degraded-refresh indication when appropriate.
- Restoring connectivity and pulling again recovers without restarting the app.

### B. Bound streak failure — MINOR/MAJOR resilience
Affected function: `_loadStreak()`.

Required change:
- Add try/catch. Keep the last known/current streak value on failure. Do not surface an uncaught Future error from the fire-and-forget `initState` call.
- Do not set a fake success value on failure.

Acceptance criteria:
- Streak backend/service failure does not generate an uncaught async exception.
- Existing displayed streak remains stable until a successful refresh.

### C. Prevent invalid BMI navigation — MAJOR UX correctness
Affected BMI `InkWell` in the Home build.

Required change:
- Only enable BMI details navigation when height and weight are valid and BMI is finite/positive.
- When unavailable, keep the BMI card in its existing unavailable/degraded presentation but make the tap disabled, or route to the appropriate profile-completion/edit action if that is already the established product pattern. Do not open `BmiDetailsScreen` with `0.0`/missing inputs.
- Add disabled semantics so TalkBack does not announce an actionable BMI control when it cannot open valid details.

Acceptance criteria:
- Profile loading/error/missing height/weight cannot open invalid BMI details.
- Valid BMI remains tappable and opens the existing details screen.

### D. Coaching partial-data correctness — verify/fix locally
`_loadCoachingData()` catches failures but leaves `_proteinToday = 0.0` and `_proteinGoal = 150`. Once goals are ready, `CoachingInsightBuilder` may interpret those defaults as real nutrition data.

Required verification:
- Confirm `CoachingInsightBuilder` does not generate a false low-protein insight when meal/nutrition loading failed.
- If it can, add a `coachingDataReady`/availability flag and omit protein-dependent coaching insights until authoritative meal data has loaded successfully. Preserve other valid insights.

Acceptance criteria:
- Offline/meal-load failure never tells the user they consumed 0 g protein unless authoritative data actually says 0.

## Local/device verification
- Fresh Home load with healthy network.
- Airplane mode launch with cached health/profile data.
- Pull-to-refresh while offline, then restore network and retry.
- Simulate profile RPC failure while metrics remain available.
- Simulate metrics failure while profile/event/other content remains available.
- Missing height/weight: BMI card cannot open invalid details.
- Water optimistic add success and persistence failure rollback.
- Small Android phone and bottom-nav overlap/96dp content clearance.
- Large text / TalkBack / forced light and dark modes.
- Reduced animations: verify entrance animation is acceptable; if app accessibility policy requires disabling it, align this screen with the shared reduced-motion pattern.

## Status
**OPEN — do not count 01.07 as fixed until Cursor/local implementation and device verification complete.**
