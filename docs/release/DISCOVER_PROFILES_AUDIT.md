# Area 05 — Discover / Profiles Release Audit

Status: CODE AUDIT COMPLETE — OPEN ITEMS REQUIRE CURSOR / DEVICE VERIFICATION
Branch: security/pre-release-hardening
Platform priority: Android first

This audit follows the permanent 10-state UI rule, responsive/overflow rule, UI production-readiness gate, and release execution rule. Every finding is classified as PASS / FIXED BY ME / CURSOR-LOCAL REQUIRED / NOT APPLICABLE.

## Scope
- Client Discover root
- Trainers / Nutritionists / Partner Centres tabs
- Search / filters / location fallback
- Discover provider cards
- Request / cancel / entitlement UI
- Public provider profile
- Provider reviews and certifications presentation
- Messaging / connection CTA visibility
- Public profile navigation/data fallbacks
- Responsive/light-dark/reduced-motion/device checks

## Discover root — PASS

- Initial provider loading has skeleton treatment.
- Whole-provider load failure has explicit error state + Retry.
- Search/filter empty is differentiated from genuine no-provider state.
- Connected providers are excluded from Discover and a dedicated connected-empty state links to My Trainers / My Nutritionists.
- Location denial/unavailable degrades to browse mode rather than blocking discovery.
- Trainer vs nutritionist specialty filters are scoped independently.
- Provider rows are de-duplicated by provider ID.
- Nearby/browse sorting is deterministic: distance first, then name.
- Request actions have per-provider submitting locks.
- Server remains authoritative for nutritionist eligibility and connection allowance; unknown entitlement state does not invent a local block.
- Accepted relationships are not shown as fresh request targets.
- Public provider navigation passes fallback display name and provider type, while the destination still fetches authoritative profile data.

## MAJOR — Discover refresh still presents two simultaneous loading treatments

Classification: CURSOR-LOCAL REQUIRED
File: `lib/pages/discover/discover_page.dart`

Confirmed behavior:
- `RefreshIndicator.onRefresh` calls `_loadRealData()`.
- `_loadRealData()` immediately sets `_isLoading = true` and clears `_trainers`, `_nutritionists`, `_centers`.
- Build then replaces existing cards with `_DiscoverLoadingHeader` + four skeleton cards while the pull-to-refresh spinner is already active.

Required change:
- Split `initialLoading` from `refreshing` (or pass a `showInitialLoading` flag).
- Initial first load with no usable data may show skeletons.
- Pull-to-refresh must preserve existing good cards and use the RefreshIndicator as the dominant refresh treatment.
- Apply refreshed lists atomically after successful fetch.
- Refresh failure must preserve previous good content and show a non-destructive degraded/error notice rather than replacing it with a full empty/error page.

Acceptance:
- Pull refresh never shows RefreshIndicator + initial skeleton replacement together.
- Existing cards remain visible while refreshing.
- Refresh failure does not erase previously loaded providers/centres.
- Initial cold load still has a clear loading state.

## MAJOR — Partner-centre fetch failure is currently rendered as real empty data

Classification: CURSOR-LOCAL REQUIRED
File: `lib/pages/discover/discover_page.dart`

Confirmed behavior:
- `listForDiscover()` is wrapped in an inner catch.
- Failure only logs in debug and leaves `_centers` empty.
- Selecting Centres can therefore show `No Partner Centres yet` even though the actual condition is a network/RPC/backend failure.

Required change:
- Add a centre-specific load/degraded state (`_centersError` or equivalent).
- A provider-fetch success must not hide a centre-fetch failure.
- When Centres is selected and centre fetch failed, show centre-specific error copy + Retry.
- Preserve prior good centre data during refresh failure where available.
- Genuine successful zero rows may use `No Partner Centres yet`.

Acceptance:
- Disable/network-fail centre RPC -> user sees Retry/error, never authoritative zero.
- Successful zero-row response -> genuine empty copy.
- Provider tabs can remain usable if only centres failed.

## MAJOR — Public profile converts network failures into apparently authoritative defaults

Classification: CURSOR-LOCAL REQUIRED
File: `lib/pages/profile/public_profile_readonly_page.dart`

Confirmed behavior:
- `_profile` is initialized immediately as a synthetic `ProviderProfessionalProfile` using `widget.userId`, fallback role and fallback title.
- `_withTimeout()` returns `null` for timeout/errors.
- Profile fetch failure can therefore leave the synthetic provider visible with default values.
- Certifications failure becomes `[]`.
- Reviews failure becomes `[]`.
- Accepted client-count failure becomes `0` unless a fallback query succeeds.
- Entitlement / relationship / rating permission failures silently become false/null defaults.
- `_load()` has no explicit `_loadError` / `_hasLoadedAuthoritativeProfile` state.

Impact:
A failed public profile load can look like a real provider with zero clients, no reviews, no certifications, no detailed bio, and default provider characteristics. This violates the release rule: unknown/error must not be presented as authoritative empty/zero/default data.

Required change:
1. Add `_hasLoadedProfile`, `_profileLoadError`, and section-specific degraded states where appropriate.
2. Fallback route title may paint as a lightweight identity placeholder during first load, but must be visually identifiable as loading/degraded rather than authoritative profile content.
3. If authoritative profile lookup fails and no previously good profile exists:
   - show an inline/full profile error with Retry;
   - disable Request/Message/Review actions that depend on authoritative provider state;
   - do not show 0 clients / no reviews / no certifications as confirmed facts.
4. If a refresh fails after a good load, retain good data and show a non-destructive refresh failure state.
5. Keep independent sections resilient: reviews failing should not destroy profile identity; certs failing should not make the whole profile unusable.

Acceptance:
- Network-off first open cannot present a fully normal provider profile with fake zeros.
- Previous good profile survives refresh failure.
- Review/certification fetch failure is distinguishable from genuine zero items.
- Connection CTAs only use authoritative provider/relationship state.

## MAJOR — Public profile refresh can show duplicate loading treatment

Classification: CURSOR-LOCAL REQUIRED
File: `lib/pages/profile/public_profile_readonly_page.dart`

Confirmed behavior:
- Page uses `RefreshIndicator(onRefresh: _load)`.
- `_load()` sets `_refreshing = true`.
- Header also displays an 18x18 `CircularProgressIndicator` when `_refreshing`.

Required change:
- On pull-to-refresh, use only the RefreshIndicator unless a separate section-specific background refresh indicator has a distinct purpose.
- Header spinner may be kept for non-pull background refresh only if state ownership is explicit.

Acceptance:
- Pull refresh has one dominant spinner.
- No simultaneous top RefreshIndicator and header spinner for the same operation.

## Data / provider eligibility — PASS WITH BACKEND DEPENDENCY

- Discover repository calls `nearby_providers` and `discover_providers` RPCs.
- Browse repository documentation states verified + discoverable providers.
- UI surfaces `verified` from returned provider data and uses the verified badge accordingly.
- `create_lead_tx` has already been hardened separately so a request cannot create a connection lead to a non-verified provider even if UI/server listing were stale.

Backend function bodies/RLS remain subject to Areas 13/14. Area 05 does not mark backend security complete.

## Discover provider card — PASS / LOCAL POLISH

File: `lib/widgets/provider/discover_provider_card.dart`

Good:
- Long provider name uses ellipsis.
- Headline is capped to two lines.
- Specialty chips wrap.
- metadata uses Wrap.
- CTA is full-width and submitting state is explicit.
- pending request has cancel state.
- verified badge is based on returned `verified`.
- plan/upgrade treatment is explicit.

CURSOR / device polish:
- Ensure effective CTA height reaches 48dp (currently source minimum is 46dp).
- Respect `MediaQuery.disableAnimationsOf(context)` for press AnimatedScale.
- Verify metadata/location row at 320dp and large text. Long location must never push session-mode text offscreen or overflow.
- Plan badge currently uses 10sp; verify readability and raise toward 11–12sp where practical.
- Verify `foregroundColor: Colors.black` on Discover accent CTA retains contrast for all intended accent variants. Do not change semantic accent colors without contrast evidence.

## Public profile connection/messaging actions — PASS WITH STATE-TRUTHFULNESS FIX REQUIRED

- `Request` is disabled when provider is authoritatively not accepting clients.
- pending relationship shows Cancel.
- accepted relationship transitions primary action to Message.
- message creation is server/service gated.
- rate/review control appears only when the relationship policy allows rating.
- nutritionist plan gating uses server entitlement when known; unknown state reaches authoritative backend rather than inventing a deny.

Once profile/relationship load-error states are introduced, actions must remain disabled until their dependencies are authoritative.

## Public reviews/certifications — PARTIAL

Classification: CURSOR-LOCAL REQUIRED

Current code handles success and genuine empty presentation, but fetch errors are converted to empty lists.

Required behavior:
- successful `[]` -> `No reviews yet` / no certifications as appropriate;
- request failure -> section error/degraded copy + Retry or retained previous data;
- loading -> skeleton/progress only for that section if needed;
- never represent request failure as confirmed zero.

## Navigation / ID safety carry-forward

Classification: CURSOR-LOCAL REQUIRED (already recorded in Area 03)

Route `/providers/:providerId` accepts arbitrary strings and public profile constructs a fallback object immediately. Add UUID validation/invalid-profile recovery in the routing/navigation hardening task so malformed deep links do not create a plausible fake provider screen.

## 10-state classification

### Discover
1 Default/normal — PASS
2 Initial loading — PASS
3 Refreshing — CURSOR-LOCAL REQUIRED (double treatment)
4 Empty — PASS except centres failure ambiguity
5 Error — PASS provider-wide; CURSOR-LOCAL REQUIRED centres-specific
6 Retry — PASS provider-wide; CURSOR-LOCAL REQUIRED centres-specific
7 Success action — PASS request/cancel feedback
8 Disabled/unavailable — PASS per-provider submitting / entitlement UI
9 Partial/degraded — PARTIAL; location degrade PASS, centres error FAIL
10 Offline/slow/interrupted — PARTIAL; provider failure handled, refresh preservation pending

### Public provider profile
1 Default/normal — PASS after authoritative load
2 Initial loading — CURSOR-LOCAL REQUIRED (synthetic fallback currently appears normal)
3 Refreshing — CURSOR-LOCAL REQUIRED (duplicate spinner)
4 Empty — PARTIAL; sections cannot distinguish failed from zero
5 Error — CURSOR-LOCAL REQUIRED profile/section errors
6 Retry — CURSOR-LOCAL REQUIRED
7 Success action — PASS request/cancel/review/message feedback paths
8 Disabled/unavailable — PASS for known accepting/busy states; must also disable while authority unknown
9 Partial/degraded — CURSOR-LOCAL REQUIRED
10 Offline/slow/interrupted — CURSOR-LOCAL REQUIRED

## Responsive / accessibility / visual-device matrix

Mandatory local verification:
- 320dp narrow phone
- 360dp Android
- 393/412dp tall phone
- tablet/foldable-width emulator safety
- normal + large accessibility font
- light + dark
- reduced motion
- gesture + 3-button navigation
- long provider name, long headline, long specialty, long city/location
- broken avatar URL / no avatar
- Discover loading/error/search-empty/true-empty/connected-empty
- public profile loading/error/long bio/no bio/reviews/no reviews/certs/no certs

No RenderFlex/overflow exceptions are acceptable.

## Priority before Android release

P0/P1:
1. Separate Discover initial loading from refresh.
2. Add centre-specific failure/degraded state.
3. Make public profile authoritative-load/error state explicit; remove fake-zero/default presentation.
4. Distinguish reviews/certs request failure from genuine empty.
5. Remove duplicate public-profile refresh spinner treatment.

P2 polish:
6. Discover card 48dp CTA + reduced motion.
7. Validate small metadata typography and long location wrapping.
8. Cap/disable Discover list entrance stagger under reduced motion (already recorded in primary UI audit).

## Final Area 05 verdict

Discover/profile happy paths are substantially implemented and business-state mapping is generally coherent, but Area 05 is NOT 100% release-ready until the data-truthfulness and refresh-state issues above are implemented and physically verified.

Do not mark this area FIXED merely because this instruction file exists. Cursor/local fixes must be pulled back into `security/pre-release-hardening`, reviewed, formatted/analyzed, and device-tested before closure.
