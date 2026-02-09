# Quest System Setup Guide

This guide walks you through setting up the complete quest/challenge/achievement/leaderboard system for Cotrainr.

## Prerequisites

- Supabase project with existing tables: `profiles`, `user_profiles`, `user_quests`, `user_quest_settings`, `user_quest_refills`, `leaderboard_points`, `notifications`
- Flutter app with `supabase_flutter` package
- Riverpod for state management

## Step 1: Inspect Current Schema

Before applying migrations, inspect your current database schema:

1. Open Supabase SQL Editor
2. Run the inspection queries from `supabase/migrations/20250127_inspect_quest_schema.sql`
3. Review the output to understand your current table structures, indexes, triggers, and RLS policies
4. Save the output for reference

**Key things to check:**
- Does `user_profiles` have `total_xp` column? (service expects this, not just `xp`)
- Does `user_quests` have `type`, `assigned_at`, `expires_at` columns?
- Does `user_quest_settings` have `last_daily_refresh`, `last_weekly_refresh`?
- Does `user_quest_refills` have `refilled_at` column?

## Step 2: Apply Migration

1. Open Supabase SQL Editor
2. Copy and paste the entire contents of `supabase/migrations/20250127_complete_quest_system.sql`
3. Run the migration
4. Verify no errors occurred

**What the migration does:**
- Fixes existing table schemas to match service expectations
- Creates new tables: `quest_definitions`, `achievements`, `user_achievements`, `challenges`, `challenge_members`, `challenge_progress`
- Creates indexes for performance
- Sets up triggers for `updated_at` timestamps
- Enables RLS and creates security policies
- Creates RPC functions for quest operations
- Seeds initial quest definitions

## Step 3: Verify Migration Success

Run these queries to verify:

```sql
-- Check new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'quest_definitions',
    'achievements',
    'user_achievements',
    'challenges',
    'challenge_members',
    'challenge_progress'
  );

-- Check RPC functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN (
    'allocate_daily_quests',
    'allocate_weekly_quests',
    'refill_quests',
    'update_quest_progress',
    'claim_quest_rewards',
    'create_challenge',
    'join_challenge',
    'update_challenge_progress',
    'get_leaderboard'
  );

-- Check quest definitions were seeded
SELECT COUNT(*) FROM public.quest_definitions;
-- Should return 14 (number of seeded quests)
```

## Step 4: Update Flutter Code

### 4.1 Add QuestRepository

The `QuestRepository` class is already created at `lib/repositories/quest_repository.dart`. It provides methods for:

- **Daily Quests**: `getDailyQuests()`, `refillQuests()`
- **Weekly Quests**: `getWeeklyQuests()`
- **Quest Progress**: `updateQuestProgress()`, `claimQuestRewards()`
- **Challenges**: `getActiveChallenges()`, `createChallenge()`, `joinChallenge()`, `updateChallengeProgress()`
- **Achievements**: `getAchievements()`
- **Leaderboard**: `getLeaderboard()` with cursor pagination

### 4.2 Create Riverpod Provider

Create `lib/providers/quest_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/quest_repository.dart';
import '../models/quest_models.dart';

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return QuestRepository();
});

final dailyQuestsProvider = FutureProvider<List<ActiveQuest>>((ref) async {
  final repo = ref.read(questRepositoryProvider);
  return await repo.getDailyQuests();
});

final weeklyQuestsProvider = FutureProvider<List<ActiveQuest>>((ref) async {
  final repo = ref.read(questRepositoryProvider);
  return await repo.getWeeklyQuests();
});

final activeChallengesProvider = FutureProvider<List<ChallengeQuest>>((ref) async {
  final repo = ref.read(questRepositoryProvider);
  return await repo.getActiveChallenges();
});

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final repo = ref.read(questRepositoryProvider);
  return await repo.getAchievements();
});

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, Map<String, dynamic>>((ref, params) async {
  final repo = ref.read(questRepositoryProvider);
  return await repo.getLeaderboard(
    periodType: params['periodType'] as String,
    periodStart: params['periodStart'] as DateTime,
    limit: params['limit'] as int? ?? 50,
    cursorPoints: params['cursorPoints'] as int?,
    cursorUserId: params['cursorUserId'] as String?,
  );
});
```

### 4.3 Update QuestPage

Update your `lib/pages/quest/quest_page.dart` to use the new repository:

```dart
// Replace QuestService with QuestRepository
final questRepo = ref.read(questRepositoryProvider);

// Use providers for data
final dailyQuests = ref.watch(dailyQuestsProvider);
final weeklyQuests = ref.watch(weeklyQuestsProvider);
final challenges = ref.watch(activeChallengesProvider);
final achievements = ref.watch(achievementsProvider);
```

## Step 5: Test the System

### 5.1 Test Daily Quests

```dart
// In your Flutter app
final repo = QuestRepository();

// Get daily quests (auto-allocates if needed)
final dailyQuests = await repo.getDailyQuests();
print('Daily quests: ${dailyQuests.length}');

// Update progress
await repo.updateQuestProgress(dailyQuests.first.id, 1000.0);

// Claim rewards
final result = await repo.claimQuestRewards(dailyQuests.first.id);
print('Awarded XP: ${result['xp_awarded']}');
```

### 5.2 Test Weekly Quests

```dart
final weeklyQuests = await repo.getWeeklyQuests();
print('Weekly quests: ${weeklyQuests.length}');
```

### 5.3 Test Challenges

```dart
// Create a challenge
final challengeId = await repo.createChallenge(
  title: '7-Day Steps Challenge',
  description: 'Walk 10,000 steps daily for 7 days',
  challengeType: 'steps',
  scope: 'friends',
  goalValue: 70000,
  goalUnit: 'steps',
  startDate: DateTime.now(),
  endDate: DateTime.now().add(Duration(days: 7)),
  rewardXP: 500,
  rewardPoints: 100,
);

// Join challenge
await repo.joinChallenge(challengeId);

// Update progress
await repo.updateChallengeProgress(challengeId, 5000.0);
```

### 5.4 Test Leaderboard

```dart
// Get daily leaderboard
final leaderboard = await repo.getLeaderboard(
  periodType: 'daily',
  periodStart: DateTime.now(),
  limit: 50,
);

// Cursor-based pagination
final nextPage = await repo.getLeaderboard(
  periodType: 'daily',
  periodStart: DateTime.now(),
  limit: 50,
  cursorPoints: leaderboard.last.points,
  cursorUserId: leaderboard.last.userId,
);
```

### 5.5 Test Achievements

```dart
final achievements = await repo.getAchievements();
print('Total achievements: ${achievements.length}');
print('Unlocked: ${achievements.where((a) => a.isUnlocked).length}');
```

## Step 6: Storage Setup (Optional)

If you want to add images for achievements/challenges:

1. Create Supabase Storage bucket: `achievements` and `challenges`
2. Set RLS policies:

```sql
-- Allow authenticated users to read
CREATE POLICY "Anyone can view achievement images"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'achievements');

CREATE POLICY "Anyone can view challenge images"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'challenges');
```

## Step 7: Expected JSON Shapes

### Daily/Weekly Quest Response

```json
{
  "id": "uuid",
  "quest_definition_id": "daily_steps_8k",
  "type": "daily",
  "title": "Steps Sprint",
  "description": "Hit 8,000 steps today",
  "category": "steps",
  "progress": 5000.0,
  "maxProgress": 8000.0,
  "rewardXP": 50,
  "rewardPoints": 10,
  "status": "in_progress",
  "assignedAt": "2025-01-27T00:00:00Z",
  "expiresAt": "2025-01-28T00:00:00Z",
  "timeLeft": "12h 30m",
  "canClaim": false,
  "requirements": {"target": 8000, "type": "steps"}
}
```

### Challenge Response

```json
{
  "id": "uuid",
  "title": "7-Day Steps Challenge",
  "description": "Walk 10,000 steps daily",
  "challenge_type": "steps",
  "scope": "friends",
  "goal_value": 70000,
  "goal_unit": "steps",
  "start_date": "2025-01-27T00:00:00Z",
  "end_date": "2025-02-03T00:00:00Z",
  "reward_xp": 500,
  "reward_points": 100,
  "participants": 5,
  "current_progress": 15000.0
}
```

### Leaderboard Entry

```json
{
  "user_id": "uuid",
  "username": "john_doe",
  "avatar_url": "https://...",
  "rank": 1,
  "points": 1320,
  "total_xp": 5000,
  "level": 5
}
```

## Troubleshooting

### Issue: "Quest not found or not accessible"

**Solution**: Ensure RLS policies are correctly set. The user must own the quest (`user_id = auth.uid()`).

### Issue: "Daily refill limit reached"

**Solution**: Users can only refill 2 quests per day. Check `user_quest_refills` table.

### Issue: Quest progress not updating

**Solution**: 
1. Verify `update_quest_progress` RPC function exists
2. Check quest status is 'available' or 'in_progress'
3. Ensure user owns the quest

### Issue: Leaderboard shows wrong data

**Solution**:
1. Verify `period_type` and `period_start` match your data
2. Check `leaderboard_points` table has correct `period_type` values
3. Ensure cursor pagination uses correct `(points, user_id)` ordering

## Next Steps

1. **Customize Quest Definitions**: Add more quests in `quest_definitions` table
2. **Add Achievements**: Create achievement definitions in `achievements` table
3. **Implement Progress Tracking**: Connect quest progress to your health tracking service
4. **Add Notifications**: Notify users when quests are completed or challenges start
5. **Add Analytics**: Track quest completion rates, popular challenges, etc.

## Security Notes

- All RPC functions use `SECURITY DEFINER` with `SET search_path = public` to prevent SQL injection
- RLS policies ensure users can only access their own quest data
- Leaderboard is public (any authenticated user can view)
- Challenge progress updates are validated server-side

## Performance Notes

- Indexes are created on frequently queried columns
- Cursor-based pagination is used for leaderboard to handle large datasets
- Quest allocation uses random selection to ensure variety
- Cooldown system prevents quest repetition
