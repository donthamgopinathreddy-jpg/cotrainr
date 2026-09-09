# Areas 20–21 ReadyForge Remediation Record

Branch: `security/pre-release-hardening`

## Area 20 — Settings / Account Hub

### FIXED BY ME

1. Settings role/profile load truthfulness
   - File: `lib/pages/profile/settings_page.dart`
   - Commit: `4eb41440fa1c8f96363f8ee93c50377f44f8b411`
   - Added persistent account-role load failure state with Retry.
   - Provider-only rows are no longer silently hidden without explanation when role lookup fails.
   - Removed the release-facing `Billing History` Coming Soon row.

2. Notification settings load truthfulness
   - File: `lib/pages/profile/settings/notifications_page.dart`
   - Commit: `79cef8d95a3cb1e2065e8edbdb1622d9497d3e9e`
   - Added top-level load error + Retry instead of rendering default values after a failed load.
   - Added a dedicated video-session preference failure state + Retry.
   - Prevents video-session toggles being edited while their authoritative values are unavailable.
   - Added permission refresh failure feedback.

3. Health Connect / Apple Health load state
   - File: `lib/pages/profile/settings/health_devices_page.dart`
   - Commit: `e505457b73cede07e03e22f9d800b8e1b9bc11a2`
   - Added initial load error + Retry.
   - Added stale/last-known degraded-state banner when a later refresh fails.
   - Replaced raw exception text in user-facing permission error copy.
   - Added install failure feedback.

4. Privacy & Security load state
   - File: `lib/pages/profile/settings/privacy_security_page.dart`
   - Commit: `0e4138587b9e90e0083b6e888ebce130df4dbc95`
   - Added initial load error + Retry and disabled Save while source state is unavailable.
   - Added location permission refresh failure feedback.
   - Removed the release-facing `Download My Data` Coming Soon row.

### LIVE SUPABASE VERIFICATION

Production project: `nvtozwtuyhwqkqvftpyi`

Verified `public.profiles` contains:
- `role`
- `share_metrics_with_trainer`
- `share_meals_with_trainer`
- `share_nutrition_with_nutritionist`

No schema or policy change was required for the Area 20 UI-state fixes above.

### OPEN / CURSOR OR LOCAL VERIFICATION REQUIRED

- `PrivacyPreferencesService.load()` can deliberately fall back to SharedPreferences/default values after a Supabase read failure. The current store interface does not expose whether returned values are authoritative or cached. Add a source/degraded signal without breaking existing test fakes, then render a clear cached/offline state before allowing a server-affecting Save.
- Verify Change Password against the actual hosted Supabase password policy and improve server error mapping where required.
- Run `flutter analyze` and focused widget tests for Settings, Notifications, Privacy/Security and Health Devices.
- Physical Android: 320dp width, large font, offline, permission-denied/permanently-denied, background/resume, system Back/predictive Back, double-tap while saving.

## Area 21 — Trainer role / Provider device-preference audit

### CONFIRMED PROVIDER-ESSENTIAL SURFACES

Keep for Trainer and Nutritionist roles:
- Account / Edit Profile
- Privacy & Security
- Change Password
- Provider verification
- Professional profile / certifications
- Service locations and location permission needed for discoverability/service areas
- Notifications for messages, connection events and video sessions
- Google Meet integration
- My Clients / Requests
- Coach Notes
- Messaging
- Video Sessions
- Discover/public provider profile
- Account deletion / legal / support

### PERSONAL DEVICE/FITNESS SURFACES NOT REQUIRED TO OPERATE AS A PROVIDER

The current Trainer and Nutritionist experiences both initialize and display the user's personal fitness stack. This is not required for provider practice management and creates unnecessary Health Connect/device permission pressure for users who only use Cotrainr professionally.

Current examples:
- `lib/pages/trainer/trainer_home_page.dart`
- `lib/pages/nutritionist/nutritionist_home_page.dart`
- `lib/pages/profile/profile_page.dart`
- `lib/pages/profile/settings_page.dart`

Provider-role personal surfaces currently include:
- Health Connect / Apple Health connection
- automatic health metrics initialization/sync
- personal Steps / Active Calories / Water / Distance tiles
- personal BMI card
- personal streak
- personal fitness goals
- personal protein/coaching insight calculations
- Add Water action
- Water reminder preference
- personal Progress Snapshot / Goals cards in Profile

### RECOMMENDED PRODUCT CLEANUP

For Trainer/Nutritionist role, default the main provider experience to professional/practice data, not personal-device fitness data.

Recommended provider Home hierarchy:
1. Provider identity / verification state
2. Active clients + pending requests
3. Next video session
4. Messages / unread work
5. Coach notes / client actions
6. Community event / nearby partner centres if retained
7. Professional quick actions

Recommended provider Settings:
- Keep Account, Security, Notifications, Integrations, Service Locations, Legal/Support.
- Hide personal `Fitness` section (Goals & Preferences + Health Connect) from Trainer/Nutritionist unless Cotrainr intentionally supports a separate "use Cotrainr for my own fitness" mode.
- Hide `Water reminders` for provider-only users under the same rule.

Recommended provider Profile:
- Replace personal Goals / Progress Snapshot emphasis with professional profile completeness, verification, specialties, locations, certifications, client count and provider-plan/allowance status.

### DO NOT DELETE YET

Do not delete Health Connect, goals, BMI, metrics, water, meal or related backend code. Client role still uses them, and a future provider-as-client/self-fitness mode may reuse them. First hide/gate them by authoritative role and verify navigation/deep-link access.

### AREA 21 OPEN FINDINGS ALREADY CONFIRMED

- `TrainerHomePage._loadGoals()` lacks exception isolation; `_goalsReady` can remain false indefinitely.
- Trainer Home refresh can abort all unrelated refresh operations if metrics sync fails first.
- `CoachClientAccessService` maps RPC/network errors to `hasAcceptedLead=false`, which can incorrectly show `This client is not connected` instead of a backend error.
- Client monitoring swallows notes/session/metrics/meals subsection failures and can render false empty/zero states.
- My Clients can show its normal empty state after load failure; needs persistent Error + Retry.
- Trainer Coach Notes can show false `No clients yet` / empty notes after backend failure.
- Coach Notes derives provider type from user-editable/stale `userMetadata.role`; authorization/role truth must come from the authoritative server/profile model.

### REQUIRED ACCEPTANCE TESTS FOR PROVIDER DEVICE-PREFERENCE CLEANUP

Trainer and Nutritionist accounts with Health Connect never granted must be able to:
- complete login/onboarding
- open Home
- manage clients/requests
- message accepted clients
- schedule/join video sessions
- manage verification/professional profile/service locations
- receive required notifications
- use Settings

without being prompted for Health Connect or depending on personal metrics sync.

Client role must retain the existing health, goals, BMI, water and meal functionality.
