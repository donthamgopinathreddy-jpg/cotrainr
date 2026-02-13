# Duplicate & Unused Tables Report

**Schema analyzed:** Your current Supabase public schema  
**App reference:** Flutter codebase (lib/)

---

## 1. Duplicate Tables (Same Purpose, Different Implementations)

| Primary (App Uses) | Duplicate (Unused) | Notes |
|--------------------|-------------------|------|
| **post_comments** | **comments** | Both store post comments. App uses `post_comments` (author_id, content). `comments` has user_id, text, is_deleted – legacy/alternate schema. |
| **user_follows** | **follows** | Both store follow relationships. App uses `user_follows` (follower_id, following_id). `follows` has same structure but no id column – likely legacy. |
| **user_streaks** | **streaks** | Both track login/activity streaks. App uses `user_streaks` (current_streak, last_login_date). `streaks` has longest_streak, last_completed_date – different model. |
| **metrics_daily** | **daily_stats** | Both track daily metrics. App uses `metrics_daily` (steps, calories_burned, water_intake_liters, streak_days). `daily_stats` has steps, calories_burned, water_ml – overlapping. |
| **user_profiles** | **user_stats** | Both track XP/level/coins. App uses `user_profiles` (level, xp, coins, total_xp). `user_stats` has total_xp, coins, level – duplicate purpose. |
| **user_quests** | **quest_progress** / **user_quest_progress** | App uses `user_quests` (quest instances with progress_current, progress_target, status). `quest_progress` and `user_quest_progress` track progress differently – legacy quest systems. |
| **providers** | **trainers** / **trainer_profiles** | App uses `providers` (provider_type, specialization, rating) for discover/leads. `trainers` and `trainer_profiles` are alternate trainer representations – likely legacy. |
| **quests** | **quests_master** | App uses `quests` (dynamic quest system). `quests_master` has type, goal_value, coin_reward – simpler legacy schema. |
| **meals** + **meal_items** + **meal_media** | **meal_days** + **meal_photos** + **meals_logs** | Two meal-tracking systems. App uses neither (meal_tracker is local-only). Both are UNUSED. |
| **foods** | **foods_catalog** | Both are food databases. Neither used by app (meal_tracker uses local FoodItem). |

---

## 2. Unused Tables (No Flutter References)

| Table | Reason |
|-------|--------|
| **ai_plans** | No `.from('ai_plans')` or RPC reference in lib/ |
| **centers** | Discover page has "centers" tab but never fetches from `centers` table – uses `nearby_providers` RPC (provider_locations only). Tab shows empty list. |
| **client_trainer_links** | No references. App uses `leads` + `conversations` for client–provider links. |
| **comments** | Duplicate of post_comments; app uses post_comments |
| **competition_participants** | No references |
| **competitions** | No references. App uses `challenges` for competitions. |
| **conversation_members** | No references. App uses conversations with client_id, provider_id, other_user_id. |
| **daily_stats** | Duplicate of metrics_daily; app uses metrics_daily |
| **favorites_foods** | No references |
| **follows** | Duplicate of user_follows; app uses user_follows |
| **foods** | No references |
| **foods_catalog** | No references |
| **goals** | No references. UserGoalsService uses auth metadata + SharedPreferences. |
| **meal_days** | No references |
| **meal_photos** | No references |
| **meals** | No references (meal_tracker is local-only) |
| **meal_items** | No references |
| **meal_media** | No references |
| **meals_logs** | No references |
| **quest_progress** | Legacy; app uses user_quests |
| **quests_master** | Legacy; app uses quests |
| **reward_events** | No references |
| **spatial_ref_sys** | PostGIS system table – DO NOT DROP |
| **streaks** | Duplicate of user_streaks; app uses user_streaks |
| **trainer_meal_sharing** | No references |
| **trainer_notes** | No references |
| **trainer_profiles** | Legacy; app uses providers |
| **trainer_verifications** | No references |
| **trainers** | Legacy; app uses providers |
| **user_quest_progress** | Legacy; app uses user_quests |
| **user_stats** | Duplicate of user_profiles; app uses user_profiles |

---

## 3. Tables Used by App (KEEP)

| Table | Used By |
|-------|---------|
| achievements | quest_repository |
| challenge_members | join_challenge RPC |
| challenge_progress | update_challenge_progress RPC |
| challenges | quest_repository |
| conversations | messages_repository |
| leaderboard_points | quest_service, get_leaderboard RPC |
| leads | leads_service |
| messages | messages_repository |
| metrics_daily | metrics_repository |
| notifications | notifications_repository |
| post_comments | posts_repository |
| post_likes | posts_repository |
| post_media | posts_repository |
| post_reports | RLS only |
| posts | posts_repository |
| profiles | profile_repository, etc. |
| provider_locations | provider_locations_repository, nearby_providers RPC |
| providers | leads, nearby_providers RPC |
| quests | quest_repository |
| subscriptions | create_lead_tx RPC |
| user_achievements | quest_repository |
| user_follows | follow_repository |
| user_profiles | quest_provider, quest_service |
| user_quest_refills | quest_service |
| user_quest_settings | quest_service |
| user_quests | quest_repository, quest_service |
| user_streaks | streak_service |
| video_sessions | Video sessions page (routing) |
| weekly_usage | create_lead_tx RPC |

---

## 4. Summary

| Category | Count | Tables |
|----------|-------|--------|
| **KEEP** | 28 | See above |
| **DUPLICATE (archive)** | 10 pairs | comments, follows, streaks, daily_stats, user_stats, quest_progress, user_quest_progress, trainers, trainer_profiles, quests_master |
| **UNUSED (archive)** | 22 | ai_plans, centers, client_trainer_links, competition_participants, competitions, conversation_members, favorites_foods, foods, foods_catalog, goals, meal_days, meal_photos, meals, meal_items, meal_media, meals_logs, reward_events, trainer_meal_sharing, trainer_notes, trainer_verifications, trainers |
| **DO NOT TOUCH** | 1 | spatial_ref_sys (PostGIS) |

---

## 5. Recommended Archive Order

Archive in dependency order (children before parents):

**Phase 1 – No dependencies:**
- ai_plans, centers, client_trainer_links, comments, competition_participants, competitions, conversation_members, daily_stats, favorites_foods, follows, foods, foods_catalog, goals, reward_events, streaks, trainer_meal_sharing, trainer_notes, trainer_profiles, trainer_verifications, trainers, user_stats, quests_master

**Phase 2 – Depend on Phase 1:**
- meal_photos, meals_logs, meal_days (if no FKs to keep)
- meal_items, meal_media, meals
- quest_progress, user_quest_progress (if no FKs to quests)

**Phase 3 – Check FKs:**
- user_achievements.achievement_id → achievements. Ensure achievements.id type matches (your schema shows achievements.id as uuid; complete_quest_system uses TEXT for achievement ids – verify).

---

## 6. SQL to Archive (Safe – Move to archive schema)

```sql
-- Create archive schema
CREATE SCHEMA IF NOT EXISTS archive;

-- Phase 1: Tables with no incoming FKs (run in transaction)
BEGIN;
-- Drop RLS policies first
ALTER TABLE public.ai_plans DISABLE ROW LEVEL SECURITY;
-- ... (repeat for each table)

-- Move to archive
ALTER TABLE public.comments SET SCHEMA archive;
ALTER TABLE public.follows SET SCHEMA archive;
ALTER TABLE public.streaks SET SCHEMA archive;
ALTER TABLE public.daily_stats SET SCHEMA archive;
ALTER TABLE public.user_stats SET SCHEMA archive;
ALTER TABLE public.quests_master SET SCHEMA archive;
ALTER TABLE public.ai_plans SET SCHEMA archive;
ALTER TABLE public.centers SET SCHEMA archive;
ALTER TABLE public.client_trainer_links SET SCHEMA archive;
ALTER TABLE public.competition_participants SET SCHEMA archive;
ALTER TABLE public.competitions SET SCHEMA archive;
ALTER TABLE public.conversation_members SET SCHEMA archive;
ALTER TABLE public.favorites_foods SET SCHEMA archive;
ALTER TABLE public.foods SET SCHEMA archive;
ALTER TABLE public.foods_catalog SET SCHEMA archive;
ALTER TABLE public.goals SET SCHEMA archive;
ALTER TABLE public.reward_events SET SCHEMA archive;
ALTER TABLE public.trainer_meal_sharing SET SCHEMA archive;
ALTER TABLE public.trainer_notes SET SCHEMA archive;
ALTER TABLE public.trainer_profiles SET SCHEMA archive;
ALTER TABLE public.trainer_verifications SET SCHEMA archive;
ALTER TABLE public.trainers SET SCHEMA archive;
COMMIT;
```

**Note:** FK constraints may block some moves. Run `ALTER TABLE ... DROP CONSTRAINT <fk_name>` before moving if needed. Check `pg_constraint` for dependent FKs.

---

## 7. Schema Mismatches to Watch

- **achievements**: Your schema has `id uuid`; migrations expect `id TEXT`. user_achievements.achievement_id → achievements(id). Verify type alignment.
- **quests**: Your schema has `id uuid`; migrations use `id TEXT` for quest definitions. user_quests.quest_definition_id is TEXT. Check compatibility.
