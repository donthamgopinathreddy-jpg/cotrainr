# Areas 21–22 Cursor Handoff — Trainer & Nutritionist V1

Branch: `security/pre-release-hardening`

## Locked product decision

Trainer and Nutritionist keep their own personal fitness features and normal personal Meal Tracker in V1.

Do not remove:
- Steps
- Active calories
- Water
- Distance
- BMI
- streak / personal fitness insights
- Goals & Preferences
- Health Connect / Apple Health
- water reminders
- normal Meal Tracker food logging

The change is Home-screen priority, not feature removal.

## Locked Home order — both roles

1. Cover / Hero
2. Events
3. My Fitness — collapsed by default
4. Professional overview
5. Recent clients
6. Reviews & Ratings
7. Explore
8. Messages / personal Meals hints
9. Existing bottom nav: Home / Clients / Messages / Meals / Profile

## GitHub implementation already applied

- Shared provider Home: `lib/pages/provider/provider_role_home_page.dart`
  - commit `1d97103de568c1cc1baca1b8128ce920c77742a2`
- Trainer wrapper: `lib/pages/trainer/trainer_home_page.dart`
  - commit `067b593e9273c06980cf2058e53045cac6e4c047`
- Nutritionist wrapper: `lib/pages/nutritionist/nutritionist_home_page.dart`
  - commit `03a4ae26cfe48eb47df5036c943178da9e64203a`
- Reviews & Ratings Home widget: `lib/widgets/provider/provider_reviews_home_section.dart`
  - initial commit `0aa78d3be7e422557aa2c2c81885659bafa10efa`
  - cleanup commit `7fd392d6542b037e0b931599afd285ca7bb8d8fc`
- Main remediation ledger update: `docs/release/AREA_20_21_REMEDIATION.md`
  - commit `13126e24381cc950a7bae345279d3d794467d933`

## Behavior implemented

- `My Fitness` starts collapsed and shows compact Steps + BMI summary.
- Expanding it exposes the existing Steps, Calories, Water, Distance and BMI UI.
- Existing Add Water and metric-detail navigation are retained.
- Personal Meal Tracker remains unchanged in bottom navigation for both provider roles.
- Metrics-sync failure is isolated so it cannot abort unrelated provider Home refreshes.
- Goal-load failure falls back to defaults instead of leaving a permanent loading skeleton.
- Provider Home entrance animations respect reduced-motion preference.
- Trainer and Nutritionist use one shared Home architecture to prevent future role drift.
- Reviews & Ratings loads the provider's visible reviews, supports loading, zero-review and Retry/error states.

## Production Supabase verification

Existing production review backend is already present and was inspected:
- `public.reviews`
- `public.provider_reviews` compatibility surface
- `list_provider_reviews(uuid, int)`
- `submit_provider_review(uuid, smallint, text)`
- rating recalculation functions

No new review migration was required for the Home preview.

## Cursor / local work required before marking fixed

Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

If analyzer or tests find any issue in `provider_role_home_page.dart`, fix it on this same hardening branch and record the exact commit in the main release ledger.

Then test Trainer and Nutritionist separately on Android:
- 320dp, 360dp, 393–412dp widths
- light/dark
- normal and large text
- My Fitness collapsed/expanded
- Health Connect not granted
- metrics unavailable
- pull-to-refresh while metrics sync fails
- no clients / active clients / pending requests
- no reviews / reviews present / review RPC failure
- long provider/client names
- no upcoming video session / upcoming session
- offline / slow / interrupted network
- TalkBack
- predictive/system Back

## Still-open Areas 21–22 findings

Do not mark Areas 21/22 closed until these are addressed:
- `CoachClientAccessService` conflates backend/RPC failure with `not connected`.
- Client monitoring can silently convert notes/session/metrics/meals subsection errors into empty/zero data.
- My Clients needs persistent Error + Retry rather than normal empty UI after load failure.
- Coach Notes can show false empty states after load failure.
- Coach Notes role classification must use authoritative profile/server role truth instead of `userMetadata.role`.
- Nutritionist-specific `share_nutrition_with_nutritionist` flow still needs full end-to-end verification.
- Reviews Home count/average is based on the loaded review list; introduce a server-authoritative aggregate/count before review volume can exceed the preview RPC limit.
- A dedicated View All Reviews screen is optional for V1 unless product scope requires it; the Home review surface itself is required and is now implemented.
