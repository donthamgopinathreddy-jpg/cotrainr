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
4. Professional overview
5. Recent clients
6. Reviews & Ratings
7. Explore
8. Messages / personal Meal Tracker hints
9. Existing bottom navigation remains unchanged: Home / Clients / Messages / Meals / Profile

---

## Area 21 — Trainer role end-to-end

### FIXED BY ME — HOME ARCHITECTURE

- Shared provider Home: `lib/pages/provider/provider_role_home_page.dart` — `1d97103de568c1cc1baca1b8128ce920c77742a2`
- Trainer wrapper: `lib/pages/trainer/trainer_home_page.dart` — `067b593e9273c06980cf2058e53045cac6e4c047`
- `My Fitness` collapsed by default; metrics remain available; metrics sync no longer aborts unrelated Home refresh work; reduced-motion honored.

### FIXED BY ME — REVIEWS & RATINGS

- Initial Home preview: `0aa78d3be7e422557aa2c2c81885659bafa10efa`
- Repository now exposes server-authoritative `providers.rating` + `providers.total_reviews` summary and configurable review limit: `8d1557e1ca86cd43a2e2a88885aa03a242ac5d69`
- Added full provider reviews screen with loading/error/empty/refresh states and latest-50 behavior: `fd0cc1b25d1429eb26e56c043113a728b679e78b`
- Home review card now uses authoritative aggregate when available, shows degraded summary warning if aggregate refresh fails, and provides `See all reviews`: `bb8976090e35841fb9b92415cac556ae221a5af6`

Production verification:
- `providers.rating` and `providers.total_reviews` exist and are maintained by `recalculate_provider_rating` from visible canonical `reviews` rows.
- `list_provider_reviews` returns visible reviews ordered newest-first and clamps `p_limit` to 50.
- No schema migration was needed.

### FIXED BY ME — CLIENT ACCESS FAILURE TRUTHFULNESS

- `lib/services/coach_client_access_service.dart` — `5de86952137424488828d4a434dc5b816295c65c`
- RPC/network/server failures no longer masquerade as disconnected relationships.

### FIXED BY ME — COACH NOTES ROLE + ERROR STATES

- `lib/pages/trainer/trainer_coach_notes_page.dart` — `232d4ad4ee447838544ce47a2589a451731521b9`
- Authoritative provider role, persistent client/note error states, dedupe, safe routing, duplicate-submit protection.

### FIXED BY ME — MY CLIENTS LOAD TRUTHFULNESS

- `lib/pages/provider/provider_my_clients_page.dart` — `07af60639511c1b694562fe3bb4ee028d30561d9`
- Persistent Error + Retry, stale-data preservation on refresh failure, genuine empty states preserved.

### FIXED BY ME — CLIENT MONITORING PARTIAL / DEGRADED STATES

- `lib/pages/client_monitoring/client_detail_shell.dart` — `5eab033510d2f5266b085b1e44f6c6f0a3ef5694`
- Notes/session/metrics/meals track independent failures with per-section truthfulness and retry.

### OPEN AREA 21 FINDINGS

- Re-check trainer messaging entitlement/accepted-connection path end-to-end.
- Re-check trainer video-session schedule/join permissions and Meet integration.
- Verify professional profile, verification, certifications, service locations and public-profile consistency.
- Run static analysis/tests and physical-device matrix before closure.

---

## Area 22 — Nutritionist role end-to-end

### FIXED BY ME — HOME ARCHITECTURE

- Nutritionist shared Home wrapper: `03a4ae26cfe48eb47df5036c943178da9e64203a`
- Personal metrics/BMI/water/goals/Meal Tracker/Health Connect retained.
- Reviews use the same authoritative aggregate + See all implementation as Trainer.

### VERIFIED — NUTRITIONIST CLIENT SHARING ACCESS PATH

Live `coach_client_access_status(uuid)` returns `provider_type` from the accepted lead and `share_nutrition_with_nutritionist` from the client profile. Flutter permits nutritionist meal access only when both conditions are true.

### FIXED BY ME — SHARED PROVIDER CLIENT SURFACES

- My Clients Error/Retry + stale-data warning: `07af60639511c1b694562fe3bb4ee028d30561d9`
- Client monitoring partial/degraded section states: `5eab033510d2f5266b085b1e44f6c6f0a3ef5694`
- Coach Notes authoritative provider role + error states: `232d4ad4ee447838544ce47a2589a451731521b9`

### AREA 22 AUDIT REQUIREMENTS STILL OPEN

- notes ownership/access adversarial backend tests
- messaging entitlement and accepted-connection re-check
- video-session scheduling/joining and Google Meet re-check
- verification, professional profile, certifications, service locations
- Discover/public profile truth
- notifications
- Settings role gating
- subscription/connection allowance behavior
- 10-state UI, responsive/overflow, light/dark, accessibility, offline/stale-data physical validation

---

## CURSOR / LOCAL QUALITY GATE — REQUIRED BEFORE MARKING AREAS 21/22 CLOSED

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then validate Trainer and Nutritionist on Android at minimum: 320dp/360dp/393–412dp, large text, light/dark, collapsed/expanded My Fitness, no Health permission, clients/request states, review aggregate/load failure/See all, access lookup failure vs real disconnect, partial client-monitoring failures, nutritionist meal sharing on/off, Coach Notes failures, long names, offline/slow/interrupted network, TalkBack/touch targets, and predictive/system Back.

No local Flutter analyze/test/build or physical-device verification has been run by the assistant. Do not mark Areas 21 or 22 production-verified until those gates pass.
