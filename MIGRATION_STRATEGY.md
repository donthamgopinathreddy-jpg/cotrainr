# Migration Strategy for Existing Database

## Overview
This migration adds the missing tables and columns needed for the core loop (Discover → Request → Accept → Chat) **without breaking your existing database structure**.

## What This Migration Does

### ✅ Safe Changes (No Breaking Changes)
1. **Adds missing tables:**
   - `providers` (trainer/nutritionist profiles)
   - `provider_locations` (service locations with privacy)
   - `weekly_usage` (quota tracking)
   - `leads` (client requests)
   - `conversations` (chat conversations)
   - `messages` (chat messages)

2. **Fixes subscriptions table:**
   - Adds `plan` column (ENUM) if missing
   - Syncs data from `plan_type` if it exists
   - Keeps `plan_type` intact (no deletion)

3. **Adds enums, indexes, triggers, RLS policies** for new tables only

4. **Adds RPC function:**
   - `nearby_providers()` for spatial search

### ❌ What This Migration Does NOT Do
- Does NOT modify existing `profiles` table structure
- Does NOT delete any existing columns
- Does NOT modify existing tables (except adding `plan` to subscriptions)
- Does NOT break existing functionality

## Migration Order

Run these migrations in order:

1. **`20250127_add_missing_tables_safe.sql`** (this file)
   - Creates missing tables
   - Adds `plan` column to subscriptions
   - Sets up RLS, triggers, indexes

2. **`20250127_fix_quota_race_conditions.sql`** (already exists)
   - Adds `create_lead_tx()` RPC
   - Adds `update_lead_status_tx()` RPC
   - Adds unique constraints

## Compatibility Notes

### Profiles Table
- Your existing `profiles` table has: `role TEXT` with CHECK constraint
- Our code expects: `profiles.role` to exist (✅ it does)
- The trigger `enforce_provider_role()` works with TEXT role (not ENUM)
- **No changes needed** - your structure is compatible

### Subscriptions Table
- Your existing table has: `plan_type TEXT`
- Migration adds: `plan ENUM` (for RPC compatibility)
- Both columns can coexist
- Migration syncs data: `plan_type` → `plan` on first run
- **Recommendation:** Update your app to use `plan` column going forward

### Existing Tables Not Touched
- `achievements`, `ai_plans`, `centers`, `client_trainer_links`
- `comments`, `competitions`, `daily_stats`, `foods`, `foods_catalog`
- `goals`, `meal_days`, `meal_items`, `meal_photos`, `meals`, `meals_logs`
- `notifications`, `posts`, `post_comments`, `post_likes`
- `profiles` (structure preserved)
- `quest_progress`, `quests`, `quests_master`
- `reward_events`, `streaks`, `subscriptions` (only adds `plan` column)
- `trainer_meal_sharing`, `trainer_notes`, `trainer_profiles`, `trainer_verifications`
- `trainers`, `user_achievements`, `user_quest_progress`, `user_stats`

## Testing Checklist

After running the migration:

1. ✅ Verify new tables exist:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name IN ('providers', 'provider_locations', 'weekly_usage', 'leads', 'conversations', 'messages');
   ```

2. ✅ Verify subscriptions has `plan` column:
   ```sql
   SELECT column_name, data_type FROM information_schema.columns 
   WHERE table_name = 'subscriptions' AND column_name = 'plan';
   ```

3. ✅ Test RPC function:
   ```sql
   SELECT * FROM nearby_providers(17.3850, 78.4867, 50.0);
   ```

4. ✅ Verify RLS policies:
   - Try inserting into `leads` directly (should fail - no insert policy)
   - Try reading own `weekly_usage` (should work)
   - Try reading someone else's `weekly_usage` (should fail)

5. ✅ Verify existing functionality still works:
   - Existing queries on `profiles`, `subscriptions`, etc. should work
   - No breaking changes to existing tables

## Next Steps

1. Run `20250127_add_missing_tables_safe.sql` in Supabase SQL Editor
2. Run `20250127_fix_quota_race_conditions.sql` (if not already run)
3. Deploy Edge Functions (`create-lead`, `update-lead-status`, `get-entitlements`)
4. Test the core loop: Discover → Request → Accept → Chat

## Rollback Plan

If something goes wrong:

1. **New tables can be dropped** (they're isolated):
   ```sql
   DROP TABLE IF EXISTS public.messages CASCADE;
   DROP TABLE IF EXISTS public.conversations CASCADE;
   DROP TABLE IF EXISTS public.leads CASCADE;
   DROP TABLE IF EXISTS public.weekly_usage CASCADE;
   DROP TABLE IF EXISTS public.provider_locations CASCADE;
   DROP TABLE IF EXISTS public.providers CASCADE;
   ```

2. **Subscriptions `plan` column can be dropped** (if you want to revert):
   ```sql
   ALTER TABLE public.subscriptions DROP COLUMN IF EXISTS plan;
   ```

3. **Existing tables are untouched** - no rollback needed for them
