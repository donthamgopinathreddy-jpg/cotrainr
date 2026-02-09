# Quest System Implementation Summary

## What Was Created

### 1. Database Migration (`supabase/migrations/20250127_complete_quest_system.sql`)

**Fixes Existing Tables:**
- `user_profiles`: Adds `total_xp` column (service expects this)
- `user_quests`: Adds `type`, `assigned_at`, `expires_at` columns
- `user_quest_settings`: Adds `last_daily_refresh`, `last_weekly_refresh` columns
- `user_quest_refills`: Adds `refilled_at` column

**Creates New Tables:**
- `quest_definitions`: Server-driven quest templates (daily/weekly/challenge)
- `achievements`: Achievement definitions (milestones, badges)
- `user_achievements`: User achievement progress tracking
- `challenges`: Group challenges (friends/local/global)
- `challenge_members`: Challenge participants
- `challenge_progress`: Individual progress in challenges

**Creates RPC Functions:**
- `allocate_daily_quests(user_id)`: Auto-allocates daily quests
- `allocate_weekly_quests(user_id)`: Auto-allocates weekly quests
- `refill_quests(user_id)`: Refills daily quest slot (max 2/day)
- `update_quest_progress(quest_instance_id, delta)`: Updates quest progress safely
- `claim_quest_rewards(quest_instance_id)`: Claims rewards transactionally
- `create_challenge(...)`: Creates a new challenge
- `join_challenge(challenge_id)`: Joins a challenge
- `update_challenge_progress(challenge_id, delta)`: Updates challenge progress
- `get_leaderboard(...)`: Gets leaderboard with cursor pagination

**Security:**
- All tables have RLS enabled
- RPC functions use `SECURITY DEFINER` with `SET search_path = public`
- Proper policies for authenticated users only

### 2. Flutter Repository (`lib/repositories/quest_repository.dart`)

**Methods Provided:**

**Daily Quests:**
- `getDailyQuests()`: Gets active daily quests (auto-allocates if needed)
- `refillQuests()`: Refills a daily quest slot

**Weekly Quests:**
- `getWeeklyQuests()`: Gets active weekly quests (auto-allocates if needed)

**Quest Operations:**
- `updateQuestProgress(questInstanceId, delta)`: Updates quest progress
- `claimQuestRewards(questInstanceId)`: Claims quest rewards

**Challenges:**
- `getActiveChallenges()`: Gets challenges user has joined
- `getChallengeDetail(challengeId)`: Gets challenge details with leaderboard
- `createChallenge(...)`: Creates a new challenge
- `joinChallenge(challengeId)`: Joins a challenge
- `updateChallengeProgress(challengeId, delta)`: Updates challenge progress

**Achievements:**
- `getAchievements()`: Gets all achievements with user progress

**Leaderboard:**
- `getLeaderboard(...)`: Gets leaderboard with cursor-based pagination

### 3. Documentation

- `QUEST_SYSTEM_SETUP.md`: Complete setup guide with step-by-step instructions
- `supabase/migrations/20250127_inspect_quest_schema.sql`: SQL queries to inspect current schema

## Key Features

### Server-Driven Quest System
- Quest definitions stored in database (not hardcoded in Flutter)
- Easy to add/modify quests without app updates
- Supports daily, weekly, and challenge quest types

### Automatic Quest Allocation
- Daily quests auto-allocated at first access each day
- Weekly quests auto-allocated at first access each week
- Respects cooldown periods to prevent repetition

### Challenge System
- Group challenges with friends, local, or global scope
- Real-time progress tracking
- Leaderboard within challenges

### Achievement System
- Milestone-based achievements
- Progress tracking per user
- Unlock notifications (to be implemented)

### Leaderboard
- Daily, weekly, monthly periods
- Cursor-based pagination for performance
- Shows rank, points, XP, and level

### Security
- All operations protected by RLS
- Server-side validation in RPC functions
- Users can only access their own quest data
- Leaderboard is public (any authenticated user can view)

## Next Steps

1. **Run the migration** in Supabase SQL Editor
2. **Update your QuestPage** to use `QuestRepository` instead of `QuestService`
3. **Create Riverpod providers** (see `QUEST_SYSTEM_SETUP.md`)
4. **Connect progress tracking** to your health tracking service
5. **Add notifications** for quest completions and challenge updates

## Important Notes

- The migration is **idempotent** - safe to run multiple times
- Quest definitions are **seeded** with 14 default quests
- All RPC functions use **transactional operations** for data consistency
- **Cursor pagination** is used for leaderboard to handle large datasets efficiently

## Testing Checklist

- [ ] Run inspection queries to verify current schema
- [ ] Apply migration successfully
- [ ] Verify new tables exist
- [ ] Verify RPC functions exist
- [ ] Test daily quest allocation
- [ ] Test weekly quest allocation
- [ ] Test quest progress updates
- [ ] Test quest reward claiming
- [ ] Test challenge creation
- [ ] Test challenge joining
- [ ] Test challenge progress updates
- [ ] Test leaderboard queries
- [ ] Test achievement retrieval

## Support

If you encounter issues:
1. Check `QUEST_SYSTEM_SETUP.md` troubleshooting section
2. Verify RLS policies are correctly set
3. Check Supabase logs for RPC function errors
4. Ensure user is authenticated before calling repository methods
