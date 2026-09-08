# Cotrainr Areas 06–09 End-to-End Release Audit

Date: 2026-09-09
Branch: `security/pre-release-hardening`
Production backend: Supabase `nvtozwtuyhwqkqvftpyi`
Scope: Flutter UI/UX -> state/providers -> services/repositories -> RPC/RLS/database -> failure states -> Android/device verification.

This document covers the batch requested for release areas 06–09. No area is marked 100% until the remaining local/device items below are implemented and verified.

## 06 Connections / Model B

### PASS — production model verified
Live PostgreSQL is 17.6.1 and database timezone is UTC (`Etc/UTC`). The live RPC model matches the locked period accepted-connection allowance model:
- request / decline / cancel do not consume allowance;
- provider acceptance consumes one allocation for the UTC calendar month;
- client/member end within 7 days is eligible for restoration;
- later client/member end does not restore;
- provider end may restore;
- same pair + period restoration is limited to one;
- accepted relationships link to an entitlement allocation;
- provider verification is checked when creating and accepting a relationship;
- current conversations are reused rather than creating a new provider-client thread for every reconnect.

Frontend `LeadsService` correctly delegates create / accept-or-decline / end behavior to the authoritative RPCs (`create_lead_tx`, `update_lead_status_tx`, `end_connection_tx`) rather than reproducing quota rules locally.

### LIVE DATA CONSISTENCY — PASS
Production aggregate consistency query on 2026-09-09 returned:
- duplicate provider-client conversation pairs: 0
- duplicate active lead pairs: 0
- accepted leads missing allocation: 0
- accepted leads with broken allocation linkage: 0
- users with multiple subscription rows: 0

Aggregate relationship state at audit time: 7 accepted, 0 requested, 3 ended. This is operational verification only, not fixture data.

### OPEN — performance / cleanup, not release blocker
- `provider_entitlement_allocations.provider_id` is reported by the Supabase performance advisor as an unindexed foreign key.
- historical/duplicate index cleanup should remain in the later backend/cleanup wave and must not be performed blindly during product-flow hardening.

### LOCAL E2E REQUIRED
Test Free/Basic/Premium account combinations using two real client/provider accounts:
- request -> cancel -> request again;
- provider decline;
- provider accept;
- allowance boundary at UTC month rollover;
- client end before and after 7 days;
- provider end;
- same-pair restore only once;
- reconnect reuses durable conversation;
- unverified provider cannot receive/accept a connection.

## 07 Messaging

### FIXED BY ME — BLOCKER: direct conversation INSERT authorization hole
Previous production RLS contained a direct `conversations` INSERT policy whose accepted-lead predicate contained self-comparisons, allowing an unsafe direct-write path outside the vetted conversation RPC.

Production migration applied:
`20260908230512_pre_release_lock_conversation_and_nutrition_writes`

Fix:
- removed direct INSERT policy on `public.conversations`;
- new provider-client conversation creation now has to pass through the vetted server function.

Verification:
- production now has 0 direct INSERT policies on `public.conversations`.
- `create_or_find_provider_client_conversation` is not executable by `anon` and remains executable by `authenticated`.

Git record:
`supabase/migrations/20260908230512_pre_release_lock_conversation_and_nutrition_writes.sql`

### FIXED BY ME — BLOCKER: active subscription missing from send authorization
The previous live `can_send_message_in_conversation` correctly checked authenticated caller, participant membership, provider-client shape, account status, block state, and current accepted lead, but it did not enforce Cotrainr's product rule that messaging requires an active client subscription.

Production migration applied:
`20260908230616_pre_release_lock_metrics_and_messaging_subscription`

The function now also requires an active, non-expired `subscriptions` row for the conversation client.

Verification:
- function definition contains subscription lookup;
- `anon` execute = false;
- `authenticated` execute = true.

Git record:
`supabase/migrations/20260908230616_pre_release_lock_metrics_and_messaging_subscription.sql`

### CURSOR / LOCAL ACTION REQUIRED — frontend subscription state must match server
File: `lib/services/messaging_policy_service.dart`

Issue:
`clientMayUseMessagingWithProvider()` currently checks only block state + accepted lead. `PublicProfileReadonlyPage` uses this to decide whether the Message CTA is enabled. After the server hardening, an accepted client with an expired/inactive subscription can therefore still see a Message CTA and enter chat, even though the server correctly rejects sending.

Required change:
- make `clientMayUseMessagingWithProvider()` require the same active client subscription rule as the server;
- make fallback logic in `canCurrentUserSendMessage()` fail closed on subscription state if the authoritative RPC is unavailable;
- do not weaken or bypass the live RPC/RLS gate;
- present an explicit read-only/subscription-required UI rather than a generic send failure.

Acceptance:
- accepted + active subscription -> Message/send enabled;
- accepted + inactive/expired/no subscription -> history may remain readable but composer/send is disabled with correct subscription explanation;
- provider side obeys the client's subscription state;
- reconnect after subscription becomes active restores composer without recreating history.

### CURSOR / LOCAL ACTION REQUIRED — duplicate realtime reloads
File: `lib/pages/messaging/messaging_page.dart`

Current architecture listens to both conversation changes and message INSERT/UPDATE and each callback can trigger a complete conversation refetch. One logical message can therefore produce multiple concurrent reloads.

Required implementation:
- debounce/coalesce roughly 100–250 ms, or use an `_reloadInFlight` + `_reloadPending` gate;
- at most one effective rendered-list refresh per event burst;
- keep unread/order correctness.

### CURSOR / LOCAL ACTION REQUIRED — search empty state
When the inbox has conversations but the current search has no matches, display `No conversations found` + clear search affordance. Reserve `No messages yet` for a genuinely empty conversation collection.

### POST-LAUNCH PERFORMANCE
`MessagesRepository.fetchConversations()` performs per-conversation work (preview/unread/profile). A batched RPC/view may be appropriate later after RLS review; this is not required for initial release with a small conversation set.

## 08 Meal / Water Tracking

### FIXED BY ME — BLOCKER: cross-user meal writes possible through permissive RLS
Production had owner policies plus separate `Active accounts can ...` write policies on `meals`, `meal_items`, and `nutrition_goals`. Because permissive PostgreSQL RLS policies are OR-combined, an active account could satisfy the active-account policy without satisfying row ownership.

Production migration:
`20260908230512_pre_release_lock_conversation_and_nutrition_writes`

Fix:
- `meals`: SELECT own; INSERT/UPDATE/DELETE require owner + active account;
- `meal_items`: ownership derived from parent `meals` row; mutations require parent owner + active account;
- `nutrition_goals`: mutations require owner + active account;
- coach read policies are preserved separately.

Verification:
- live policy inspection shows owner-qualified write paths;
- aggregate validation query found 0 unsafe meal write policies under the audited predicate.

### FRONTEND WIRING — PASS WITH UI ISSUES
`MealRepository` uses direct RLS-protected `meals`, `meal_items`, and `nutrition_goals` paths and writes the authenticated user's ID. No client-side authorization bypass was found.

### BLOCKER/MAJOR CURSOR ACTION — selected-date stale data race
File: `lib/pages/meal_tracker/meal_tracker_page_v2.dart`

Previously recorded and still open:
- date selection changes immediately;
- overlapping day requests can complete out of order;
- old day data can be painted beneath the newly selected date;
- a failed load can leave previous-day data looking authoritative.

Required:
- `_loadDayData(DateTime requestedDate)` with captured date;
- request generation/token or current-selection equality before applying results;
- `_dayLoading` and `_dayError` states;
- previous-day values must never be labelled as the newly selected day;
- initial load distinguishes `not loaded` from an authoritative zero-food day;
- inline Retry.

Acceptance: rapid Previous/Next 5–10 times always ends on the final selected date and an older response cannot overwrite it.

### MAJOR DATA-INTEGRITY RISK — water increment is not atomic
Current water storage is `metrics_daily.water_intake_liters`. `MetricsRepository.incrementWater()` performs client-side read -> add -> write -> verify. Two overlapping quick-log actions (for example notification action + open app, or repeated taps) can both read the same old total and one increment can be lost.

Required backend + frontend change:
- create an authenticated atomic RPC such as `increment_water_intake(p_liters numeric)`;
- validate positive bounded input;
- use `auth.uid()` internally, never accept arbitrary user id;
- atomically insert/update today's row and return authoritative new total;
- repository quick-log uses only this RPC for increments;
- preserve Health Connect merge rule so Health data cannot lower manual water.

Acceptance:
- 10 concurrent +250 ml increments increase the total by exactly 2.5 L;
- unauthenticated call fails;
- caller cannot change another user's water;
- duplicate notification taps each count exactly once when they represent distinct actions.

### WATER STORAGE — PASS
There is no separate production water table. Water is intentionally stored in `metrics_daily.water_intake_liters`. At audit time 269 metrics rows existed, with 31 containing positive water values. This aggregate check confirms the path is in real use.

## 09 Health Metrics

### FIXED BY ME — BLOCKER: cross-user metrics writes possible through permissive RLS
Production `metrics_daily` had owner policy plus separate active-account INSERT/UPDATE/DELETE policies. Those permissive policies could authorize writes without row ownership.

Production migration:
`20260908230616_pre_release_lock_metrics_and_messaging_subscription`

Fix:
- own SELECT;
- active + own INSERT;
- active + own UPDATE using both USING and WITH CHECK;
- active + own DELETE;
- coach SELECT policy retained.

Verification:
- aggregate validation query found 0 unsafe metric write policies under the audited predicate.

### FRONTEND/SYNC — PASS
`MetricsRepository` scopes normal self reads/writes to the authenticated user. `MetricsSyncService` correctly:
- avoids concurrent self-sync through `_isSyncing`;
- initializes Health source;
- writes nothing when platform health is unavailable;
- preserves stored positive values when an individual metric is temporarily zero/unavailable;
- stores water as the maximum of Health water and already stored manual water;
- backfills the prior six calendar days;
- supports a manual sync path.

The earlier shared `HealthTrackingService` initialization race has already been fixed on the hardening branch.

### CURSOR / LOCAL ACTION REQUIRED — Home refresh ownership
Home/client/provider pull-to-refresh must isolate `metricsSyncService.syncNow()` from unrelated profile/goals/streak/session refresh tasks. A Health/network sync failure must not abort the entire page refresh.

Acceptance:
- offline or denied Health pull refresh completes;
- cached metrics remain visible;
- profile/goals can refresh independently;
- no uncaught `RefreshIndicator` future.

### PRODUCT SCOPE MISMATCH — MUST RESOLVE BEFORE RELEASE
Live backend still includes coach read support for client metrics/meals (`coach_can_view_client_metrics`, `coach_can_view_client_meals`, related RLS SELECT policies) when relationship/share rules allow it. Earlier product scope removed trainer monitoring of metrics/meals to support broader provider types such as yoga/wellness/boxing.

Do not silently delete these paths. Before release, resolve one authoritative product rule:
- KEEP: retain coach metrics/meals sharing and ensure UI/privacy wording explicitly exposes it; or
- REMOVE: retire frontend coach monitoring surfaces and revoke/retire corresponding backend read paths via a forward migration.

Acceptance:
- product UI, privacy controls, RLS and provider dashboards all express the same rule.

### LOCAL HEALTH CONNECT MATRIX REQUIRED
Physical Android verification:
- Health Connect unavailable;
- permission denied;
- permission permanently denied/settings recovery;
- granted with steps/calories/distance/water;
- app offline;
- app killed/resumed;
- cached DB values preserved;
- no permission/transient error overwrites good metrics with zero;
- large font/light/dark/320dp visual pass.

## Live database verification summary
- database timezone: UTC
- duplicate conversation pairs: 0
- duplicate active relationship pairs: 0
- accepted relationship allocation inconsistencies: 0
- multiple subscription rows per user: 0
- direct conversation INSERT RLS policies: 0 after hardening
- unsafe audited meal write policies: 0 after hardening
- unsafe audited metrics write policies: 0 after hardening

## Advisor follow-up
Security advisor was rerun after DDL. No new missing-RLS issue was introduced by these migrations. Pre-existing advisor work remains for later Areas 13–14, including service-only tables with RLS/no policy, SECURITY DEFINER review, leaked-password protection, and PostGIS-owned warnings. Do not alter `spatial_ref_sys` or move PostGIS blindly.

Performance advisor was also rerun. It reports multiple pre-existing RLS init-plan optimizations, unindexed foreign keys, unused indexes and duplicate indexes. These are recorded as backend/performance debt and should be handled selectively in the backend/cleanup waves, not by indiscriminate index/policy churn.

## Batch verdict
### Area 06 Connections / Model B
Production model and live consistency: PASS. Physical E2E matrix remains.

### Area 07 Messaging
Backend authorization materially hardened. Frontend subscription-state alignment, search-empty UX and realtime reload coalescing remain OPEN.

### Area 08 Meal / Water
Cross-user write authorization fixed. Meal date race and atomic water increment remain OPEN.

### Area 09 Health Metrics
Cross-user write authorization fixed and sync logic is substantially sound. Home refresh isolation, product scope decision for coach monitoring, and physical Health Connect verification remain OPEN.

Overall: AREAS 06–09 ARE NOT YET 100% RELEASE-SIGNED-OFF. The production backend is materially safer after this batch, but the listed frontend/local/device gates must close before Android release.
