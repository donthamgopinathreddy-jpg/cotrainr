# Cotrainr Flutter – Evidence-Based Audit Report

**Audit date:** February 2025  
**Scope:** Full app flow, data model, timers, RLS/security, launch blockers, roadmap  
**Rules:** No refactors; every claim cites file:line; "not found" when uncertain.

---

## 1) App Flow Map (End-to-End)

### Welcome → Login → Signup → Session Restore

| Step | Navigation | Data Flow | Citations |
|------|------------|-----------|-----------|
| **Entry** | Router `initialLocation: '/welcome'` | — | `app_router.dart:33` |
| **Session restore** | `_checkSession()` → `context.go('/home')` if `supabase.auth.currentSession != null` | Uses `Supabase.instance.client.auth.currentSession` | `welcome_page.dart:111-121` |
| **Login tap** | `_goToLogin()` → `context.push('/auth/login')` | — | `welcome_page.dart:133` |
| **Signup tap** | `_goToCreateAccount()` → `context.push('/auth/create-account')` | — | `welcome_page.dart:138` |
| **Login (email/password)** | `signInWithPassword()` → `context.go('/home')` | `login_page.dart:193-200` | `login_page.dart:186-216` |
| **Login (OAuth)** | `signInWithOAuth()` → redirect to `cotrainr://auth-callback` | No explicit post-OAuth redirect in app; Supabase handles callback | `login_page.dart:162-166` |
| **Signup** | `signUp()` → `sync_profile_role_from_auth` RPC → `context.go('/auth/permissions', extra: {'role': role})` | Role from signup choice; RPC syncs profile | `signup_wizard_page.dart:432-441` |
| **Permissions** | `context.go('/trainer/dashboard')` or `/nutritionist/dashboard` or `/home` | Role from `state.extra['role']` | `permissions_page.dart:238-244` |

### Role Routing

| Where | How role is determined | Where stored | Citations |
|-------|-------------------------|--------------|-----------|
| **Router redirect** | `user.userMetadata?['role']` (auth metadata) | Auth metadata | `app_router.dart:54-66` |
| **Home shell tabs** | `ref.watch(currentUserProvider).value` → `CurrentUser.role` | `user_profiles` via `get_my_profile` RPC | `home_shell_page.dart:34-36, 164-166` |
| **ProfileRoleService** | `get_my_profile` RPC → `list.first['role']` | `profiles.role` (or `user_profiles` depending on schema) | `profile_role_service.dart:14-15, 26` |
| **ensureProfileExists** | `user.userMetadata?['role']` → insert into `profiles` if missing | `profiles` table | `profile_role_service.dart:38-49` |

**Note:** Router uses `userMetadata['role']`; app shell uses `get_my_profile` (DB). Mismatch possible if metadata not synced.

### Home Shell Tabs

| Tab index | Tab name | Page shown | Citations |
|-----------|----------|------------|-----------|
| 0 | Home | `HomePageV3` | `home_shell_page.dart:167-174` |
| 1 | Discover / My Clients | `DiscoverPage` (client) or `TrainerMyClientsPage` or `NutritionistMyClientsPage` (provider) | `home_shell_page.dart:179-183` |
| 2 | Quest | `QuestPage` | `home_shell_page.dart:184` |
| 3 | Cocircle | `CocirclePage` | `home_shell_page.dart:185` |
| 4 | Profile | `ProfilePage` | `home_shell_page.dart:186` |

### Client User Flows

| Flow | Router/Page | Repository/Service | Citations |
|------|-------------|--------------------|-----------|
| **Discover nearby providers** | `DiscoverPage` (tab 1) | `ProviderLocationsRepository().fetchNearbyProviders()` → RPC `nearby_providers` | `discover_page.dart:55`; `provider_locations_repository.dart:162` |
| **Social (Cocircle)** | `CocirclePage` (tab 3) | `PostsRepository.fetchRecentPosts()` → RPC `get_cocircle_feed`; `FollowRepository` | `posts_repository.dart:30`; `cocircle_page.dart` |
| **Profile** | `ProfilePage` (tab 4) | `ProfileRepository`, `get_my_profile`, `get_public_profile` | `profile_repository.dart:21, 37` |
| **Messaging** | `/messaging` → `MessagingPage`; `/messaging/chat/:userId` → `ChatScreen` | `MessagesRepository` → `conversations`, `messages`; RPC `get_public_profile` | `app_router.dart:165-365`; `messages_repository.dart:20, 94` |
| **Meal Tracker** | `/meal-tracker` → `MealTrackerPageV2` | `MealRepository`, `FoodCatalogRepository` → `meals`, `meal_items`, `foods`, `food_portions` | `app_router.dart:173-177`; `meal_repository.dart:118, 186` |
| **Quests** | `QuestPage` (tab 2) | `QuestRepository` → RPCs `allocate_daily_quests`, `allocate_weekly_quests`, `claim_quest_rewards`, `refill_quests` | `quest_page.dart`; `quest_repository.dart:25, 202, 370, 379` |

### Provider Flows (Trainer/Nutritionist)

| Flow | Page | Repository/Service | Citations |
|------|------|--------------------|-----------|
| **Service Locations CRUD** | `ServiceLocationsPage` (from profile settings) | `ProviderLocationsRepository` → `provider_locations` (select, insert, update, delete) | `service_locations_page.dart:15`; `provider_locations_repository.dart:28, 70, 96, 113` |
| **Discovery visibility** | `nearby_providers` RPC | Masks home geo (`is_public_exact=false`); no direct SELECT on `provider_locations` | `20250127_add_missing_tables_safe.sql:411`; `provider_locations_repository.dart:162` |
| **Profile differences** | `TrainerProfilePage`, `NutritionistProfilePage` | Same `ProfileRepository`; role from `currentUserProvider` | `trainer_profile_page.dart`; `nutritionist_profile_page.dart` |
| **Leads** | `LeadsService` | Edge Functions `create-lead`, `update-lead-status`; table `leads` | `leads_service.dart:15-56, 65-76` |
| **Coach notes** | `CoachNotesPage` | `CoachNotesRepository` → `coach_notes` | `coach_notes_repository.dart:54, 110` |

---

## 2) Data Model Map

### Discover / provider_locations

| Table/RPC | Used by | Citations |
|-----------|---------|-----------|
| `provider_locations` | CRUD via `ProviderLocationsRepository` | `provider_locations_repository.dart:28, 70, 96, 113, 130` |
| RPC `nearby_providers` | `fetchNearbyProviders()` | `provider_locations_repository.dart:162` |

### Social Feed (Cocircle)

| Table/RPC | Used by | Citations |
|-----------|---------|-----------|
| RPC `get_cocircle_feed` | `PostsRepository.fetchRecentPosts()` | `posts_repository.dart:30` |
| `posts`, `post_media`, `post_likes`, `post_comments` | Posts CRUD, likes, comments | `posts_repository.dart:41, 91, 198, 236, 330` |
| RPC `get_public_profile`, `get_public_profiles` | Author profiles | `posts_repository.dart:129, 258, 309`; `follow_repository.dart:133, 186` |
| `user_follows` | Follow/unfollow | `follow_repository.dart:20, 59, 76, 106` |

### Messaging

| Table/RPC | Used by | Citations |
|-----------|---------|-----------|
| `conversations`, `messages` | `MessagesRepository` | `messages_repository.dart:20, 34, 56, 77, 120, 152, 235` |
| RPC `get_public_profile` | Other user profile in chat | `messages_repository.dart:94` |

### Meal Tracker + Food Catalog

| Table/RPC | Used by | Citations |
|-----------|---------|-----------|
| `meals`, `meal_items` | `MealRepository` | `meal_repository.dart:118, 186, 369, 426, 441` |
| `nutrition_goals` | Goals upsert | `meal_repository.dart:303, 318, 342` |
| `foods`, `food_portions` | `FoodCatalogRepository` | `food_catalog_repository.dart:66, 99` |

### Quests + XP/Level

| Table/RPC | Used by | Citations |
|-----------|---------|-----------|
| RPC `allocate_daily_quests`, `allocate_weekly_quests` | `QuestRepository.getDailyQuests()`, `getWeeklyQuests()` | `quest_repository.dart:25, 202` |
| RPC `claim_quest_rewards`, `update_quest_progress`, `refill_quests` | Quest actions | `quest_repository.dart:359, 370, 379` |
| `user_quests`, `quests` | Quest definitions and progress | `quest_repository.dart:41, 96, 216, 254` |
| `user_profiles` | XP, level (via direct select) | `quest_provider.dart:58-62, 79-83` |
| RPC `get_xp_for_next_level` | Tier/level display | `quest_provider.dart:103-108` |
| `challenges`, `achievements`, `leaderboard_points` | Challenges, achievements, leaderboard | `quest_repository.dart:394, 459, 575, 632` |

### Notifications / Device Tokens

| Table/RPC | Used by | Citations |
|-----------|---------|-----------|
| `notifications` | `NotificationsRepository` | `notifications_repository.dart:20, 47, 65, 83, 101` |
| `device_tokens` | `PushNotificationService` | `push_notification_service.dart:137` |

---

## 3) Timers / Background Loops Audit

| Location | Interval | What it does | Duplicated? |
|----------|----------|--------------|-------------|
| `quest_progress_sync_service.dart:31` | 30s | `Timer.periodic` → sync quest progress | Yes – see quest_page |
| `quest_page.dart:58` | 15s | `Timer.periodic` → `_syncQuestProgress()` | **Yes** – overlaps with QuestProgressSyncService |
| `video_sessions_page.dart:49` | 1 min | `_meetingStatusTimer` – meeting status poll | No |
| `video_sessions_page.dart:1320` | 1s | `_timer` – UI countdown | No |
| `meeting_room_page.dart:137` | 1 min | `_durationCheckTimer` – duration check | No |
| `background_health_tracker.dart:52` | 30s | `Timer.periodic` → track + `metricsSyncService.syncNow()` | Yes – see metrics |
| `metrics_sync_service.dart:40` | 30s | `Timer.periodic` → sync metrics | **Yes** – BackgroundHealthTracker also calls syncNow |
| `health_tracking_provider.dart:28` | 30s | `Stream.periodic` – steps polling | No (different purpose) |
| `health_tracking_provider.dart:56` | 30s | `Timer.periodic` – `_updateTimer` | No |
| `feed_preview_v3.dart:286` | 4s | `Timer.periodic` – carousel auto-advance | No |

**Duplications:**
- Quest sync: `quest_page.dart:58` (15s) + `quest_progress_sync_service.dart:31` (30s)
- Metrics sync: `metrics_sync_service.dart:40` (30s) + `background_health_tracker.dart:52` (30s) calls `syncNow()`

---

## 4) RLS + Security Assumptions

### RPCs Taking `user_id` (Client Trust Risk)

| RPC | Param | Caller | Auth check in RPC? | Citations |
|-----|-------|--------|--------------------|-----------|
| `allocate_daily_quests` | `p_user_id` | `quest_repository.dart:25` (passes `auth.currentUser?.id`) | **No** – uses `p_user_id` directly | `20250127_complete_quest_system.sql:629` |
| `allocate_weekly_quests` | `p_user_id` | `quest_repository.dart:202` | **No** | `20250127_complete_quest_system.sql:733` |
| `refill_quests` | (none in newer schema; older has `p_user_id`) | `quest_repository.dart:379` | Uses `auth.uid()` internally in some migrations | Migration varies |
| `get_public_profile` | `p_user_id` | `profile_repository.dart:37`, `posts_repository.dart:129`, `messages_repository.dart:94` | SECURITY DEFINER; returns public columns only – read-only, low risk | `20250213_cocircle_feed_fix.sql:219` |
| `get_public_profiles` | `p_user_ids` | `follow_repository.dart:133, 186`, `posts_repository.dart:258` | SECURITY DEFINER; read-only | `20250213_cocircle_feed_fix.sql:237` |
| `grant_referral_rewards` | `p_referred_id` | `referral_repository.dart:62` (passes `auth.currentUser?.id`) | RPC validates `referred_id = p_referred_id` in referrals; grants for self only | `20250213_referral_system.sql:198` |

**Risk:** `allocate_daily_quests` and `allocate_weekly_quests` accept `p_user_id` from client without enforcing `p_user_id = auth.uid()`. A malicious client could allocate quests for another user.

### Direct Writes to `user_profiles` (XP/Level)

| Location | Action | Citations |
|----------|--------|-----------|
| App does **not** write XP/level directly | All XP/level changes via RPCs | — |
| `claim_quest_rewards` RPC | Updates `user_profiles`; enforces `uq.user_id = auth.uid()` | `20250213_fix_claim_quest_rewards_xp.sql:31` |

### SECURITY DEFINER Functions

| Function | Migration | Notes |
|---------|-----------|-------|
| `nearby_providers` | `20250127_provider_locations.sql:216` | No `user_id` param; uses caller coords |
| `get_public_profile`, `get_public_profiles` | `20250213_cocircle_feed_fix.sql:219, 237` | Read-only; returns public columns |
| `allocate_daily_quests`, `allocate_weekly_quests` | `20250127_complete_quest_system.sql:632, 736` | Take `p_user_id` – **no auth.uid() check** |
| `claim_quest_rewards` | `20250213_fix_claim_quest_rewards_xp.sql:14` | Enforces `uq.user_id = auth.uid()` ✓ |
| `grant_referral_rewards` | `20250213_referral_system.sql` | Validates referral row |
| `create_lead_tx`, admin RPCs | Various | Admin/edge-function use |

---

## 5) Top Issues Blocking Launch (Ranked)

| # | Severity | Symptom | Root cause | Fix | Verification |
|---|----------|---------|------------|-----|--------------|
| 1 | **P0** | Supabase URL/key exposed if repo is public | Hardcoded in `supabase_config.dart:6-8` | Use `String.fromEnvironment('SUPABASE_URL')` and `--dart-define` | Grep for hardcoded key; build with env |
| 2 | **P0** | XP shows 0 on load failure; no retry | `quest_provider.dart:68-69` catches and returns 0 | Remove catch; let error propagate | Force network error; confirm error UI |
| 3 | **P0** | Level shows 1 on load failure | `quest_provider.dart:86-87` catches and returns 1 | Same as above | Same |
| 4 | **P0** | Client can allocate quests for another user | `allocate_daily_quests`, `allocate_weekly_quests` accept `p_user_id` without `auth.uid()` check | Add `IF p_user_id != auth.uid() THEN RAISE EXCEPTION` at start of both RPCs | Call RPC with different UUID; expect error |
| 5 | **P1** | Duplicate quest sync (extra network) | `quest_page.dart:58` (15s) + `quest_progress_sync_service.dart:31` (30s) | Remove quest_page timer; keep service only | No timer in quest_page; service still runs |
| 6 | **P1** | HealthTrackingService created 3x | `main.dart:22`, `health_tracking_provider.dart:7`, `background_health_tracker.dart:76` | Use `ref.read(healthTrackingServiceProvider)` in BackgroundHealthTracker | Single instance |
| 7 | **P1** | Discover/Nearby bypass provider | `discover_page.dart:55`, `nearby_preview_v3.dart:25` instantiate repo directly | Use `ref.read(providerLocationsRepositoryProvider)` | Discover uses provider |
| 8 | **P1** | Dead QuestService with client-side `_awardXP` | `quest_service.dart:355, 359-360` – unused, could award XP if wired | Delete or deprecate; app uses `claim_quest_rewards` RPC | Grep confirms QuestService unused |
| 9 | **P1** | entitlementsProvider swallows errors | `entitlements_provider.dart:14-15` returns null on catch | Propagate error | Entitlements UI shows error |
| 10 | **P2** | stepsProvider Stream.periodic never ends | `health_tracking_provider.dart:28` | Use `take(n)` or prefer StepsNotifier | Stream completes on dispose |
| 11 | **P2** | main.dart unused import | `main.dart:9` `background_health_tracker.dart` | Remove if unused | `flutter analyze` passes |
| 12 | **P2** | Role mismatch: router vs DB | Router uses `userMetadata['role']`; shell uses `get_my_profile` | Ensure `sync_profile_role_from_auth` called on login; or router reads profile | Trainer login → trainer dashboard |
| 13 | **P2** | OAuth callback flow unclear | `login_page.dart:164` redirectTo `cotrainr://auth-callback` | Verify deep link + session restore | OAuth login → home |
| 14 | **P2** | Duplicate metrics sync | `metrics_sync_service.dart:40` + `background_health_tracker.dart:52` | Consolidate; one sync entry point | Single sync path |
| 15 | **P2** | signup_wizard unused `_isValidPassword` | `signup_wizard_page.dart:821` | Remove or use | Analyzer clean |

---

## 6) Quick Win Roadmap (2 Weeks)

| Day | Focus | Tasks | Dependencies |
|-----|-------|-------|---------------|
| **1** | Auth stability | Move Supabase config to env (P0 #1); fix userXPProvider/userLevelProvider error handling (P0 #2, #3) | None |
| **2** | Security | Add `auth.uid()` check to `allocate_daily_quests` and `allocate_weekly_quests` (P0 #4) | Migration |
| **3** | Role routing | Verify `sync_profile_role_from_auth` on login; test trainer/nutritionist redirect (P2 #12) | Auth |
| **4** | Discovery | Discover/Nearby use provider (P1 #7) | None |
| **5** | Messaging | Smoke test chat flow; verify conversation/message RLS | None |
| **6** | Quests claim | Remove quest_page sync timer (P1 #5); verify claim flow | None |
| **7** | Permissions | Test permissions page flow for all roles | Auth |
| **8** | Notifications | Verify device token registration; push receipt | None |
| **9** | Performance | Single HealthTrackingService (P1 #6); deprecate QuestService (P1 #8) | None |
| **10** | Cleanup | entitlementsProvider (P1 #9); main.dart import (P2 #11); metrics sync consolidation (P2 #14) | None |

---

## 7) Missing / Dead Code

| Item | Evidence | Action |
|------|----------|--------|
| **QuestService** | `quest_service.dart:8` – class exists; `_awardXP` at 359; no imports | Delete or add `@Deprecated` |
| **Legacy QuestService.claimQuest** | `quest_service.dart:355-360` – client-side XP award | Unused; app uses `claim_quest_rewards` RPC |
| **welcome_animation_page** | `context.go('/home')` at 80 | Separate entry path; verify if used |
| **_isValidPassword** | `signup_wizard_page.dart:821` | Unused; remove or wire |
| **MetricsRepository** | Created per sync in `metrics_sync_service.dart:71` | Consider provider for reuse |

---

## 8) Build Risks

### Analyzer (from prior run)

- `main.dart:9` – Unused import `background_health_tracker.dart`
- `main.dart:25, 27` – `avoid_print`
- `signup_wizard_page.dart:821` – Unused `_isValidPassword`
- `image_crop_page.dart:158` – `use_build_context_synchronously`
- Multiple `withOpacity` deprecations (use `withValues`)

### Large Files (Slow Debug)

- `meeting_room_page.dart` – ~3400 lines
- `quest_page.dart` – ~2680 lines
- `signup_wizard_page.dart` – ~2700 lines

### Likely Break Risks

- `app_router.dart` – Central; route changes can break navigation
- `profile_role_service.dart` – `ensureProfileExists` inserts into `profiles`; schema must match
- `quest_repository.dart` – RPC param names must match migrations (`p_user_id`, etc.)
