# Cotrainr Supabase Database Audit Report

**Generated:** 2025-02-13  
**Scope:** public schema tables, triggers, functions, views, RLS policies, Flutter app usage  
**Note:** No automatic changes. All SQL is for manual review and execution.

---

## 1. Table-by-Table Audit

### Row Counts & Write Activity

*Row counts and recent write activity require running against your live database. Use the inspection queries in Section 6.*

| Table | Source Migration | App Usage | Classification |
|-------|------------------|-----------|----------------|
| **profiles** | complete_safe_migration | ✅ Auth, edit profile, posts, follows, messaging | **Core** |
| **providers** | complete_safe_migration | ✅ Discover, leads, nearby_providers RPC | **Core** |
| **provider_locations** | complete_safe_migration | ✅ Discover, nearby_providers RPC | **Core** |
| **subscriptions** | complete_safe_migration | ✅ create_lead_tx RPC (quota) | **Core** |
| **weekly_usage** | complete_safe_migration | ✅ create_lead_tx RPC (quota) | **Core** |
| **leads** | complete_safe_migration | ✅ LeadsService, create_lead_tx, update_lead_status_tx | **Core** |
| **conversations** | complete_safe_migration + cocircle | ✅ MessagesRepository, chat, Cocircle DMs | **Core** |
| **messages** | complete_safe_migration | ✅ ChatScreen, Realtime | **Core** |
| **video_sessions** | complete_safe_migration | ✅ video_sessions_page (routing) | **Optional** |
| **posts** | complete_safe_migration | ✅ PostsRepository, Cocircle feed | **Core** |
| **post_media** | complete_safe_migration | ✅ PostsRepository | **Core** |
| **post_likes** | complete_safe_migration | ✅ PostsRepository | **Core** |
| **post_comments** | complete_safe_migration | ✅ PostsRepository | **Core** |
| **post_reports** | complete_safe_migration | ✅ RLS only | **Optional** |
| **meals** | complete_safe_migration | ❌ Not used (meal_tracker is local-only) | **Unused** |
| **meal_items** | complete_safe_migration | ❌ Not used | **Unused** |
| **meal_media** | complete_safe_migration | ❌ Not used | **Unused** |
| **metrics_daily** | complete_safe_migration | ✅ MetricsRepository, quest progress | **Core** |
| **user_profiles** | complete_safe_migration + quest | ✅ Quest XP/level, allocate_daily_quests, claim_quest_rewards | **Core** |
| **user_quests** | complete_safe_migration + quest | ✅ QuestRepository, allocate/claim RPCs | **Core** |
| **user_quest_settings** | complete_safe_migration | ✅ allocate_daily_quests, refill_quests | **Core** |
| **user_quest_refills** | complete_safe_migration | ✅ refill_quests RPC | **Core** |
| **quests** | complete_quest_system | ⚠️ Static quest definitions; dynamic quests use NULL | **Optional** |
| **achievements** | complete_quest_system | ✅ QuestRepository (user_achievements join) | **Core** |
| **user_achievements** | complete_quest_system | ✅ QuestRepository | **Core** |
| **challenges** | complete_quest_system | ✅ QuestRepository, create_challenge, join_challenge | **Core** |
| **challenge_members** | complete_quest_system | ✅ join_challenge RPC | **Core** |
| **challenge_progress** | complete_quest_system | ✅ update_challenge_progress RPC | **Core** |
| **leaderboard_points** | complete_safe_migration | ✅ get_leaderboard RPC, QuestService | **Core** |
| **notifications** | complete_safe_migration | ✅ NotificationRepository | **Core** |
| **user_follows** | add_user_follows | ✅ FollowRepository, Cocircle | **Core** |
| **user_streaks** | user_streaks_table | ✅ StreakService | **Core** |

---

## 2. App Usage Summary

### Tables Used by Flutter App

| Component | Tables | RPCs |
|-----------|--------|------|
| Auth/Profiles | profiles | - |
| Discover | provider_locations, providers, profiles | nearby_providers |
| Leads | leads, profiles, providers | Edge: create-lead, update-lead-status |
| Messaging | conversations, messages | - |
| Cocircle | posts, post_media, post_likes, post_comments, user_follows, profiles | - |
| Metrics | metrics_daily | - |
| Quests | user_profiles, user_quests, user_quest_settings, user_quest_refills, quests, achievements, user_achievements, challenges, challenge_members, challenge_progress, leaderboard_points | allocate_daily_quests, allocate_weekly_quests, update_quest_progress, claim_quest_rewards, refill_quests, create_challenge, join_challenge, update_challenge_progress, get_leaderboard |
| Streaks | user_streaks | - |
| Notifications | notifications | - |
| Video | video_sessions | - |

### Storage Buckets

- `avatars` – profile avatars
- `posts` – post media

### Supabase System Schemas (DO NOT MODIFY)

- `auth.*` – auth.users, auth.sessions, etc.
- `storage.*` – storage.buckets, storage.objects
- `realtime.*` – Realtime publication

---

## 3. Database Dependencies

### Triggers

| Trigger | Table | Function |
|---------|-------|----------|
| on_auth_user_created | auth.users | handle_new_user |
| trg_profiles_updated_at | profiles | set_updated_at |
| trg_providers_updated_at | providers | set_updated_at |
| trg_provider_locations_updated_at | provider_locations | set_updated_at |
| trg_user_profiles_updated_at | user_profiles | set_updated_at |
| trg_update_level_on_xp | user_profiles | (dynamic_quest_system) |
| trg_user_streaks_updated_at | user_streaks | set_updated_at |
| trg_user_achievements_updated_at | user_achievements | set_updated_at |
| trg_challenges_updated_at | challenges | set_updated_at |
| handle_primary_location | provider_locations | handle_primary_location |
| enforce_home_privacy | provider_locations | enforce_home_privacy |

### Functions Referencing Tables

| Function | References |
|----------|------------|
| handle_new_user | profiles |
| nearby_providers | provider_locations, providers, profiles |
| create_lead_tx | profiles, providers, subscriptions, weekly_usage, leads |
| update_lead_status_tx | leads, conversations |
| allocate_daily_quests | user_quests, user_profiles, user_quest_settings |
| allocate_weekly_quests | user_quests, user_profiles, user_quest_settings |
| generate_dynamic_quest | user_profiles, user_quests |
| update_quest_progress | user_quests, user_profiles, leaderboard_points |
| claim_quest_rewards | user_quests, user_profiles, user_quest_refills |
| refill_quests | user_quest_settings, user_quest_refills |
| create_challenge | challenges, challenge_members |
| join_challenge | challenges, challenge_members |
| update_challenge_progress | challenge_progress, challenges |
| get_leaderboard | leaderboard_points, profiles, user_profiles |

### Foreign Keys (Key Dependencies)

- **profiles** ← auth.users
- **providers** ← auth.users
- **provider_locations** ← providers
- **leads** ← auth.users, providers
- **conversations** ← leads (nullable), auth.users, providers (nullable), other_user_id → auth.users
- **messages** ← conversations
- **posts** ← auth.users
- **post_media** ← posts
- **post_likes** ← posts, auth.users
- **post_comments** ← posts, auth.users
- **meal_items** ← meals
- **meal_media** ← meals
- **user_achievements** ← achievements
- **challenge_members** ← challenges
- **challenge_progress** ← challenges

---

## 4. Broken References & Fixes

### 4.1 leads_service.dart – `rating_avg` Does Not Exist

**Location:** `lib/services/leads_service.dart` (lines 69–74)

**Issue:** Select uses `rating_avg` but `providers` table has `rating`.

**Fix (app):** Change select to use `rating` instead of `rating_avg`:

```dart
provider:providers!leads_provider_id_fkey(
  user_id,
  provider_type,
  verified,
  rating  // was rating_avg
)
```

### 4.2 user_profiles.total_xp

**Issue:** `complete_safe_migration` creates `user_profiles` with `xp`, not `total_xp`. Dynamic quest system expects `total_xp`.

**Status:** `complete_quest_system` migration adds `total_xp` if missing. Ensure migration order: `complete_safe_migration` → `complete_quest_system` → `dynamic_quest_system`.

**Verification:** If `total_xp` is missing, run:

```sql
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS total_xp INTEGER NOT NULL DEFAULT 0;
UPDATE public.user_profiles SET total_xp = COALESCE(xp, 0) WHERE total_xp = 0;
```

### 4.3 user_follows FKs to auth.users

**Issue:** `user_follows` FKs point to `auth.users`, not `profiles`. PostgREST cannot join `profiles` via these FKs.

**Status:** Already addressed – `FollowRepository` fetches profiles in a separate query.

---

## 5. Risk List – What Breaks If Deleted

| Action | Impact |
|--------|--------|
| Drop **profiles** | Auth, posts, messaging, discover, leads all break |
| Drop **providers** | Discover, leads, nearby_providers break |
| Drop **provider_locations** | Discover, nearby_providers break |
| Drop **leads** | Leads flow, create_lead_tx, update_lead_status_tx break |
| Drop **conversations** | Messaging, chat, Cocircle DMs break |
| Drop **messages** | Chat breaks |
| Drop **posts** / **post_media** / **post_likes** / **post_comments** | Cocircle feed breaks |
| Drop **user_profiles** | Quest system, level/XP, allocate/claim RPCs break |
| Drop **user_quests** | Quest system breaks |
| Drop **challenges** / **challenge_members** / **challenge_progress** | Challenges feature breaks |
| Drop **achievements** / **user_achievements** | Achievements feature breaks |
| Drop **meals** / **meal_items** / **meal_media** | No app impact (unused); RLS policies reference them |
| Drop **subscriptions** / **weekly_usage** | create_lead_tx quota logic breaks |
| Drop **quests** | Static quest definitions; dynamic quests still work (quest_definition_id NULL) |
| Drop **video_sessions** | Video sessions page may break if it queries this table |

---

## 6. Safe Cleanup Plan

### 6.1 Inspection Queries (Run First)

```sql
-- Row counts for public tables
SELECT schemaname, relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- Recent write activity (n_tup_ins + n_tup_upd + n_tup_del)
SELECT relname, n_tup_ins, n_tup_upd, n_tup_del,
       n_tup_ins + n_tup_upd + n_tup_del AS total_writes
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY total_writes DESC;
```

### 6.2 Create Archive Schema

```sql
CREATE SCHEMA IF NOT EXISTS archive;
```

### 6.3 Archive Unused Tables (meals, meal_items, meal_media)

```sql
-- Only run if you have confirmed these tables are unused and you want to archive
-- WARNING: This moves data. Ensure no app code uses these tables.

-- Check for any data first
SELECT 'meals' AS tbl, COUNT(*) FROM public.meals
UNION ALL SELECT 'meal_items', COUNT(*) FROM public.meal_items
UNION ALL SELECT 'meal_media', COUNT(*) FROM public.meal_media;

-- Archive (run only after backup)
ALTER TABLE public.meal_media SET SCHEMA archive;
ALTER TABLE public.meal_items SET SCHEMA archive;
ALTER TABLE public.meals SET SCHEMA archive;
```

### 6.4 Drop Unused Tables (Only After Archive & Verification)

```sql
-- Drop from archive schema if you archived above, or drop from public if empty
-- Run ONLY after: 1) Backup, 2) Archive, 3) Remove RLS policies that reference meals

-- First drop RLS policies that reference meals
DROP POLICY IF EXISTS "Users can manage own meals" ON public.meals;
DROP POLICY IF EXISTS "Users can manage own meal items" ON public.meal_items;
DROP POLICY IF EXISTS "Users can manage own meal media" ON public.meal_media;

-- If tables are in public and you want to drop (CASCADE drops dependent objects)
-- DROP TABLE IF EXISTS public.meal_media CASCADE;
-- DROP TABLE IF EXISTS public.meal_items CASCADE;
-- DROP TABLE IF EXISTS public.meals CASCADE;
```

### 6.5 Remove Orphan Triggers/Functions (If Any)

*Only if you have identified orphaned objects. Do not drop:*
- `set_updated_at` (used by many tables)
- `handle_new_user` (auth trigger)
- `handle_primary_location`, `enforce_home_privacy` (provider_locations)

### 6.6 Verify Supabase System Tables Untouched

```sql
-- Ensure no migrations modify auth, storage, or realtime
-- Your migrations should NOT contain:
--   ALTER TABLE auth.*
--   ALTER TABLE storage.*
--   ALTER TABLE realtime.*
```

---

## 7. Recommended Minimal Production Schema

### Core Tables (Must Keep)

```
profiles          – User identity, role, username
providers         – Trainer/nutritionist metadata
provider_locations – Geo for discover
subscriptions     – Plan for quota
weekly_usage      – Lead request quota
leads             – Client–provider requests
conversations     – Chat threads (lead-based + Cocircle DMs)
messages          – Chat messages
posts             – Cocircle feed
post_media        – Post images/videos
post_likes        – Likes
post_comments     – Comments
user_follows      – Follow graph
metrics_daily     – Steps, etc.
user_profiles     – Quest XP, level, coins
user_quests       – Quest instances
user_quest_settings
user_quest_refills
quests            – Static definitions (optional)
achievements      – Achievement definitions
user_achievements
challenges
challenge_members
challenge_progress
leaderboard_points
notifications
user_streaks
```

### Optional (Feature-Based)

| Table | Feature |
|-------|---------|
| post_reports | Moderation |
| video_sessions | Video calls |
| quests | Static quest definitions |

### Safe to Archive

| Table | Reason |
|------|--------|
| meals | Meal tracker uses local state only |
| meal_items | Depends on meals |
| meal_media | Depends on meals |

---

## 8. SQL Migration Scripts

### Fix: Add total_xp to user_profiles (If Missing)

```sql
-- File: supabase/migrations/YYYYMMDD_add_total_xp_to_user_profiles.sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_profiles' AND column_name = 'total_xp'
  ) THEN
    ALTER TABLE public.user_profiles ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0;
    UPDATE public.user_profiles SET total_xp = COALESCE(xp, 0) WHERE total_xp = 0;
  END IF;
END $$;
```

### Fix: leads_service rating_avg → rating (App Change)

See Section 4.1 – update `lib/services/leads_service.dart` to use `rating` instead of `rating_avg`.

---

## 9. Summary

| Category | Count |
|----------|-------|
| Core tables | 28 |
| Optional tables | 2 |
| Unused tables | 3 (meals, meal_items, meal_media) |
| Broken references | 1 (rating_avg in leads_service) |
| Schema fixes | 1 (total_xp in user_profiles if missing) |

**Actions:**
1. Fix `leads_service.dart` to use `rating` instead of `rating_avg`.
2. Ensure `total_xp` exists on `user_profiles` (run migration if needed).
3. Archive or drop `meals`, `meal_items`, `meal_media` only after backup and verification.
4. Do not modify `auth.*`, `storage.*`, or `realtime.*`.
