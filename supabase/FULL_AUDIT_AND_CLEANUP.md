# Cotrainr Full Audit & Cleanup Report

**Date:** 2025-02-13  
**Scope:** Database, Realtime, Followers, Signup UI  
**Status:** Ready for manual review and execution

---

## 1. Database Inspection & Cleanup

### 1.1 Table Audit

| table_name | row_count* | foreign_keys | referenced_by | RLS policies | Classification |
|------------|------------|--------------|---------------|--------------|----------------|
| profiles | * | id→auth.users | providers, posts, leads, conversations, messages, post_comments, post_likes, user_follows | SELECT/INSERT/UPDATE | **CORE** |
| providers | * | user_id→auth.users | provider_locations, leads, conversations | RLS | **CORE** |
| provider_locations | * | provider_id→providers | nearby_providers RPC | RLS | **CORE** |
| subscriptions | * | user_id→auth.users | create_lead_tx | RLS | **CORE** |
| weekly_usage | * | user_id→auth.users | create_lead_tx | RLS | **CORE** |
| leads | * | client_id, provider_id | conversations, update_lead_status_tx | RLS | **CORE** |
| conversations | * | lead_id, client_id, provider_id, other_user_id | messages | RLS | **CORE** |
| messages | * | conversation_id, sender_id | - | RLS | **CORE** |
| video_sessions | * | lead_id, host_id | - | RLS | **OPTIONAL** |
| posts | * | author_id | post_media, post_likes, post_comments, post_reports | RLS | **CORE** |
| post_media | * | post_id | - | RLS | **CORE** |
| post_likes | * | post_id, user_id | - | RLS | **CORE** |
| post_comments | * | post_id, author_id | - | RLS | **CORE** |
| post_reports | * | post_id, reporter_id | - | RLS | **OPTIONAL** |
| meals | * | user_id | meal_items, meal_media | RLS | **UNUSED** |
| meal_items | * | meal_id | - | RLS | **UNUSED** |
| meal_media | * | meal_id | - | RLS | **UNUSED** |
| metrics_daily | * | user_id | - | RLS | **CORE** |
| user_profiles | * | user_id | - | RLS | **CORE** |
| user_quests | * | user_id | - | RLS | **CORE** |
| user_quest_settings | * | user_id | - | RLS | **CORE** |
| user_quest_refills | * | user_id | - | RLS | **CORE** |
| quests | * | - | user_quests (quest_definition_id) | - | **OPTIONAL** |
| achievements | * | - | user_achievements | RLS | **CORE** |
| user_achievements | * | user_id, achievement_id | - | RLS | **CORE** |
| challenges | * | created_by | challenge_members, challenge_progress | RLS | **CORE** |
| challenge_members | * | challenge_id, user_id | - | RLS | **CORE** |
| challenge_progress | * | challenge_id, user_id | - | RLS | **CORE** |
| leaderboard_points | * | user_id | get_leaderboard RPC | RLS | **CORE** |
| notifications | * | user_id | - | RLS | **CORE** |
| user_follows | * | follower_id, following_id→auth.users | - | RLS | **CORE** |
| user_streaks | * | user_id | - | RLS | **CORE** |

*Run `supabase/scripts/inspect_schema.sql` for live row counts and write activity.

### 1.2 KEEP / ARCHIVE / DROP

| Action | Tables |
|--------|--------|
| **KEEP** | profiles, providers, provider_locations, subscriptions, weekly_usage, leads, conversations, messages, posts, post_media, post_likes, post_comments, metrics_daily, user_profiles, user_quests, user_quest_settings, user_quest_refills, achievements, user_achievements, challenges, challenge_members, challenge_progress, leaderboard_points, notifications, user_follows, user_streaks |
| **ARCHIVE** | meals, meal_items, meal_media |
| **OPTIONAL KEEP** | video_sessions, post_reports, quests |
| **DROP** | Only after archive + backup |

### 1.3 Tables Not Used by Flutter

- **meals**, **meal_items**, **meal_media** – Meal tracker uses local state only (`meal_tracker_page_v2.dart`)

### 1.4 SQL: Archive Unused Tables

```sql
-- Run after backup
CREATE SCHEMA IF NOT EXISTS archive;

-- Drop RLS policies first
DROP POLICY IF EXISTS "Users can manage own meal media" ON public.meal_media;
DROP POLICY IF EXISTS "Users can manage own meal items" ON public.meal_items;
DROP POLICY IF EXISTS "Users can manage own meals" ON public.meals;

-- Move to archive
ALTER TABLE public.meal_media SET SCHEMA archive;
ALTER TABLE public.meal_items SET SCHEMA archive;
ALTER TABLE public.meals SET SCHEMA archive;
```

### 1.5 SQL: Drop After Archive

```sql
-- Only if archived above
DROP TABLE IF EXISTS archive.meal_media CASCADE;
DROP TABLE IF EXISTS archive.meal_items CASCADE;
DROP TABLE IF EXISTS archive.meals CASCADE;
```

---

## 2. Fix: column "category" does not exist

### 2.1 Root Cause

- **user_quests** – `allocate_daily_quests`, `allocate_weekly_quests`, `generate_dynamic_quest`, and triggers use `category`
- **quests** – Static allocation uses `v_quest_def.category`
- **achievements** – Some code paths expect `category`

If migrations ran out of order, these columns may be missing.

### 2.2 Fix Applied

Migration: `supabase/migrations/20250213_fix_category_column.sql`

- Adds `category TEXT NOT NULL DEFAULT 'steps'` to `user_quests` if missing
- Adds `category` to `quests` and `achievements` if missing
- Idempotent, safe to run multiple times

### 2.3 Flutter Queries

No Flutter code selects `category` directly. Quest data comes from RPCs and `user_quests` rows; the app uses `requirements` JSON for display.

---

## 3. Realtime Chat Architecture

### 3.1 Current State

- **Schema:** `conversations` + `messages` (see `complete_safe_migration` + `cocircle_direct_conversations`)
- **Realtime:** `messages` in `supabase_realtime` publication (in cocircle migration)
- **RLS:** Participants can view/send (client_id, provider_id, or other_user_id)
- **Flutter:** `MessagesRepository.subscribeToMessages(conversationId)` uses `postgres_changes` with `filter: conversation_id`

### 3.2 Schema Summary

```sql
-- conversations: id, lead_id (nullable), client_id, provider_id (nullable), other_user_id (nullable)
-- messages: id, conversation_id, sender_id, content, media_url, read_at, created_at
-- Index: idx_messages_conversation_id (for realtime filter)
```

### 3.3 Flutter Subscription (Already Correct)

```dart
// lib/repositories/messages_repository.dart
RealtimeChannel subscribeToMessages(String conversationId, Function(Map<String, dynamic>) onNewMessage) {
  return _supabase
      .channel('messages:$conversationId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) => onNewMessage(payload.newRecord),
      )
      .subscribe();
}
```

### 3.4 Index for Performance

```sql
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
```

Add to a migration if not already present.

---

## 4. Followers / Following Model

### 4.1 Current Model

- **Table:** `user_follows(follower_id, following_id, created_at)`
- **Followers** = `WHERE following_id = profile.id`
- **Following** = `WHERE follower_id = profile.id`
- **Flutter:** `FollowRepository.getFollowers()`, `getFollowing()`, `getFollowerCount()`, `getFollowingCount()`

### 4.2 Cached Counts (New)

Migration: `supabase/migrations/20250213_follower_counts_on_profiles.sql`

- Adds `profiles.followers_count`, `profiles.following_count`
- Trigger `trg_user_follows_update_counts` on INSERT/DELETE
- Backfills existing data

### 4.3 Flutter: Use Cached Counts

```dart
// In profile fetch, include followers_count, following_count
final profile = await _supabase
    .from('profiles')
    .select('id, username, full_name, avatar_url, followers_count, following_count')
    .eq('id', userId)
    .single();
```

---

## 5. Signup Flow UI Audit

### 5.1 Location

- **Main:** `lib/pages/auth/signup_wizard_page.dart`
- **Route:** `/auth/create-account`

### 5.2 Oversized Elements

| Element | Current | Recommended |
|---------|---------|-------------|
| Step title fontSize | 32 | 24 |
| Header padding | 24, 16, 20 | 16, 12, 16 |
| Progress bar height | 4 / 3 | 3 / 2 |
| SizedBox between fields | 24 | 16 |
| Picker itemExtent | 50 | 40 |
| Picker fontSize (selected) | 24 | 18 |
| Picker fontSize (unselected) | 20 | 16 |
| Button padding vertical | 14 | 12 |
| _GradientPicker itemExtent | 40 | 36 |
| Gender symbol fontSize | 28 | 24 |

### 5.3 Refactored Values (Applied in signup_wizard_page.dart)

- `fontSize: 32` → `24` (step title)
- `padding: EdgeInsets.fromLTRB(24, 16, 24, 20)` → `(16, 12, 16, 16)`
- `height: 4` / `3` → `3` / `2` (progress)
- `SizedBox(height: 24)` → `16` (between fields)
- `itemExtent: 50` → `40` (pickers)
- `fontSize: 24` / `20` → `18` / `16` (picker text)
- `padding: EdgeInsets.symmetric(vertical: 14)` → `12` (button)
- `fontSize: 28` → `24` (gender symbol)
- `SizedBox(height: 220)` → `180` (date picker)
- `SizedBox(height: 200)` → `160` (height/weight pickers)
- `SizedBox(height: 180)` → `150` (role picker)

---

## 6. Final Output Summary

### 6.1 SQL Scripts

| Script | Purpose |
|--------|---------|
| `20250213_fix_category_column.sql` | Add missing `category` columns |
| `20250213_follower_counts_on_profiles.sql` | Cached follower/following counts + triggers |
| `20250213_add_total_xp_if_missing.sql` | Add `total_xp` to user_profiles |
| `20250213_archive_unused_meal_tables.sql` | Template for archiving meals (commented) |
| Archive + Drop | See sections 1.4, 1.5 |

### 6.2 App Fixes

| File | Change |
|------|--------|
| `lib/services/leads_service.dart` | Use `rating` instead of `rating_avg` in providers select |
| `lib/pages/auth/signup_wizard_page.dart` | Reduce paddings, font sizes, item extents |
| Profile fetches | Include `followers_count`, `following_count` when available |

### 6.3 Production Schema (Locked)

**CORE (28):** profiles, providers, provider_locations, subscriptions, weekly_usage, leads, conversations, messages, posts, post_media, post_likes, post_comments, metrics_daily, user_profiles, user_quests, user_quest_settings, user_quest_refills, achievements, user_achievements, challenges, challenge_members, challenge_progress, leaderboard_points, notifications, user_follows, user_streaks

**OPTIONAL (3):** video_sessions, post_reports, quests

**ARCHIVED (3):** meals, meal_items, meal_media

**DO NOT TOUCH:** auth.*, storage.*, realtime.*

---

## 7. Execution Order

1. Run `20250213_fix_category_column.sql`
2. Run `20250213_add_total_xp_if_missing.sql`
3. Run `20250213_follower_counts_on_profiles.sql`
4. Fix `leads_service.dart` (rating_avg → rating)
5. Apply signup UI refactor
6. After backup: archive meal tables (section 1.4)
7. Optionally drop archived tables (section 1.5)
