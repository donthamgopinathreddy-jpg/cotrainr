# Cotrainr Android v1.0 Release Checklist

This checklist is the canonical pre-release gate for the Android launch. Do not mark the release READY while any P0 or P1 item remains unresolved.

## Identity and versioning
- [x] Application ID: `com.cotrainr.app`
- [x] App name: Cotrainr
- [x] Initial release version: `1.0.0+1`
- [ ] Increment Android versionCode for every Play Console upload after build 1
- [ ] Confirm production icon, adaptive icon and splash assets on release build

## Signing
- [ ] Create a dedicated Android upload keystore locally/off-repository
- [ ] Create local `android/key.properties` with upload key configuration
- [x] `.gitignore` excludes `key.properties`, `.jks` and `.keystore` files
- [ ] Replace debug signing in the release build with the upload signing configuration
- [ ] Enrol/use Google Play App Signing
- [ ] Back up the upload key securely outside the repository

Never commit keystore files or signing passwords.

## Security gate
- [ ] Zero unresolved P0 findings
- [ ] Zero unresolved P1 findings
- [ ] RLS/grants verified for public-schema application tables
- [ ] SECURITY DEFINER RPCs/views reviewed and least-privilege EXECUTE enforced
- [ ] Storage buckets and object policies reviewed
- [ ] Edge Functions authentication/authorization reviewed
- [ ] OAuth tokens and pending states protected
- [ ] Account suspension/ban/deletion verified end-to-end
- [ ] No production secrets in repository or Flutter client

## Authentication and onboarding
- [ ] Fresh Member signup/login/onboarding passes
- [ ] Fresh Trainer signup/login/onboarding passes
- [ ] Fresh Nutritionist signup/login/onboarding passes
- [ ] Google OAuth passes on release build
- [ ] Microsoft/Azure OAuth passes on release build
- [ ] Password reset passes on release build
- [ ] Role assignment cannot be escalated through untrusted auth metadata
- [ ] Legal acceptance versions are persisted server-side

## Core MVP flows
- [ ] Discover/public provider profiles
- [ ] Connection request/accept/decline/cancel/end/reconnect
- [ ] Subscription connection allowance enforcement
- [ ] Messaging text/image/camera/voice
- [ ] Video sessions + Google Meet
- [ ] Notifications + preferences + reminders
- [ ] Health metrics without duplicate/fabricated data
- [ ] Meal tracker
- [ ] Partner Centres + Cotrainr Pass
- [ ] Community Events registration

## Android permissions and health
- [ ] Permission declarations match features actually shipped
- [ ] Runtime permission prompts are contextual
- [ ] Health Connect permissions match actual read/write behavior
- [ ] Android 13 health/step behavior verified on real device
- [ ] Android 14+ Health Connect verified on real device
- [ ] Health permission rationale/privacy disclosures are accurate

## Privacy, legal and user controls
- [ ] Public privacy policy URL is live and accessible without login
- [ ] Terms of Service URL is live
- [ ] In-app Privacy Policy and Terms links work
- [ ] In-app account deletion works
- [ ] Public web account-deletion instructions/page is live if required by Play policy
- [ ] Data retention/deletion behavior matches the privacy policy
- [ ] Contact/support email is monitored

## Google Play Console
- [ ] Store listing name, short description and full description
- [ ] App icon, feature graphic, phone screenshots
- [ ] App category and contact details
- [ ] Privacy policy URL
- [ ] Data safety form accurately reflects Supabase/Firebase/health/location/media data
- [ ] Health apps declaration/permissions requirements completed where applicable
- [ ] App access instructions supplied if review needs an authenticated account
- [ ] Content rating questionnaire
- [ ] Ads declaration
- [ ] Target audience declaration
- [ ] Account deletion declaration completed
- [ ] Sensitive permission declarations completed where applicable

## Release artifact
- [ ] `flutter analyze` clean of release-blocking findings
- [ ] Relevant tests pass
- [ ] Signed release AAB builds successfully
- [ ] Release build installed through Play internal testing
- [ ] OAuth/deep links tested from Play-installed build
- [ ] Push notifications tested from Play-installed build
- [ ] No debug-only markers or test endpoints visible
- [ ] Crash/startup smoke test completed

## Final gate
Release is READY only when all P0/P1 findings are closed and the signed Play internal-test build passes the three-role end-to-end test.
