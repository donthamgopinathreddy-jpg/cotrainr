# Role-Based Access Control (RBAC) Audit Report

**Generated:** 2025-01-27  
**Repository:** cotrainr_flutter  
**Auditor:** Senior Flutter Architect

---

## 1) Role Overview

### Client
- **Intended Purpose:** End users seeking fitness/nutrition services
- **Responsibilities:** Track health metrics, discover trainers/nutritionists, book sessions, chat, social feed participation
- **Key Features:** Home dashboard, Discover, Quest/Achievements, Cocircle (social), Messaging, Video sessions (join), Meal tracker

### Trainer
- **Intended Purpose:** Fitness professionals providing training services
- **Responsibilities:** Manage clients, create video sessions, track client progress, verification, service locations
- **Key Features:** Trainer dashboard, My Clients, Client detail pages, Video session creation, Verification submission, Service locations management

### Nutritionist
- **Intended Purpose:** Nutrition professionals providing dietary services
- **Responsibilities:** Manage clients, create video sessions, track client nutrition, verification, service locations
- **Key Features:** Nutritionist dashboard, My Clients, Client detail pages, Video session creation, Verification submission, Service locations management

---

## 2) Pages Per Role

### CLIENT PAGES

| Page Name | Route/Path | File Path | Feature Purpose | Implementation Status | Access Control |
|-----------|------------|-----------|----------------|----------------------|----------------|
| Home Dashboard | `/home` | `lib/pages/home/home_shell_page.dart` | Main navigation hub with tabs | **REAL** (health metrics from device) | ✅ Enforced by router (auth required) |
| Home Tab | `/home` (tab 0) | `lib/pages/home/home_page_v3.dart` | Health metrics, steps, calories, water | **REAL** (health data)**PARTIAL** (some mock data) | ❌ No role check - accessible to all authenticated users |
| Discover | `/home/discover` | `lib/pages/discover/discover_page.dart` | Find trainers/nutritionists/centers | **MOCK** (hardcoded data) | ❌ No role check |
| Quest | `/home/quest` | `lib/pages/quest/quest_page.dart` | Gamification, achievements | **PARTIAL** (UI real, backend partial) | ❌ No role check |
| Cocircle | `/home/cocircle` | `lib/pages/cocircle/cocircle_page.dart` | Social feed | **MOCK** (mock posts) | ❌ No role check |
| Profile | `/home/profile` | `lib/pages/profile/profile_page.dart` | User profile view | **PARTIAL** (reads from Supabase) | ❌ No role check - shows different UI based on role but accessible to all |
| Settings | `/settings` (via Profile) | `lib/pages/profile/settings_page.dart` | Account settings | **REAL** (Supabase integration) | ⚠️ **UI check only** - shows Service Locations for providers but page accessible to all |
| Service Locations | N/A (via Settings) | `lib/pages/profile/settings/service_locations_page.dart` | Manage service locations | **REAL** (Supabase) | ⚠️ **UI check only** - only shown in Settings if provider, but route not protected |
| Notifications | `/notifications` | `lib/pages/notifications/notification_page.dart` | Notification list | **MOCK** (mock notifications) | ❌ No role check |
| Messaging | `/messaging` | `lib/pages/messaging/messaging_page.dart` | Chat list | **MOCK** (mock conversations) | ❌ No role check |
| Chat Screen | `/messaging/chat/:userId` | `lib/pages/messaging/chat_screen.dart` | 1:1 chat | **MOCK** (mock messages) | ❌ No role check |
| Meal Tracker | `/meal-tracker` | `lib/pages/meal_tracker/meal_tracker_page_v2.dart` | Log meals, macros | **MOCK** (mock data) | ❌ No role check |
| Video Sessions | `/video?role=client` | `lib/pages/video_sessions/video_sessions_page.dart` | Join/create sessions | **MOCK** (UI only, no WebRTC) | ⚠️ **Query param only** - role passed via URL, not verified |
| Create Meeting | `/video/create?role=client` | `lib/pages/video_sessions/create_meeting_page.dart` | Create video session | **MOCK** (UI only) | ⚠️ **Query param only** - role from URL, not verified |
| Join Meeting | `/video/join` | `lib/pages/video_sessions/join_meeting_page.dart` | Join by ID | **MOCK** (UI only) | ❌ No role check |
| Meeting Room | `/video/room/:meetingId` | `lib/pages/video_sessions/meeting_room_page.dart` | Video call UI | **MOCK** (UI only, no WebRTC) | ❌ No role check |
| Insights (Steps) | `/insights/steps` | `lib/pages/insights/steps_insights_page.dart` | Steps analytics | **REAL** (device data) | ❌ No role check |
| Insights (Water) | `/insights/water` | `lib/pages/insights/water_insights_page.dart` | Water intake analytics | **REAL** (user goals) | ❌ No role check |
| Insights (Calories) | `/insights/calories` | `lib/pages/insights/calories_insights_page.dart` | Calories analytics | **REAL** (device data) | ❌ No role check |
| Insights (Distance) | `/insights/distance` | `lib/pages/insights/distance_insights_page.dart` | Distance analytics | **REAL** (GPS data) | ❌ No role check |
| Refer Friend | `/refer` | `lib/pages/refer/refer_friend_page.dart` | Referral program | **MOCK** (UI only) | ❌ No role check |

### TRAINER PAGES

| Page Name | Route/Path | File Path | Feature Purpose | Implementation Status | Access Control |
|-----------|------------|-----------|----------------|----------------------|----------------|
| Trainer Dashboard | `/trainer/dashboard` | `lib/pages/trainer/trainer_dashboard_page.dart` | Main navigation hub | **MOCK** (mock data) | ⚠️ **Router redirect only** - no explicit guard |
| Trainer Home | Tab 0 in dashboard | `lib/pages/trainer/trainer_home_page.dart` | Trainer home view | **MOCK** (mock data) | ❌ No role check |
| My Clients | Tab 1 in dashboard | `lib/pages/trainer/trainer_my_clients_page.dart` | Client list | **MOCK** (mock clients) | ❌ No role check |
| Client Detail | `/clients/:id` | `lib/pages/trainer/client_detail_page.dart` | View client progress | **MOCK** (mock data) | ❌ **CRITICAL GAP** - accessible to any authenticated user |
| Create Client | N/A (via My Clients) | `lib/pages/trainer/create_client_page.dart` | Add new client | **MOCK** (UI only) | ❌ No role check |
| Trainer Quest | Tab 2 in dashboard | `lib/pages/trainer/trainer_quest_page.dart` | Quest system | **PARTIAL** (reuses quest_page.dart) | ❌ No role check |
| Trainer Cocircle | Tab 3 in dashboard | `lib/pages/trainer/trainer_cocircle_page.dart` | Social feed | **MOCK** (mock posts) | ❌ No role check |
| Trainer Profile | Tab 4 in dashboard | `lib/pages/trainer/trainer_profile_page.dart` | Trainer profile | **PARTIAL** (reads Supabase) | ❌ No role check |
| Become Trainer | `/trainer/become` | `lib/pages/trainer/become_trainer_page.dart` | Registration form | **MOCK** (UI only, no backend) | ❌ **CRITICAL GAP** - accessible to anyone, even trainers |
| Verification | `/verification` | `lib/pages/trainer/verification_submission_page.dart` | Submit verification docs | **MOCK** (UI only) | ❌ No role check |

### NUTRITIONIST PAGES

| Page Name | Route/Path | File Path | Feature Purpose | Implementation Status | Access Control |
|-----------|------------|-----------|----------------|----------------------|----------------|
| Nutritionist Dashboard | `/nutritionist/dashboard` | `lib/pages/nutritionist/nutritionist_dashboard_page.dart` | Main navigation hub | **MOCK** (mock data) | ⚠️ **Router redirect only** - no explicit guard |
| Nutritionist Home | Tab 0 in dashboard | `lib/pages/nutritionist/nutritionist_home_page.dart` | Nutritionist home view | **MOCK** (mock data) | ❌ No role check |
| My Clients | Tab 1 in dashboard | `lib/pages/nutritionist/nutritionist_my_clients_page.dart` | Client list | **MOCK** (mock clients) | ❌ No role check |
| Client Detail | `/nutritionist/clients/:id` | `lib/pages/nutritionist/nutritionist_client_detail_page.dart` | View client progress | **MOCK** (mock data) | ❌ **CRITICAL GAP** - accessible to any authenticated user |
| Nutritionist Quest | Tab 2 in dashboard | `lib/pages/nutritionist/nutritionist_quest_page.dart` | Quest system | **PARTIAL** (reuses quest_page.dart) | ❌ No role check |
| Nutritionist Cocircle | Tab 3 in dashboard | `lib/pages/nutritionist/nutritionist_cocircle_page.dart` | Social feed | **MOCK** (mock posts) | ❌ No role check |
| Nutritionist Profile | Tab 4 in dashboard | `lib/pages/nutritionist/nutritionist_profile_page.dart` | Nutritionist profile | **PARTIAL** (reads Supabase) | ❌ No role check |

---

## 3) Shared Pages

| Page Name | Route/Path | File Path | Role-Specific Behavior | Missing Role Checks |
|-----------|------------|-----------|------------------------|---------------------|
| Discover | `/home/discover` | `lib/pages/discover/discover_page.dart` | None - same for all roles | ❌ Should filter by role (trainers see trainers, etc.) |
| Cocircle | `/home/cocircle` | `lib/pages/cocircle/cocircle_page.dart` | None - same feed for all | ❌ No role-based filtering |
| Quest | `/home/quest` | `lib/pages/quest/quest_page.dart` | Quest definitions can specify roles | ⚠️ Role filtering in quest definitions but not enforced in UI |
| Profile | `/home/profile` | `lib/pages/profile/profile_page.dart` | Shows different UI based on role (verification card, etc.) | ⚠️ UI adapts but page accessible to all |
| Settings | N/A (via Profile) | `lib/pages/profile/settings_page.dart` | Shows "Service Locations" only for providers | ⚠️ UI check only - page accessible to all |
| Video Sessions | `/video?role=...` | `lib/pages/video_sessions/video_sessions_page.dart` | Different buttons/features per role | ⚠️ Role from query param, not verified |
| Create Meeting | `/video/create?role=...` | `lib/pages/video_sessions/create_meeting_page.dart` | Different participant selection per role | ⚠️ Role from query param, not verified |
| Messaging | `/messaging` | `lib/pages/messaging/messaging_page.dart` | None - same for all | ❌ No role-based filtering |
| Chat Screen | `/messaging/chat/:userId` | `lib/pages/messaging/chat_screen.dart` | None - same for all | ❌ No access control - any user can chat with any user |

---

## 4) Routing & Guards Audit

### Current Router Implementation (`lib/router/app_router.dart`)

**Auth Guard:**
- ✅ **Line 35-47:** Checks if user is logged in, redirects to `/welcome` if not
- ✅ **Line 41:** Public routes defined: `/welcome`, `/auth/login`, `/auth/create-account`, `/welcome-animation`, `/auth/permissions`
- ⚠️ **Line 51-67:** If logged in and accessing auth routes, redirects based on role BUT:
  - Only checks `userMetadata['role']` (can be null or wrong)
  - Defaults to `/home` if role check fails
  - **No explicit role verification for protected routes**

**Role-Based Redirects:**
- ✅ **Line 57-60:** Redirects trainers to `/trainer/dashboard`, nutritionists to `/nutritionist/dashboard`
- ❌ **Missing:** No redirect for clients (defaults to `/home`)

**Route Protection:**
- ❌ **NO role guards on:**
  - `/trainer/dashboard` - accessible to any authenticated user
  - `/trainer/become` - accessible to anyone (even existing trainers)
  - `/nutritionist/dashboard` - accessible to any authenticated user
  - `/clients/:id` - accessible to any authenticated user (should be trainer-only)
  - `/nutritionist/clients/:id` - accessible to any authenticated user (should be nutritionist-only)
  - `/video/create` - role from query param only, not verified
  - `/video/room/:meetingId` - no role check

**Critical Routing Gaps:**
1. **Trainer routes accessible to clients/nutritionists:**
   - `/trainer/dashboard` - no guard
   - `/trainer/become` - no guard (should redirect if already trainer)
   - `/clients/:id` - no guard (should verify user is trainer and owns client)

2. **Nutritionist routes accessible to clients/trainers:**
   - `/nutritionist/dashboard` - no guard
   - `/nutritionist/clients/:id` - no guard (should verify user is nutritionist and owns client)

3. **Video session routes:**
   - Role passed via query param (`?role=trainer`) but never verified against actual user role
   - Any user can access `/video/create?role=trainer` even if they're a client

4. **Shared routes:**
   - All shared routes (`/home`, `/messaging`, `/discover`, etc.) accessible to all roles
   - No role-based filtering or restrictions

---

## 5) UI Gating Audit

### Places Where Role Checks ARE Done:

1. **Settings Page** (`lib/pages/profile/settings_page.dart`):
   - ✅ **Line 33-37:** `_userRole` getter reads from Supabase
   - ✅ **Line 40-43:** `_isProvider` check
   - ✅ **Line 164-172:** Shows "Service Locations" only if `_isProvider == true`
   - ⚠️ **Issue:** Page still accessible to all, just hides the option

2. **Profile Page** (`lib/pages/profile/profile_page.dart`):
   - ✅ **Line 32-36:** `_role` getter reads from Supabase
   - ✅ **Line 40-54:** Shows verification card only for trainers/nutritionists
   - ✅ **Line 119-134:** Shows verification submission button only if needed
   - ⚠️ **Issue:** Page accessible to all, just adapts UI

3. **Quick Access Widget** (`lib/widgets/home_v3/quick_access_v3.dart`):
   - ✅ **Line 18:** Reads user role from Supabase
   - ✅ **Line 24:** Shows video button with role-specific route
   - ✅ **Line 78-83:** Routes to correct video page based on role

4. **Video Sessions Page** (`lib/pages/video_sessions/video_sessions_page.dart`):
   - ✅ **Line 122-133:** Different UI based on role prop
   - ⚠️ **Issue:** Role comes from query param, not verified

5. **Create Meeting Page** (`lib/pages/video_sessions/create_meeting_page.dart`):
   - ✅ **Line 50-54:** Sets allowed roles based on userRole prop
   - ✅ **Line 663-676:** Hides role chips for roles user can't select
   - ⚠️ **Issue:** Role comes from query param, not verified

### Places Where Role Checks Are MISSING:

1. **Trainer Dashboard** (`lib/pages/trainer/trainer_dashboard_page.dart`):
   - ❌ **No role check** - any authenticated user can access
   - **Should:** Verify user role is 'trainer' before showing

2. **Nutritionist Dashboard** (`lib/pages/nutritionist/nutritionist_dashboard_page.dart`):
   - ❌ **No role check** - any authenticated user can access
   - **Should:** Verify user role is 'nutritionist' before showing

3. **Client Detail Pages:**
   - ❌ `/clients/:id` - no check if user is trainer
   - ❌ `/nutritionist/clients/:id` - no check if user is nutritionist
   - ❌ **No check if user owns the client** - any trainer can see any client

4. **Become Trainer Page** (`lib/pages/trainer/become_trainer_page.dart`):
   - ❌ **No check if user is already a trainer** - can submit multiple times
   - **Should:** Redirect if user role is already 'trainer' or 'nutritionist'

5. **Service Locations Page** (`lib/pages/profile/settings/service_locations_page.dart`):
   - ❌ **No role check in page itself** - only hidden in Settings menu
   - **Should:** Add role guard at page level (defense in depth)

6. **Discover Page** (`lib/pages/discover/discover_page.dart`):
   - ❌ **No role-based filtering** - shows same results to all
   - **Should:** Filter by role (trainers see trainers, clients see all providers)

7. **Messaging/Chat:**
   - ❌ **No access control** - any user can message any user
   - **Should:** Verify users have relationship (client-trainer, etc.)

8. **Video Meeting Room** (`lib/pages/video_sessions/meeting_room_page.dart`):
   - ❌ **No role check** - any user can join any meeting
   - **Should:** Verify user is participant or has permission

---

## 6) Critical Gaps (Prioritized)

### BLOCKER Severity

1. **Trainer/Nutritionist Dashboards Accessible to Wrong Roles**
   - **File:** `lib/router/app_router.dart` (routes), `lib/pages/trainer/trainer_dashboard_page.dart`, `lib/pages/nutritionist/nutritionist_dashboard_page.dart`
   - **Issue:** Any authenticated user can navigate to `/trainer/dashboard` or `/nutritionist/dashboard`
   - **Impact:** Clients can see trainer/nutritionist UI, potential data leaks
   - **Fix:** Add role guard in router redirect or page initState

2. **Client Detail Pages Accessible to Wrong Roles**
   - **Files:** `lib/pages/trainer/client_detail_page.dart`, `lib/pages/nutritionist/nutritionist_client_detail_page.dart`
   - **Issue:** Any authenticated user can access `/clients/:id` or `/nutritionist/clients/:id`
   - **Impact:** Data leak - clients can see other clients' data, trainers can see nutritionist clients
   - **Fix:** Add role check + ownership verification in page initState

3. **Video Session Role Spoofing**
   - **Files:** `lib/pages/video_sessions/video_sessions_page.dart`, `lib/pages/video_sessions/create_meeting_page.dart`
   - **Issue:** Role passed via query param (`?role=trainer`) but never verified against actual user role
   - **Impact:** Client can access trainer features by changing URL
   - **Fix:** Read role from Supabase userMetadata, ignore query param

4. **Become Trainer Accessible to Existing Trainers**
   - **File:** `lib/pages/trainer/become_trainer_page.dart`
   - **Issue:** No check if user is already trainer/nutritionist
   - **Impact:** Trainers can submit multiple applications, UI confusion
   - **Fix:** Redirect if role is already 'trainer' or 'nutritionist'

### HIGH Severity

5. **Service Locations Page Not Protected**
   - **File:** `lib/pages/profile/settings/service_locations_page.dart`
   - **Issue:** Page accessible via direct navigation, only hidden in Settings menu
   - **Impact:** Clients can access provider-only feature if they know the route
   - **Fix:** Add role check in page initState, redirect if not provider

6. **No Access Control on Chat/Messaging**
   - **Files:** `lib/pages/messaging/messaging_page.dart`, `lib/pages/messaging/chat_screen.dart`
   - **Issue:** Any user can message any user, no relationship verification
   - **Impact:** Privacy violation, spam potential
   - **Fix:** Verify user relationship (client-trainer, etc.) before allowing chat

7. **Meeting Room No Access Control**
   - **File:** `lib/pages/video_sessions/meeting_room_page.dart`
   - **Issue:** Any user can join any meeting by ID
   - **Impact:** Unauthorized access to video sessions
   - **Fix:** Verify user is participant or has permission before joining

### MEDIUM Severity

8. **Discover Page No Role Filtering**
   - **File:** `lib/pages/discover/discover_page.dart`
   - **Issue:** Shows same results to all roles
   - **Impact:** Poor UX - trainers see other trainers in discover
   - **Fix:** Filter results by role (trainers see clients, clients see providers)

9. **Settings Page Accessible to All**
   - **File:** `lib/pages/profile/settings_page.dart`
   - **Issue:** Page accessible to all, only hides Service Locations option
   - **Impact:** Minor - page adapts UI but could be cleaner
   - **Fix:** Consider separate settings pages per role (optional)

10. **Profile Page No Role Guard**
    - **File:** `lib/pages/profile/profile_page.dart`
    - **Issue:** Page accessible to all, adapts UI
    - **Impact:** Minor - works but could be more explicit
    - **Fix:** Add role check for clarity (optional)

### LOW Severity

11. **Quest Page No Role Enforcement**
    - **File:** `lib/pages/quest/quest_page.dart`
    - **Issue:** Quest definitions have role field but not enforced in UI
    - **Impact:** Minor - quests may show to wrong roles
    - **Fix:** Filter quests by user role

12. **Cocircle No Role Filtering**
    - **File:** `lib/pages/cocircle/cocircle_page.dart`
    - **Issue:** Same feed for all roles
    - **Impact:** Minor - UX could be better
    - **Fix:** Consider role-based feed filtering (optional)

---

## 7) Next Actions (Prioritized)

### Immediate (Blockers - Fix Before Production)

1. **Add Role Guards to Router** (`lib/router/app_router.dart`)
   - Add role verification in redirect function
   - Block access to `/trainer/*` routes if role != 'trainer'
   - Block access to `/nutritionist/*` routes if role != 'nutritionist'
   - **Effort:** 2-3 hours

2. **Protect Client Detail Pages** (`lib/pages/trainer/client_detail_page.dart`, `lib/pages/nutritionist/nutritionist_client_detail_page.dart`)
   - Add role check in initState
   - Verify user owns the client (query Supabase)
   - Redirect if unauthorized
   - **Effort:** 3-4 hours

3. **Fix Video Session Role Verification** (`lib/pages/video_sessions/video_sessions_page.dart`, `lib/pages/video_sessions/create_meeting_page.dart`)
   - Remove query param role dependency
   - Read role from Supabase userMetadata
   - Verify role matches before showing features
   - **Effort:** 2-3 hours

4. **Protect Become Trainer Page** (`lib/pages/trainer/become_trainer_page.dart`)
   - Check role in initState
   - Redirect to dashboard if already trainer/nutritionist
   - **Effort:** 1 hour

### High Priority (Fix Before Beta)

5. **Protect Service Locations Page** (`lib/pages/profile/settings/service_locations_page.dart`)
   - Add role check in initState
   - Redirect if not provider
   - **Effort:** 30 minutes

6. **Add Chat Access Control** (`lib/pages/messaging/chat_screen.dart`)
   - Verify user relationship before allowing chat
   - Query Supabase for client-trainer/nutritionist relationship
   - **Effort:** 4-5 hours

7. **Protect Meeting Room** (`lib/pages/video_sessions/meeting_room_page.dart`)
   - Verify user is participant before joining
   - Query Supabase for meeting participants
   - **Effort:** 3-4 hours

### Medium Priority (Nice to Have)

8. **Add Role Filtering to Discover** (`lib/pages/discover/discover_page.dart`)
   - Filter results by user role
   - **Effort:** 2-3 hours

9. **Enforce Quest Role Filtering** (`lib/pages/quest/quest_page.dart`)
   - Filter quests by user role
   - **Effort:** 1-2 hours

---

## Summary Statistics

- **Total Pages Analyzed:** 35+
- **Pages with Role Guards:** 2 (Settings, Profile - UI only)
- **Pages with Router Guards:** 0 (only auth check)
- **Pages with No Access Control:** 33+
- **Critical Security Gaps:** 4 (Blockers)
- **High Priority Gaps:** 3
- **Medium Priority Gaps:** 3
- **Low Priority Gaps:** 2

**Overall RBAC Status:** ❌ **NOT PRODUCTION READY**

The app has significant role-based access control gaps. Most pages rely on UI hiding/showing rather than actual route protection. Critical routes like trainer/nutritionist dashboards and client detail pages are accessible to any authenticated user.
