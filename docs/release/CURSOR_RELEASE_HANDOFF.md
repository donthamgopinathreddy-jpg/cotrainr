# Cursor / Local Release Handoff

Use this only after pulling `security/pre-release-hardening`. Do not manually recreate fixes already present on the branch and do not replay already-applied production migrations against production.

## Mandatory local verification

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then verify Android release configuration and build the release candidate with the project's supported Flutter/Gradle commands.

## Android signing — local secret only
1. Generate the permanent Google Play upload keystore on the release machine.
2. Create `android/key.properties` from the committed example.
3. Keep the keystore and real passwords out of Git/GitHub.
4. Build a signed Android App Bundle.
5. Inspect the resulting artifact/package ID/version/signing certificate before upload.

## Visual/device matrix
Test at least one modern Android device/emulator in both Light and Dark modes, with font/display scaling increased once for overflow checks.

For Client, Trainer and Nutritionist, exercise every reachable release screen and verify:
- normal, pressed, selected, disabled and loading controls;
- switches visibly show ON/OFF;
- custom chips/segments/tabs visibly show selection;
- keyboard does not cover required controls;
- dialogs/bottom sheets respect safe areas;
- no clipped/overflowing text;
- empty/error/offline states do not expose raw exceptions;
- back navigation never exits or jumps unexpectedly from a nested flow;
- destructive actions require appropriate confirmation.

## E2E release paths
- fresh signup and onboarding for each role;
- login/logout/session restore/reset password;
- provider verification gating;
- discover/profile/connection flow;
- messaging authorization;
- meals/hydration/health permission grant + deny + unavailable;
- Google Meet connect/create/join/respond/cancel/edit;
- push notification foreground/background/terminated behaviour;
- nearby centres with location allowed/denied;
- partner pass/offers/verification;
- account deletion with a disposable test account.

## Report back
For every failure, capture:
- role;
- route/screen;
- light or dark mode;
- exact reproduction steps;
- expected vs actual;
- screenshot/log excerpt where useful;
- `flutter analyze` / test output if relevant.

Do not suppress analyzer/test failures just to produce an AAB. Classify and fix them or explicitly record why they are safe.
