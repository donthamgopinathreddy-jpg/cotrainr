# Cotrainr Flutter App - Complete State Report

**Generated:** 2025-01-27  
**Repository:** cotrainr_flutter  
**Flutter SDK:** 3.10.4

---

## 1) One-Paragraph Summary

Cotrainr is a fitness and wellness platform Flutter app that connects clients with trainers, nutritionists, and fitness centers. The app supports Android (minSdk 26) and iOS platforms, with web/desktop platform folders present but not actively configured. The app uses Supabase as the backend (BaaS), Riverpod for state management, and GoRouter for navigation. Core features include health metrics tracking (steps, calories, water, distance via device sensors), meal logging, social feed ("Cocircle"), quest/achievement gamification, video sessions, messaging, and role-based dashboards for clients, trainers, and nutritionists. The app is currently in active development with many features implemented as UI stubs using mock data rather than real backend integration. No build flavors or environment configurations are present—Supabase credentials are hardcoded in source files.

---

## 2) Feature Inventory

| Feature | Status | Screens | Key Files | Backend Dependencies | Notes/Known Issues |
|---------|--------|---------|-----------|----------------------|-------------------|
| **Auth (sign up/in/out)** | **Partial** | `LoginPage`, `SignupWizardPage`, `WelcomePage` | `lib/pages/auth/login_page.dart`, `lib/pages/auth/signup_wizard_page.dart` | Supabase Auth (`supabase.auth.signUp`, `signInWithPassword`) | Email/password implemented. OTP, phone auth, social login (Google OAuth) UI present but not functional. Role stored in `userMetadata['role']`. |
| **Roles (client/trainer/nutritionist)** | **Done** | Role-based routing in `app_router.dart` | `lib/router/app_router.dart` (lines 56-66), `lib/models/video_session_models.dart` (Role enum) | Supabase user metadata | Role-based redirects work. Role stored in `user.userMetadata['role']`. No role switching UI. |
| **Nearby trainers/nutritionists/centers** | **Stub** | `DiscoverPage`, `CenterDetailPage` | `lib/pages/discover/discover_page.dart`, `lib/pages/discover/center_detail_page.dart` | **NOT IMPLEMENTED** | Uses mock data (`_loadMockData()`). Filter UI exists (`DiscoverFilterSheet`) but no backend queries. Distance calculation not implemented. Map view placeholder only. |
| **Provider profiles (create/edit/view)** | **Partial** | `TrainerProfilePage`, `NutritionistProfilePage`, `UserProfilePage` | `lib/pages/trainer/trainer_profile_page.dart`, `lib/pages/nutritionist/nutritionist_profile_page.dart`, `lib/pages/cocircle/user_profile_page.dart` | **NOT IMPLEMENTED** | Profile pages exist but read from mock data or user metadata only. No profile creation/editing backend. Verification submission page exists (`VerificationSubmissionPage`) but doesn't persist. |
| **Booking flow** | **Stub** | Request buttons in `DiscoverPage` | `lib/pages/discover/discover_page.dart` (lines 30, request status map) | **NOT IMPLEMENTED** | "Request" button exists, manages local state (`_requestStatus` map), but no backend API. No accept/cancel/reschedule flows. |
| **Chat/messaging** | **Stub** | `MessagingPage`, `ChatScreen` | `lib/pages/messaging/messaging_page.dart`, `lib/pages/messaging/chat_screen.dart` | **NOT IMPLEMENTED** | UI complete with emoji picker, image/video attachments, but uses hardcoded messages (`_ChatMessage` list). No real-time messaging backend. No Supabase Realtime subscriptions. |
| **Video sessions** | **Stub** | `VideoSessionsPage`, `CreateMeetingPage`, `JoinMeetingPage`, `MeetingRoomPage` | `lib/pages/video_sessions/*.dart`, `lib/services/meeting_storage_service.dart` | **NOT IMPLEMENTED** | Full UI for meeting room (grid view, chat, controls, participants). Uses in-memory `MeetingStorageService` (no persistence). No actual video provider integration (no Agora/Zoom/WebRTC). Meeting models exist but not saved to Supabase. |
| **Subscriptions / premium unlock** | **Stub** | Subscription buttons in profile pages | `lib/pages/trainer/trainer_profile_page.dart` (line 201), `lib/pages/nutritionist/nutritionist_profile_page.dart` (line 201) | **NOT IMPLEMENTED** | UI buttons exist (`_isSubscribed` flag), but no IAP package (`in_app_purchase`). No entitlement storage. No subscription management backend. |
| **Metrics (steps, calories, water, distance, BMI)** | **Done** | `HomePageV3`, `InsightsDetailPage`, various insight pages | `lib/services/health_tracking_service.dart`, `lib/providers/health_tracking_provider.dart`, `lib/widgets/home_v3/*.dart` | Device APIs (`health` package, `geolocator`) | Steps/calories/distance read from device sensors via `HealthTrackingService`. Water is manual entry. BMI calculated from height/weight. Background step tracking initialized. Goals stored in Supabase user metadata via `UserGoalsService`. |
| **Meal tracker** | **Stub** | `MealTrackerPageV2`, `WeeklyInsightsPage` | `lib/pages/meal_tracker/meal_tracker_page_v2.dart` | **NOT IMPLEMENTED** | Full UI for logging meals with photos, macros tracking, weekly insights. Uses hardcoded `FoodItem` list. No food database integration. No backend persistence. Data stored in local state only. |
| **Social feed "Cocircle"** | **Stub** | `CocirclePage`, `CocircleCreatePostPage`, `UserProfilePage` | `lib/pages/cocircle/cocircle_page.dart`, `lib/pages/cocircle/cocircle_create_post_page.dart` | **NOT IMPLEMENTED** | UI complete: post creation, feed display, like/comment UI, profile views. Uses mock data (`CocircleFeedPost`). No backend integration. No image upload to Supabase Storage. No report/block functionality implemented. |
| **Quests** | **Partial** | `QuestPage` (Daily/Weekly/Challenges/Achievements/Leaderboard tabs) | `lib/pages/quest/quest_page.dart`, `lib/services/quest_service.dart`, `lib/models/quest_models.dart` | Supabase tables: `user_quests`, `user_quest_settings`, `user_quest_refills`, `leaderboard_points`, `user_profiles` | Quest service implemented with pool, selection logic, progress tracking. **Backend tables referenced but may not exist.** Quest claiming updates XP/points. Leaderboard queries exist but use mock data in UI. Achievements grid UI exists but not connected to real data. |
| **Admin tools** | **NOT IMPLEMENTED** | None | N/A | N/A | No admin dashboard, moderation tools, or provider approval workflows found in codebase. |
| **Notifications** | **Stub** | `NotificationPage` | `lib/pages/notifications/notification_page.dart`, `lib/services/notification_service.dart` | **NOT IMPLEMENTED** | In-memory `NotificationService` only. No push notifications (`firebase_messaging` or similar). No Supabase Realtime for notifications. Local notifications not configured. Deep links not implemented. |
| **Settings** | **Partial** | `SettingsPage`, `EditProfilePage`, `PrivacySecurityPage` | `lib/pages/profile/settings_page.dart`, `lib/pages/profile/edit_profile_page.dart` | Supabase user metadata | Profile editing updates Supabase user metadata. Privacy settings UI exists but not persisted. Account deletion not implemented. Theme switching works (light/dark). |

---

## 3) App Architecture

### State Management
- **Primary:** Riverpod (`flutter_riverpod: ^2.4.9`)
  - Used in: `lib/providers/` (3 files: `health_tracking_provider.dart`, `profile_images_provider.dart`, `quest_provider.dart`)
  - `ProviderScope` wraps app in `main.dart`
  - Most pages use `StatefulWidget` with local state; Riverpod used selectively for health metrics and quests
- **Pattern:** Mix of Riverpod providers and local state. No consistent pattern across features.

### Folder Structure (`lib/`)
```
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart          # Hardcoded Supabase credentials
│   ├── motion/
│   │   └── motion.dart                   # Animation utilities
│   └── services/                         # Empty
├── main.dart                             # App entry, Supabase init, health service init
├── models/
│   ├── quest_models.dart                 # Quest/Achievement/Leaderboard models
│   └── video_session_models.dart         # Meeting/Participant models
├── pages/                                # 64 Dart files
│   ├── auth/                            # Login, signup, welcome, permissions
│   ├── cocircle/                        # Social feed pages
│   ├── discover/                        # Trainer/nutritionist/center discovery
│   ├── home/                            # Main home page, shell
│   ├── insights/                        # Metrics detail pages
│   ├── meal_tracker/                    # Meal logging
│   ├── messaging/                       # Chat screens
│   ├── notifications/                   # Notification list
│   ├── nutritionist/                    # Nutritionist dashboard/pages
│   ├── profile/                         # User profile, settings
│   ├── quest/                           # Quest/achievement page
│   ├── trainer/                         # Trainer dashboard/pages
│   └── video_sessions/                  # Video meeting pages
├── providers/                           # 3 Riverpod providers
├── repositories/                        # Empty folder
├── router/
│   └── app_router.dart                  # GoRouter config with auth redirects
├── services/                            # 6 service classes
│   ├── health_tracking_service.dart     # Device sensor integration
│   ├── meeting_storage_service.dart     # In-memory meeting storage
│   ├── notification_service.dart        # In-memory notifications
│   ├── quest_service.dart               # Quest logic (references Supabase)
│   ├── streak_service.dart              # Streak calculation
│   └── user_goals_service.dart          # Goals in Supabase metadata
├── theme/                               # Theme configuration
├── utils/                               # Utilities
└── widgets/                             # 68 reusable widgets
    ├── auth/
    ├── cocircle/
    ├── common/
    ├── discover/
    ├── home/ & home_v3/
    ├── profile/
    └── quest/
```

### Navigation
- **Approach:** GoRouter (`go_router: ^13.0.0`)
- **File:** `lib/router/app_router.dart`
- **Routes:** 20+ routes defined with named routes
- **Auth Guard:** Redirect logic in `redirect` callback (lines 35-69)
  - Checks `Supabase.instance.client.auth.currentSession`
  - Role-based redirects (trainer → `/trainer/dashboard`, nutritionist → `/nutritionist/dashboard`, else → `/home`)
- **Transitions:** Custom `_fadeSlidePage` using `Motion.standardPageTransition()` (fade + slide + scale)
- **Deep Links:** Not implemented (no `initialLocation` handling for deep links)

### Dependency Injection
- **Pattern:** None. Services use singleton pattern (`_instance` factory) or direct instantiation.
- **Examples:**
  - `HealthTrackingService()` - singleton
  - `MeetingStorageService()` - singleton
  - `NotificationService()` - singleton
  - `Supabase.instance.client` - accessed directly throughout codebase

### Error Handling/Logging
- **Pattern:** Minimal. Most errors caught with try-catch, logged via `print()` statements.
- **No centralized error handling.** No error reporting service (Sentry, etc.).
- **Example:** `lib/services/health_tracking_service.dart` uses `print('Error initializing health tracking: $e')`

---

## 4) Backend & Data Layer

### Supabase Usage
- **Yes, Supabase is used as the primary backend.**
- **Setup:** `lib/core/config/supabase_config.dart`
  - **URL:** `https://nvtozwtuyhwqkqvftpyi.supabase.co` (hardcoded)
  - **Anon Key:** Hardcoded JWT token (exposed in source)
  - **Initialization:** `lib/main.dart` lines 14-17
- **Client Access:** `Supabase.instance.client` accessed directly (no abstraction layer)

### Supabase Tables Referenced
Based on code analysis, these tables are referenced but **may not exist in database**:

1. **`user_profiles`**
   - Referenced in: `lib/services/quest_service.dart` (lines 635, 642), `lib/providers/quest_provider.dart` (line 53)
   - Queries: `select('xp', 'level')`, `update({'xp': ..., 'level': ...})`
   - Assumed fields: `user_id`, `xp`, `level`

2. **`user_quests`**
   - Referenced in: `lib/services/quest_service.dart` (multiple `.from('user_quests')` calls)
   - Operations: `insert()`, `select()`, `update()`, `delete()`
   - Assumed fields: `id`, `user_id`, `quest_definition_id`, `type`, `status`, `progress`, `assigned_at`, `expires_at`, `claimed_at`

3. **`user_quest_settings`**
   - Referenced in: `lib/services/quest_service.dart` (lines 541, 573, 671, 687)
   - Operations: `upsert()`, `select()`
   - Assumed fields: `user_id`, `daily_quest_slots`, `weekly_quest_slots`, `refills_used_today`

4. **`user_quest_refills`**
   - Referenced in: `lib/services/quest_service.dart` (lines 585, 626)
   - Operations: `select()`, `insert()`
   - Assumed fields: `user_id`, `refilled_at`, `quest_type`

5. **`leaderboard_points`**
   - Referenced in: `lib/services/quest_service.dart` (lines 653, 660)
   - Operations: `upsert()`
   - Assumed fields: `user_id`, `points`, `time_window`, `scope`, `updated_at`

**Note:** No migration files or schema definitions found. Tables must be created manually in Supabase dashboard.

### RLS (Row Level Security) Assumptions
- **No RLS policies are defined in code.** All queries assume RLS policies exist in Supabase dashboard.
- **Critical:** Without RLS, all data is potentially exposed if anon key is compromised.
- **Expected policies:**
  - `user_profiles`: Users can read/update own profile
  - `user_quests`: Users can read/insert/update own quests
  - `leaderboard_points`: Public read for leaderboards, users can update own points

### Storage Buckets
- **No Supabase Storage usage found in codebase.**
- Image uploads in `CocircleCreatePostPage` and `ChatScreen` use `ImagePicker` but don't upload to Supabase Storage.
- Profile images referenced via URLs but no upload implementation.

### Edge Functions
- **No Edge Functions called.** No `functions.invoke()` calls found.

### Other Backend Services
- **None.** App relies solely on Supabase.

---

## 5) Data Models

### Core Models

1. **Quest Models** (`lib/models/quest_models.dart`)
   - `QuestDefinition` - Quest pool definitions
   - `ActiveQuest` - User-assigned quest instances
   - `ChallengeQuest` - Challenge-specific quests
   - `Achievement` - Achievement milestones
   - `LeaderboardEntry` - Leaderboard rankings
   - Enums: `QuestCategory`, `QuestDifficulty`, `QuestTimeWindow`, `QuestStatus`, `QuestType`, `ChallengeScope`, `AchievementCategory`, `LeaderboardType`, `LeaderboardTimeWindow`

2. **Video Session Models** (`lib/models/video_session_models.dart`)
   - `Role` enum (client, trainer, nutritionist)
   - `Meeting` - Meeting details
   - `Participant` - Meeting participant info
   - `MeetingStatus` enum
   - `MeetingPrivacy` enum

3. **Notification Model** (defined in `lib/pages/notifications/notification_page.dart`)
   - `NotificationData` - Notification item
   - `NotificationType` enum

4. **Discover Model** (defined inline in `lib/pages/discover/discover_page.dart`)
   - `DiscoverItem` - Trainer/nutritionist/center info

5. **Client Model** (referenced but not found in models/)
   - `ClientItem` - Used in trainer/nutritionist pages

### Model Inconsistencies
- **No centralized model directory.** Models scattered across pages (e.g., `NotificationData` in notification page, `DiscoverItem` in discover page).
- **Missing models:** User profile model, meal/food models (using inline `FoodItem` class), post models (using inline classes).
- **Duplication:** Quest models well-structured, but other features lack proper models.

---

## 6) Security & Compliance Risks

### High Impact Issues

1. **Hardcoded Supabase Credentials** ⚠️ **CRITICAL**
   - **File:** `lib/core/config/supabase_config.dart`
   - **Issue:** Supabase URL and anon key hardcoded in source code
   - **Risk:** If repo is public, credentials are exposed. Anon key can be extracted from APK/IPA.
   - **Fix:** Use environment variables or `flutter_dotenv`, move to build-time configuration.

2. **No RLS Policies Enforced in Code** ⚠️ **HIGH**
   - **Issue:** All Supabase queries assume RLS exists but no verification
   - **Risk:** If RLS not configured, all user data is accessible
   - **Fix:** Document required RLS policies, add migration scripts, or verify in code.

3. **Client-Side Entitlement Checks** ⚠️ **HIGH**
   - **Issue:** Subscription status (`_isSubscribed` flags) are local state, not verified server-side
   - **Risk:** Users can bypass premium features
   - **Fix:** Verify subscription status from Supabase on app start, cache with expiration.

4. **No Input Validation** ⚠️ **MEDIUM**
   - **Issue:** User inputs (signup form, meal tracker) not validated before sending to Supabase
   - **Risk:** Invalid data, injection attacks (though Supabase handles SQL injection)
   - **Fix:** Add client-side validation, use Supabase database constraints.

5. **Insecure Storage** ⚠️ **MEDIUM**
   - **Issue:** Sensitive data (goals, preferences) stored in Supabase user metadata (JSON field)
   - **Risk:** Metadata is readable if user token is compromised
   - **Fix:** Move sensitive data to proper tables with RLS.

### iOS/Android Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
- ✅ `CAMERA` - For photo posts
- ✅ `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` - Image picker
- ✅ `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` - Distance tracking
- ✅ `ACTIVITY_RECOGNITION` - Step tracking
- ✅ `POST_NOTIFICATIONS` - Push notifications (not implemented)
- ✅ `RECORD_AUDIO` - Video sessions (not implemented)

**iOS** (`ios/Runner/Info.plist`):
- ✅ `NSCameraUsageDescription` - Present
- ✅ `NSPhotoLibraryUsageDescription` - Present
- ✅ `NSPhotoLibraryAddUsageDescription` - Present
- ⚠️ **Missing:** `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription`, `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSMicrophoneUsageDescription`
- **Risk:** App will crash when requesting these permissions on iOS.

### App Store Review Issues

1. **Missing Privacy Policy URL** - No privacy policy link in settings (UI exists but not functional)
2. **Incomplete Permissions Descriptions** - iOS missing health/location/microphone descriptions
3. **No Account Deletion** - GDPR/CCPA compliance risk
4. **Debug Signing Config** - Android release builds use debug keys (`signingConfig = signingConfigs.getByName("debug")` in `build.gradle.kts` line 42)

---

## 7) Test & Build Readiness

### Tests
- **Unit Tests:** None found (except default `test/widget_test.dart` with counter example)
- **Widget Tests:** None
- **Integration Tests:** None
- **Test Coverage:** 0%

### Build Commands
- **Android:** `flutter build apk` should work (minSdk 26, Java 17)
  - **Known Issue:** Release builds use debug signing (line 42 in `android/app/build.gradle.kts`)
- **iOS:** `flutter build ios` should work (no special config found)
  - **Known Issue:** Missing permission descriptions in `Info.plist` will cause runtime crashes
- **Web:** Platform files exist but not configured for production

### Known Build Blockers
1. **Hardcoded credentials** - Will work but security risk
2. **Missing iOS permissions** - App will crash on permission requests
3. **Debug signing for Android release** - Cannot publish to Play Store
4. **No environment configuration** - Cannot have dev/staging/prod builds

---

## 8) TODO List (Prioritized)

### Must-Have for Launch

1. **Move Supabase credentials to environment variables** (S, 1-2d)
   - Use `flutter_dotenv` or build-time configuration
   - Remove hardcoded values from `supabase_config.dart`
   - Add `.env.example` template

2. **Create Supabase database schema** (M, 3-7d)
   - Create tables: `user_profiles`, `user_quests`, `user_quest_settings`, `user_quest_refills`, `leaderboard_points`
   - Add RLS policies for all tables
   - Create indexes for performance
   - Add database constraints (foreign keys, not null, etc.)

3. **Implement real backend integration for core features** (XL, 1mo+)
   - **Discover page:** Query trainers/nutritionists/centers from Supabase
   - **Messaging:** Implement Supabase Realtime for chat
   - **Cocircle:** Create posts table, implement image upload to Supabase Storage
   - **Meal tracker:** Create meals table, implement food database or API integration
   - **Video sessions:** Integrate video provider (Agora/Zoom/WebRTC) or use Supabase Realtime for signaling

4. **Fix iOS permission descriptions** (S, 1-2d)
   - Add all missing `NS*UsageDescription` keys to `Info.plist`
   - Test permission flows on iOS device

5. **Implement push notifications** (M, 3-7d)
   - Add `firebase_messaging` or Supabase push notifications
   - Configure FCM/APNS
   - Implement notification handling and deep links

6. **Add Android release signing** (S, 1-2d)
   - Create keystore, update `build.gradle.kts`
   - Configure signing for release builds

7. **Implement account deletion** (S, 1-2d)
   - Add GDPR-compliant account deletion flow
   - Delete user data from Supabase (cascade or manual cleanup)

### Should-Have

8. **Implement IAP for subscriptions** (L, 1-3w)
   - Add `in_app_purchase` package
   - Implement Android/iOS purchase flows
   - Store entitlements in Supabase
   - Add subscription management UI

9. **Add error reporting** (M, 3-7d)
   - Integrate Sentry or similar
   - Replace `print()` statements with proper logging
   - Add error boundaries

10. **Implement admin tools** (L, 1-3w)
    - Admin dashboard for provider approvals
    - Content moderation tools
    - User management

11. **Add comprehensive tests** (XL, 1mo+)
    - Unit tests for services
    - Widget tests for critical pages
    - Integration tests for auth and core flows

12. **Implement booking system** (L, 1-3w)
    - Create bookings table
    - Implement request/accept/cancel/reschedule flows
    - Add calendar integration

### Nice-to-Have

13. **Add food database integration** (M, 3-7d)
    - Integrate with nutrition API (USDA, Edamam, etc.)
    - Cache food data locally

14. **Implement social features** (L, 1-3w)
    - Friend system
    - Follow/unfollow
    - Report/block functionality

15. **Add analytics** (M, 3-7d)
    - Integrate Firebase Analytics or similar
    - Track key user events

16. **Improve error handling** (M, 3-7d)
    - Centralized error handling
    - User-friendly error messages
    - Retry mechanisms

17. **Add deep linking** (M, 3-7d)
    - Implement deep links for notifications
    - Handle app links for sharing

18. **Optimize performance** (L, 1-3w)
    - Image caching optimization
    - Lazy loading for lists
    - Code splitting if needed

---

## Summary Statistics

- **Total Dart Files:** ~155
- **Pages:** 64
- **Widgets:** 68
- **Services:** 6
- **Providers:** 3
- **Models:** 2 (incomplete)
- **Test Coverage:** 0%
- **Backend Tables Referenced:** 5 (may not exist)
- **Features with Real Backend:** 2 (Auth, Health Metrics)
- **Features with Mock Data:** 8+
- **Security Issues:** 5 critical/high

**Overall Assessment:** The app has a solid UI foundation and architecture, but approximately 70% of features use mock data and lack backend integration. The app is **not production-ready** and requires significant backend work, security fixes, and testing before launch.
