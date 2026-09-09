# Areas 20–22 ReadyForge Remediation Record

Branch: `security/pre-release-hardening`

## Area 20 — Settings / Account Hub

### FIXED BY ME

- Settings role/profile load truthfulness: `4eb41440fa1c8f96363f8ee93c50377f44f8b411`
- Notification settings load/error/retry truthfulness: `79cef8d95a3cb1e2065e8edbdb1622d9497d3e9e`
- Health Connect / Apple Health load/error/retry hardening: `e505457b73cede07e03e22f9d800b8e1b9bc11a2`
- Privacy & Security load/error/retry hardening: `0e4138587b9e90e0083b6e888ebce130df4dbc95`
- Release-facing `Billing History` and `Download My Data` Coming Soon placeholders removed.

Production Supabase project `nvtozwtuyhwqkqvftpyi` was verified to contain the authoritative profile fields `role`, `share_metrics_with_trainer`, `share_meals_with_trainer`, and `share_nutrition_with_nutritionist`.

### OPEN / CURSOR OR LOCAL VERIFICATION REQUIRED

- Expose authoritative-vs-cached source state from `PrivacyPreferencesService` before treating fallback values as server truth.
- Verify Change Password against hosted Supabase password policy and improve server error mapping where required.
- Run `flutter analyze`, `flutter test`, and physical Android Settings tests including 320dp, large text, offline, permission denied/permanently denied, resume, predictive Back, and duplicate taps.

---

## FINAL V1 PRODUCT DECISION FOR AREAS 21 AND 22

Trainer and Nutritionist remain full Cotrainr users in V1. Their personal fitness metrics, BMI, water, goals, Health Connect / Apple Health, water reminders, and normal personal Meal Tracker remain available.

Do **not** remove the provider personal fitness stack. Instead, reduce its Home-screen priority by putting it inside a collapsed `My Fitness` section.

Meal Tracker remains the same personal food-recording experience used by Client for V1. Client meal/nutrition monitoring stays inside the provider's client-detail flow and is subject to the existing client sharing permissions.

### LOCKED HOME ORDER — BOTH TRAINER AND NUTRITIONIST

1. Cover / Hero
2. Events
3. `My Fitness` — collapsed by default
   - Steps
   - Active calories
   - Water
   - Distance
   - BMI
   - existing streak / fitness insight behavior
   - Add Water and detailed metric navigation remain functional
4. Professional overview
   - Active clients
   - Requests
   - Client notes
   - next video session
5. Recent clients
6. Reviews & Ratings
7. Explore
8. Messages / personal Meal Tracker hints
9. Existing bottom navigation remains unchanged: Home / Clients / Messages / Meals / Profile

This order is now the governing V1 requirement. Do not revert to the earlier recommendation that removed provider personal fitness features.

---

## Area 21 — Trainer role end-to-end

### FIXED BY ME — HOME ARCHITECTURE

- Added shared provider Home implementation: `lib/pages/provider/provider_role_home_page.dart` — `1d97103de568c1cc1baca1b8128ce920c77742a2`
- Trainer wrapper: `lib/pages/trainer/trainer_home_page.dart` — `067b593e9273c06980cf2058e53045cac6e4c047`
- `My Fitness` is collapsed by default, provider personal metrics remain available, metrics sync failure no longer aborts unrelated Home refresh work, and reduced-motion behavior is respected.

### FIXED BY ME — REVIEWS & RATINGS HOME SURFACE

- Reusable provider review preview: `lib/widgets/provider/provider_reviews_home_section.dart` — `0aa78d3be7e422557aa2c2c81885659bafa10efa`
- Explicit loading, no-review, review-present and load-error + Retry states.

### LIVE SUPABASE REVIEW VERIFICATION

Production review infrastructure already exists: `public.reviews`, compatibility `public.provider_reviews`, `list_provider_reviews(uuid, int)`, `submit_provider_review(uuid, smallint, text)`, and rating recalculation functions. `submit_provider_review` requires an authenticated client with an accepted provider relationship and upserts one review per client/provider pair. `list_provider_reviews` returns visible reviews only.

### FIXED BY ME — CLIENT ACCESS FAILURE TRUTHFULNESS

- `lib/services/coach_client_access_service.dart` — `5de86952137424488828d4a434dc5b816295c65c`
- RPC/network/server failures now throw `CoachClientAccessLookupException` rather than being converted to `hasAcceptedLead=false`.
- A genuine server result with no accepted lead still returns `hasAcceptedLead=false`.

Production `coach_client_access_status(uuid)` was inspected live. It is `SECURITY DEFINER`, derives provider identity from `auth.uid()`, checks the exact accepted provider/client relationship, and returns the sharing flags. The three sharing columns are `NOT NULL` in production.

### FIXED BY ME — COACH NOTES ROLE + ERROR STATES

- `lib/pages/trainer/trainer_coach_notes_page.dart` — `232d4ad4ee447838544ce47a2589a451731521b9`
- Provider role comes from authoritative profile data instead of `userMetadata.role`.
- Client-list and note-list failures show persistent Error + Retry instead of false empty states.
- Accepted clients are de-duplicated, routing uses the authoritative provider type, duplicate note submit is blocked, and note input is capped.

### FIXED BY ME — MY CLIENTS LOAD TRUTHFULNESS

- `lib/pages/provider/provider_my_clients_page.dart` — `07af60639511c1b694562fe3bb4ee028d30561d9`
- Initial/backend/auth load failure no longer becomes `No clients yet` or `No requests right now`.
- Added dedicated persistent load error + Retry.
- Refresh failure with already loaded clients preserves the last loaded data and shows a degraded-state warning + Retry.
- Genuine successful empty results still use the normal empty states.

### FIXED BY ME — CLIENT MONITORING PARTIAL / DEGRADED STATES

- `lib/pages/client_monitoring/client_detail_shell.dart` — `5eab033510d2f5266b085b1e44f6c6f0a3ef5694`
- Notes, upcoming session, activity metrics and meals now track independent load failures.
- A single subsection failure no longer blocks the complete client screen.
- Refresh failures preserve last loaded subsection data where available and show a degraded-state banner.
- If no prior data exists, the affected section shows explicit load error + Retry instead of false `No activity`, `No meals`, no-session or no-notes states.
- Client access lookup outage is explicitly mapped to an access-verification error rather than a disconnected-client message.
- Meal sharing/privacy behavior remains authoritative: Trainer uses trainer meal sharing; Nutritionist uses `share_nutrition_with_nutritionist`.

### OPEN AREA 21 FINDINGS

- Reviews Home count/average currently derives from the loaded review set. Before providers can exceed the RPC preview limit, use a server-authoritative summary/count endpoint or canonical aggregate.
- Decide whether V1 needs a dedicated `View all reviews` screen.
- Run static analysis/tests to catch any layout or compile regression introduced by the shared provider Home and client-monitoring changes.

---

## Area 22 — Nutritionist role end-to-end

### FIXED BY ME — HOME ARCHITECTURE

- Nutritionist Home delegates to the shared provider Home: `lib/pages/nutritionist/nutritionist_home_page.dart` — `03a4ae26cfe48eb47df5036c943178da9e64203a`
- Nutritionist keeps personal metrics, BMI, water, goals, personal Meal Tracker and Health Connect in V1.
- Reviews & Ratings uses the same provider review surface.

### VERIFIED — NUTRITIONIST CLIENT SHARING ACCESS PATH

Live `coach_client_access_status(uuid)` returns `provider_type` from the accepted lead and `share_nutrition_with_nutritionist` from the client profile. Flutter `CoachClientAccessStatus.canViewMeals` permits nutritionist meal access only when the relationship is accepted and `share_nutrition_with_nutritionist` is true.

### FIXED BY ME — SHARED PROVIDER CLIENT SURFACES

The My Clients and client-detail fixes above apply to Nutritionist as well because both roles use the shared provider implementations:
- My Clients Error/Retry + stale-data warning: `07af60639511c1b694562fe3bb4ee028d30561d9`
- Client monitoring partial/degraded section states: `5eab033510d2f5266b085b1e44f6c6f0a3ef5694`
- Coach Notes authoritative provider role + error states: `232d4ad4ee447838544ce47a2589a451731521b9`

### AREA 22 AUDIT REQUIREMENTS STILL OPEN

- notes ownership/access adversarial backend tests
- messaging entitlement and accepted-connection requirement re-check for nutritionist flows
- video-session scheduling/joining and Google Meet integration re-check
- verification, professional profile, certifications and service locations
- Discover/public profile truth
- notifications
- Settings role gating
- subscription/connection allowance behavior
- 10-state UI, responsive/overflow, light/dark, accessibility, offline and stale-data physical validation

---

## CURSOR / LOCAL QUALITY GATE — REQUIRED BEFORE MARKING AREAS 21/22 CLOSED

Run from the current `security/pre-release-hardening` branch:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then validate Trainer and Nutritionist on Android at minimum:
- 320dp, 360dp, 393–412dp widths
- default and large text scale
- light and dark mode
- `My Fitness` collapsed and expanded
- metrics unavailable / Health Connect not granted
- pull-to-refresh with metrics sync failure
- zero clients / clients present / requests present
- client-list initial failure, stale refresh failure and Retry
- client detail: access lookup failure vs genuinely disconnected relationship
- client detail: notes/session/metrics/meals independent failures and Retry
- nutritionist meal sharing on/off
- no reviews / reviews present / review RPC failure
- Coach Notes client-list failure, notes failure, Retry and send failure
- long provider and client names
- no upcoming session / upcoming session
- offline / slow network / interrupted refresh
- TalkBack semantics and touch targets
- predictive/system Back

No local Flutter analyze/test/build or physical device verification has been run by the assistant. Do not mark Areas 21 or 22 production-verified until those gates pass.
