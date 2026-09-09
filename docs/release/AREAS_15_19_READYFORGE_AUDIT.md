# Cotrainr ReadyForge Audit — Areas 15–19

Branch: `security/pre-release-hardening`
Platform: Android first
Production backend: live Supabase project `nvtozwtuyhwqkqvftpyi`
Audit method: ReadyForge production-auditor skill

Trace rule used throughout:

`UI -> interaction -> state/provider -> repository/service -> RPC/Edge Function -> auth/authz -> RLS -> DB/storage -> failures -> device behavior -> release config`

A code change is not treated as proof of device/store readiness. Physical-device and Play Console checks remain MANUAL/BLOCKED until performed on the signed release artifact and real Play app.

---

## 15. Privacy / Account Deletion

### FIXED — Google integration revocation during full deletion

Production `delete-account` is JWT protected and derives the actor from the verified session; the client does not supply a user id.

The function already handled storage and the explicit non-cascade references required before deleting `auth.users`. Production FK inspection confirmed the known non-cascade references are deliberately handled.

Gap fixed in this audit:
- Account deletion previously removed `user_integrations_google` by database cascade but did not first revoke the external Google OAuth grant.
- `delete-account` now loads the authenticated user's stored Google integration token and best-effort calls Google's OAuth revoke endpoint before the database row disappears.
- No token value is logged.
- Google revocation failure does not deny a user the right to delete their Cotrainr account.
- The updated Edge Function was deployed to production with JWT verification enabled.

### FIXED — local persisted user state after server deletion

`lib/services/account_deletion_service.dart` now performs best-effort local cleanup after the server confirms `{ok: true}`:
- cancels Cotrainr water reminders
- clears `SharedPreferences`
- clears remaining local Supabase auth state

Reason: user-specific goals/preferences/reminder state must not leak into a later account on the same Android device.

### PASS — destructive UI baseline

`lib/pages/profile/settings/privacy_security_page.dart` currently:
- requires an explicit destructive confirmation
- describes the deletion as permanent/non-reversible
- disables settings interactions while deletion is running
- shows an in-progress indicator
- routes to `/welcome` only after server success
- reports recoverable failure via snackbar and re-enables the action

### MANUAL / LOCAL REQUIRED — deletion lifecycle and policy evidence

1. Test Android system/predictive Back while `_deletingAccount=true`. The deletion transaction must not produce duplicate calls or misleading navigation.
2. Test offline/timeout/server-500 and recovery.
3. Use a sacrificial production-like account containing:
   - profile/provider data
   - messages/connections
   - meals/metrics
   - video sessions
   - notifications/device token
   - partner claim/redemption where applicable
   - uploaded avatar/chat/post/verification files
   - Google Meet integration
4. Delete the account from the signed release build.
5. Verify:
   - `auth.users` row gone
   - owned operational rows gone or intentionally anonymized/retained
   - storage objects gone
   - device tokens gone
   - Google integration grant revoked/best-effort invalidated
   - app returns signed out
   - reinstall/re-login with a different account receives no stale local preferences/reminders

### BLOCKED — external account-deletion web resource

Google Play requires apps that allow account creation to provide both an in-app deletion path and a functional web resource where a user can request deletion without reinstalling the app.

No public Cotrainr deletion page was found during this audit.

Required before submission:
- publish a public non-auth-gated page, recommended path: `https://www.cotrainr.com/delete-account`
- page must clearly identify Cotrainr/developer
- provide a real deletion-request path without forcing app reinstall
- document what is deleted and any deliberately retained records/retention period
- enter this URL in Play Console Data safety/account deletion

### BLOCKED — public privacy policy

Cotrainr handles health/fitness, location, authentication and user-generated data. The in-app policy alone is insufficient for Play health-policy submission.

Required before submission:
- active public HTTPS privacy policy, recommended path: `https://www.cotrainr.com/privacy`
- non-geofenced, publicly accessible, not a PDF
- identify Cotrainr/developer
- disclose health/fitness data types, location, account/profile, messages/uploads, notifications/device tokens, integrations
- disclose purpose/use/sharing, security, retention/deletion, user controls/contact
- ensure in-app policy and Play Data safety answers match the live implementation

### Current ReadyForge estimate: 89%

Not 100% until public policy/deletion resources and signed-device deletion proof exist.

---

## 16. Android Production Configuration

### PASS / VERIFIED IN SOURCE

`android/app/build.gradle.kts`:
- namespace: `com.cotrainr.app`
- applicationId: `com.cotrainr.app`
- compileSdk: 36
- targetSdk: 36
- minSdk: 26
- Java/Kotlin target: 17
- release signing is separate from debug

`android/app/google-services.json` package was checked against `com.cotrainr.app`.

`.gitignore` explicitly excludes:
- `android/key.properties`
- `android/*.jks`
- `android/*.keystore`
- app-level JKS/keystore files
- local `.env*` except example files

### FIXED — fail closed for Play AAB signing

Previously the explicit missing-keystore guard covered `assembleRelease` but not the Play Store AAB path.

`android/app/build.gradle.kts` now applies the release-signing guard to both:
- `assembleRelease`
- `bundleRelease`

A release AAB cannot intentionally proceed without the real local upload/release keystore configuration.

### FIXED — manifest privacy / Play permission hardening

`android/app/src/main/AndroidManifest.xml` was tightened:
- removed broad `READ_MEDIA_IMAGES`
- removed broad `READ_MEDIA_VIDEO`
- removed legacy broad storage permissions
- removed `RECORD_AUDIO` because no active microphone/audio-recording code path was found in the current MVP
- retained CAMERA for the existing image-picker camera path
- gallery selection relies on the system picker path
- added `android:allowBackup="false"`
- added `android:fullBackupContent="false"`
- added `android:usesCleartextTraffic="false"`
- retained required location, activity recognition, Health Connect read, notification, boot and vibration permissions

This reduces unnecessary sensitive-permission surface and Play review burden.

### PASS — deep-link manifest inventory

Current manifest includes:
- `cotrainr://insights/water`
- `cotrainr://invite`
- `cotrainr://video/google-connected`
- `cotrainr://auth-callback`
- `cotrainr://reset-password`
- HTTPS `https://www.cotrainr.com/invite` app link with `autoVerify=true`
- Health Connect rationale/permission usage intents

### CURSOR / LOCAL ACTION REQUIRED — production diagnostics

File: `lib/router/app_router.dart`

Issue:
- `debugLogDiagnostics: true` is unconditional.

Required change:
1. import `package:flutter/foundation.dart`.
2. change to `debugLogDiagnostics: kDebugMode`.
3. run `flutter analyze` and route/deep-link tests.

Acceptance:
- verbose GoRouter diagnostics available in debug
- not enabled in production release.

### MANUAL / LOCAL REQUIRED — signed AAB

Real upload keystore must remain outside Git, therefore this environment cannot prove final signing.

Run locally with the actual upload key:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Acceptance:
- `build/app/outputs/bundle/release/app-release.aab` produced
- bundle signed by intended upload key
- package `com.cotrainr.app`
- versionCode greater than any version already uploaded to Play
- release installs/launches through an Internal Testing delivery, not only local debug APK.

### MANUAL / DASHBOARD REQUIRED

- verify Play App Signing enrollment/upload certificate
- add/verify production SHA fingerprints used by Firebase/Google OAuth as applicable
- host/verify `assetlinks.json` for `www.cotrainr.com`
- test HTTPS invite app link on signed Play-distributed build
- verify launcher icon/splash across densities

### Current ReadyForge estimate: 92%

---

## 17. Code / Legacy Cleanup

### KEEP HISTORICAL

- Supabase migration history, including historical Zoom/CoCircle/Quest migrations. Do not delete/replay historical migrations merely to make the tree look cleaner.

### KEEP FUTURE

- CoCircle / Quest data/code deliberately hidden behind MVP feature controls where still retained for later product work.

### PASS / ACTIVE ZOOM SURFACE

Authoritative hardening-branch checks found:
- active `zoom_integration_provider.dart` absent
- active `supabase/functions/zoom-oauth-start` absent
- live Supabase Edge Function inventory contains no Zoom OAuth/session function

The legacy `user_integrations_zoom` database table may remain until dependency proof supports a future forward migration. Its existence alone is not a release blocker while client grants remain hardened and no live app path uses it.

Classification: DEFER removal until dependency proof.

### CURSOR / LOCAL ACTION REQUIRED — debug logging cleanup

Repo scan still finds production `print(...)`/debug-style logging in multiple Flutter services/bootstrap/repositories.

Required approach:
- do not blindly remove operational error logging
- replace production `print` with controlled logger or `if (kDebugMode) debugPrint(...)` where the message is only diagnostic
- never log tokens, auth headers, health values tied to identity, message bodies or private user content
- run `flutter analyze` after cleanup.

### CURSOR / LOCAL ACTION REQUIRED — dependency proof

`pubspec.yaml` contains `record` and `just_audio`; current code search did not locate active usages.

Do not remove based on search alone. Locally prove with:
- IDE/reference search
- `flutter pub deps`
- `flutter analyze`
- `flutter test`
- debug build
- release AAB build

If no runtime/indirect feature depends on them, classify SAFE DELETE and remove in one dependency-cleanup commit.

### CURSOR / LOCAL ACTION REQUIRED — TODO/FIXME and dead route sweep

Before release, run a full local indexed search for:
- `TODO`
- `FIXME`
- `print(`
- `debugPrint(`
- `debugLogDiagnostics`
- `zoom`
- `academy`
- hidden CoCircle/Quest routes
- test-only/dev-only endpoints

Every result must be classified:
- SAFE DELETE
- KEEP ACTIVE
- KEEP FUTURE
- KEEP HISTORICAL
- DEFER WITH REASON

No code/database object should be deleted without dependency proof.

### Current ReadyForge estimate: 83%

---

## 18. Physical-device / E2E Verification

### MANUAL — PHYSICAL SIGNED ANDROID DEVICE REQUIRED

This area cannot be legitimately completed by repository/database inspection. The authoritative artifact must be the same signed release AAB delivered through Play Internal Testing.

Required matrix:

### Install / lifecycle
- fresh install
- upgrade install from previous test version
- cold start / warm start
- background/foreground
- process kill/relaunch
- logout/login account switching
- Android predictive back
- gesture navigation
- 3-button navigation

### Auth / onboarding
- email signup
- email login/logout
- forgot/reset password deep link
- email confirmation if enabled
- Google OAuth
- Apple/Microsoft only if enabled for Android/release scope
- incomplete-profile direct deep link
- restricted/suspended account direct deep link
- client onboarding
- trainer onboarding + verification
- nutritionist onboarding + verification

### Primary UI matrix
For Home, Discover/My Clients, Messages, Meals and Profile:
- default
- loading
- refreshing
- empty
- error
- retry
- success
- disabled
- degraded/cached
- offline/interrupted

Also:
- 320dp
- 360dp
- 393–412dp
- large text / accessibility scale
- light/dark/system
- keyboard/IME
- reduced motion
- TalkBack/semantics
- long names/content
- no double refresh/loaders
- no pixel/RenderFlex overflow

### Connections / messaging
- request/decline/cancel does not consume allowance
- provider accept consumes correct UTC-month allowance
- client end <=7 days restores
- later client end does not restore
- provider end restores
- same pair/period restore max once
- subscription-gated messaging
- real-time messages/unread
- blocked/disconnected states
- account A cannot read/write account B data

### Meal / hydration / health
- rapid date changes do not show wrong day
- offline/error states truthful
- hydration quick log
- concurrent water updates once atomic path is completed
- Health Connect absent/denied/granted/no-data/live-data
- steps/calories/distance/water truthfulness
- no fabricated zero for unavailable data

### Video / Google Meet
- connect Google cold/warm return
- create single/group session
- edit/reschedule
- cancel
- join
- participant accept/reject + reason
- revoked/expired Google integration
- offline/slow network
- app background/killed

### Notifications
- permission denied/granted/settings return
- token refresh
- account switch
- foreground/background/killed
- session-created notification
- 5-minute reminder
- start reminder
- Join action
- Reject action
- cold-start action
- preferences OFF
- master push OFF
- no duplicate delivery
- no cross-account token delivery

### Partners
- full Cotrainr Pass ID + copy
- narrow/large-text layout
- valid member lookup
- invalid pass
- claim
- offer redemption
- duplicate redemption
- inactive account
- audit trail

### Deletion
- execute full deletion matrix from Area 15 using sacrificial account.

### Release acceptance
- zero crash in primary paths
- zero critical/high security regression
- no cross-user data access
- no release-only deep-link/OAuth/notification failure
- no blocker overflow/accessibility issue

### Current ReadyForge estimate: 52%

Repository/live-backend evidence helps define the matrix but does not replace physical execution.

---

## 19. Google Play Release

### CURRENT STATE

No Fastlane/Android Publisher release lane or source-controlled Play metadata was found in the Cotrainr repository during this audit.

Cotrainr is not yet ready for Play submission because the following evidence is still absent:
- signed release AAB from the real upload key
- Play Internal Testing upload/install evidence
- public privacy policy URL
- public external account deletion resource
- completed Data safety answers aligned to live implementation
- completed Health apps declaration
- final Health Connect permission justifications
- content rating / target audience / ads declarations
- app access/test account where needed
- final screenshots/feature graphic/store metadata
- pre-launch report

### REQUIRED RELEASE ORDER

1. `flutter analyze`
2. `flutter test`
3. build signed AAB
4. ReadyForge release gate: zero CRITICAL/HIGH unresolved software blockers
5. create/update Play metadata from source control
6. upload exact tested AAB to Internal Testing
7. install from Play and execute Area 18 matrix
8. review Play pre-launch report
9. fix blockers and increment versionCode for replacement build if needed
10. promote same verified release through chosen test track
11. commit Play edit / submit changes for review
12. after approval, use staged production rollout
13. monitor crash/ANR/review/rollout state
14. halt rollout on release-health regression
15. progress staged rollout only when release gate remains healthy.

### READYFORGE AUTOMATION TARGET

ReadyForge should own the reproducible Play path once Google Play Developer API credentials are configured outside Git:

```text
readyforge audit
readyforge release-check android
readyforge build android
readyforge play metadata validate
readyforge play metadata sync
readyforge play deploy internal
readyforge play promote closed
readyforge play submit-review
readyforge play promote production --rollout 0.10
readyforge play rollout halt
readyforge play rollout --to 0.25
readyforge play rollout --to 0.50
readyforge play rollout --to 1.00
```

The release manifest must bind:
- Git commit SHA
- app version/versionCode
- AAB SHA-256
- signing/upload certificate identity
- ReadyForge audit result
- metadata revision
- Play track/release id
- submission/review state
- rollout percentage

ReadyForge must never silently promote to production. Production promotion requires an explicit release command/approval and all configured gates passing.

### MANUAL / PLAY CONSOLE REQUIRED FOR INITIAL SETUP

No Play Console/Android Publisher connector is available in the current ChatGPT environment, so no actual upload/review submission is claimed here.

Initial owner actions still required where Google requires human declarations/account setup:
- create/verify Play app entry for package `com.cotrainr.app`
- Play App Signing setup
- Google Play Developer API/service-account access with least privilege
- developer identity/legal agreements
- Data safety review
- Health apps declaration
- content rating
- target audience
- ads declaration
- app access instructions
- country/pricing/distribution settings as applicable
- production release approval policy.

Credentials/service-account JSON must never be committed to Git. Store in CI secret management.

### POLICY BLOCKERS

Cotrainr contains fitness, nutrition and Health Connect features. Google Play requires a Health apps declaration, and health apps must publish a public privacy policy describing sensitive data practices. Health Connect access must be limited to user-facing necessary data types.

Apps that create accounts must also expose an external web account-deletion resource in addition to the in-app deletion path.

### Current ReadyForge estimate: 58%

---

# Final 15–19 Readiness

| Area | Baseline | ReadyForge current | Status |
|---|---:|---:|---|
| 15 Privacy / account deletion | 70% | 89% | software cleanup improved; policy URLs + device proof open |
| 16 Android production config | 80% | 92% | manifest/signing hardened; signed AAB/device evidence open |
| 17 Code / legacy cleanup | 70% | 83% | active Zoom removed; logging/dependency/local proof open |
| 18 Physical-device / E2E | 50% | 52% | matrix defined; signed-device execution still required |
| 19 Play Store release | 45% | 58% | release path defined; Play setup/metadata/policies/upload not executed |

## Release verdict

**NOT READY FOR GOOGLE PLAY SUBMISSION YET.**

Primary remaining blockers before Internal Testing/review:
1. publish public privacy policy
2. publish external account-deletion web resource
3. resolve inherited P0/P1 frontend issues from Areas 1–14
4. rotate/move reminder cron credential to secret management
5. enable/review Auth leaked-password protection where available
6. run local analyze/tests and build with real upload keystore
7. upload signed AAB to Play Internal Testing
8. execute full Area 18 physical-device matrix
9. complete Data safety + Health apps declarations and other Play policy forms
10. configure ReadyForge/Android Publisher release automation or use Play Console for the first release.
