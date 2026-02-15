# Referral Deep Link Domain Setup

Host these files at `https://www.cotrainr.com/.well-known/` for App Links (Android) and Universal Links (iOS).

## 1. Android: assetlinks.json

**URL:** `https://www.cotrainr.com/.well-known/assetlinks.json`

**Template:** See `.well-known/assetlinks.json`

**Replace:**
- `package_name` → `com.example.cotrainr_flutter` (from `android/app/build.gradle.kts` applicationId)
- `sha256_cert_fingerprints` → Array of SHA-256 fingerprints:
  - **Debug:** `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` (Windows: `%USERPROFILE%\.android\debug.keystore`)
  - **Release:** From your release keystore or Google Play App Signing (Play Console → Setup → App signing)

**Content-Type:** Must be served as `application/json`

## 2. iOS: apple-app-site-association

**URL:** `https://www.cotrainr.com/.well-known/apple-app-site-association`

**Template:** See `.well-known/apple-app-site-association`

**Replace:**
- `REPLACE_WITH_TEAM_ID` → Your Apple Developer Team ID (e.g. `ABCD1234`)
- `REPLACE_WITH_BUNDLE_ID` → e.g. `com.example.cotrainrFlutter` (from Xcode)

**Content-Type:** Must be served as `application/json` (no file extension)

**Xcode:** Add Associated Domains capability: `applinks:www.cotrainr.com`

## 3. Fallback when Universal Links not set up

Host a page at `https://www.cotrainr.com/invite` that:
- Reads `?code=X` from URL
- Redirects to `cotrainr://invite?code=X` or shows "Open in App" button
- Ensures `https://www.cotrainr.com/invite?code=X` works even before assetlinks/apple-app-site-association are configured

## 4. Verification

- **Android:** https://developers.google.com/digital-asset-links/tools/generator
- **iOS:** https://search.developer.apple.com/appsearch-validation-tool/
