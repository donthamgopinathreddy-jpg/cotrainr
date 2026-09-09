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

- Added shared provider Home implementation:
  - `lib/pages/provider/provider_role_home_page.dart`
  - Commit: `1d97103de568c1cc1baca1b8128ce920c77742a2`
- Replaced duplicated Trainer Home implementation with a thin role wrapper:
  - `lib/pages/trainer/trainer_home_page.dart`
  - Commit: `067b593e9273c06980cf2058e53045cac6e4c047`
- Trainer Home now uses the locked V1 ordering above.
- `My Fitness` is collapsed by default with a compact Steps + BMI summary.
- Metrics/BMI/water/Health Connect behavior is retained rather than removed.
- Metrics sync failure is isolated from the rest of pull-to-refresh so provider/practice refresh work still proceeds.
- Goal loading no longer leaves the fitness section in a permanent loading state if local goal storage fails.
- Reduced-motion preference is respected by the provider Home section entrance animations.

### FIXED BY ME — REVIEWS & RATINGS HOME SURFACE

- Added reusable provider review preview component:
  - `lib/widgets/provider/provider_reviews_home_section.dart`
  - Commit: `0aa78d3be7e422557aa2c2c81885659bafa10efa`
- Home shows:
  - rating summary
  - review count for the loaded review set
  - latest review previews
  - explicit no-review state
  - explicit load-error + Retry state

### LIVE SUPABASE REVIEW VERIFICATION

Production review infrastructure was inspected and already exists:
- canonical `public.reviews`
- compatibility `public.provider_reviews`
- `list_provider_reviews(uuid, int)`
- `submit_provider_review(uuid, smallint, text)`
- provider rating recalculation functions

Verified `submit_provider_review` requires an authenticated client with an accepted provider connection and upserts one review per client/provider pair. `list_provider_reviews` returns visible reviews only.

No review schema migration was required for the Home preview integration.

### OPEN AREA 21 FINDINGS

- `CoachClientAccessService` still maps RPC/network errors to `hasAcceptedLead=false`; this can incorrectly show `This client is not connected` during backend failure.
- Client monitoring still swallows independent notes/session/metrics/meals subsection errors and can render false empty/zero states.
- My Clients still needs a persistent Error + Retry state instead of falling back to normal empty UI after load failure.
- Trainer Coach Notes can show false `No clients yet` / empty notes after backend failure.
- Coach Notes role classification must stop relying on user-editable/stale `userMetadata.role`; use authoritative profile/server role truth.
- Reviews Home count/average currently derives from the loaded review list. Before providers can accumulate more than the RPC preview limit, add a server-authoritative review-summary/count endpoint or use the canonical provider aggregate.
- Decide whether V1 needs a dedicated `View all reviews` screen. The Home preview itself is now present.

---

## Area 22 — Nutritionist role end-to-end

### FIXED BY ME — HOME ARCHITECTURE

- Nutritionist Home now delegates to the same shared provider Home implementation:
  - `lib/pages/nutritionist/nutritionist_home_page.dart`
  - Commit: `03a4ae26cfe48eb47df5036c943178da9e64203a`
- Nutritionist receives the same locked Home hierarchy as Trainer while retaining nutritionist-specific client routing and provider-practice counts.
- Personal metrics, BMI, water, goals, personal Meal Tracker and Health Connect remain available for V1.
- Reviews & Ratings uses the same provider review surface and live review RPC.

### AREA 22 AUDIT REQUIREMENTS STILL OPEN

Audit Nutritionist specifically for:
- My Clients and Requests role filtering
- client detail route `/nutritionist/clients/:id`
- `share_nutrition_with_nutritionist` enforcement
- client meal-log monitoring states
- notes ownership/access
- messaging entitlement and accepted-connection requirement
- video-session scheduling/joining and Google Meet integration
- verification, professional profile, certifications, service locations
- Discover/public profile truth
- notifications
- Settings role gating
- subscription/connection allowance behavior
- 10-state UI, responsive/overflow, light/dark, accessibility, offline and stale data

---

## CURSOR / LOCAL QUALITY GATE — REQUIRED BEFORE MARKING AREAS 21/22 CLOSED

Run from the current `security/pre-release-hardening` branch:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then validate Trainer and Nutritionist Home on Android at minimum:
- 320dp, 360dp, 393–412dp widths
- default and large text scale
- light and dark mode
- `My Fitness` collapsed and expanded
- metrics unavailable / Health Connect not granted
- pull-to-refresh with metrics sync failure
- zero clients / clients present / requests present
- no reviews / reviews present / review RPC failure
- long provider and client names
- no upcoming session / upcoming session
- offline / slow network / interrupted refresh
- TalkBack semantics and touch targets
- predictive/system Back

No GitHub Actions status checks were attached to the latest Home commit, so these local checks remain mandatory before the change can be marked production-verified.
