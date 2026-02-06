# Quest & Achievements System Implementation

## Overview
A comprehensive quest and achievements system has been implemented following the specifications provided. The system includes daily quests, weekly quests, challenges, achievements, leaderboards, and a proper XP/leveling system.

## What's Been Implemented

### 1. Data Models (`lib/models/quest_models.dart`)
- **QuestDefinition**: Base quest template with category, difficulty, time windows, cooldowns, and requirements
- **ActiveQuest**: User-assigned quest instance with progress tracking
- **ChallengeQuest**: Time-bounded competition quests (friends/local/global)
- **Achievement**: Non-repeatable milestone badges with progress tracking
- **LeaderboardEntry**: Leaderboard entries with points (separate from XP)

### 2. Quest Service (`lib/services/quest_service.dart`)
- **Quest Pool**: Predefined quest definitions for daily/weekly quests
- **Quest Selection Logic**: 
  - Avoids same category twice in a row
  - Respects cooldown periods
  - Scales difficulty based on user performance
  - 3 fixed + 2 rotating daily quests
  - Max 2 refills per day to prevent farming
- **Progress Calculation**: Tracks progress for steps, water, meals, workouts, etc.
- **Quest Claiming**: Awards XP and leaderboard points separately
- **Auto-refresh**: Daily quests refresh at midnight, weekly quests on Monday

### 3. Quest Providers (`lib/providers/quest_provider.dart`)
- Riverpod providers for:
  - Daily quests
  - Weekly quests
  - User XP
  - User level

### 4. Quest Page UI (`lib/pages/quest/quest_page.dart`)
- **5 Tabs**: Daily | Weekly | Challenges | Achievements | Leaderboard
- **Quest Cards**: Show progress, rewards, time left, and "Claim" button
- **Claim Button**: Only enabled when quest is complete (progress >= 100%)
- **Level System**: XP bar, level badge, and level progression
- **Challenges Tab**: Placeholder for future challenge implementation

## Quest Categories

1. **Steps**: Daily step goals (8K, 10K, morning steps)
2. **Hydration**: Water intake goals (2L, meet daily goal)
3. **Nutrition**: Meal logging, protein goals
4. **Workout**: Exercise completion
5. **Consistency**: Daily check-ins, streaks
6. **Social**: Friend interactions (optional, not forced)
7. **Recovery**: Sleep tracking (for future)

## Quest Types

### Daily Quests
- Refresh every day at midnight
- 3-6 quests shown at a time
- Some have time windows (e.g., "before 8 AM")
- Can be refilled up to 2 times per day after completion

### Weekly Quests
- Refresh every Monday
- 4-8 quests shown
- Focus on habit-forming (7-day consistency, totals)
- Bigger rewards (XP and points)

### Challenges
- Time-bounded competitions (3 days, weekend, 7 days)
- Scopes: Friends, Local (city), Global
- Optional participation
- Social features (not required for progression)

## Rewards System

### XP (Experience Points)
- Used for leveling up
- Earned from quests and streaks
- Levels unlock cosmetics and small perks

### Points (Leaderboard Points)
- **Separate from XP** (prevents farming)
- Used for leaderboard rankings
- Daily/weekly/monthly leaderboards
- Capped per day to prevent abuse

### Achievements
- Non-repeatable milestones
- Badge frames, titles, XP rewards
- Progress tracking with tiers

## Anti-Cheat Measures

1. **Daily cap on leaderboard points**
2. **Cooldown periods** for quest repetition
3. **Max 2 daily quest refills** per day
4. **Separate points from XP** (prevents infinite farming)
5. **Rate limiting** on quest claiming (to be implemented)

## Database Schema Required

The following Supabase tables need to be created:

### `user_quests`
```sql
CREATE TABLE user_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  quest_definition_id TEXT NOT NULL,
  type TEXT NOT NULL, -- 'daily', 'weekly', 'challenge'
  status TEXT NOT NULL, -- 'available', 'in_progress', 'completed', 'claimed', 'expired'
  assigned_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `user_quest_settings`
```sql
CREATE TABLE user_quest_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  last_daily_refresh TIMESTAMPTZ,
  last_weekly_refresh TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `user_quest_refills`
```sql
CREATE TABLE user_quest_refills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  refilled_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `user_profiles` (add columns)
```sql
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS total_xp INTEGER DEFAULT 0;
```

### `leaderboard_points`
```sql
CREATE TABLE leaderboard_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  date DATE, -- For daily leaderboard
  week_start DATE, -- For weekly leaderboard
  month_start DATE, -- For monthly leaderboard
  points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date),
  UNIQUE(user_id, week_start),
  UNIQUE(user_id, month_start)
);
```

### `user_achievements`
```sql
CREATE TABLE user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  achievement_id TEXT NOT NULL,
  current_progress DOUBLE PRECISION DEFAULT 0,
  target_progress DOUBLE PRECISION NOT NULL,
  is_unlocked BOOLEAN DEFAULT FALSE,
  unlocked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);
```

## Next Steps

1. **Create database tables** in Supabase (see schema above)
2. **Implement water intake tracking** (currently placeholder)
3. **Implement meal/nutrition tracking** (currently placeholder)
4. **Implement workout tracking** (currently placeholder)
5. **Add challenge system** (UI placeholder exists)
6. **Add achievements tracking** (models exist, service needed)
7. **Add leaderboard queries** (models exist, service methods needed)
8. **Add confetti animation** on quest claim
9. **Add haptic feedback** on quest claim
10. **Connect quest page to real data** (currently uses mock data)

## Current Status

✅ **Completed:**
- Quest models and data structures
- Quest service with selection logic
- Quest providers (Riverpod)
- Quest page UI with 5 tabs
- Claim button functionality (UI ready)
- Level system integration

🔄 **In Progress:**
- Connecting to real database
- Progress calculation for all metrics

⏳ **Pending:**
- Challenge system implementation
- Achievements service
- Leaderboard service
- Water/meal/workout tracking integration

## Notes

- The quest service currently uses placeholder values for water intake, meals, and workouts. These need to be connected to the actual health tracking services.
- The quest page currently uses mock data. It needs to be connected to the `QuestService` via providers.
- Social quests are optional and won't block progression.
- Leaderboard points are separate from XP to prevent farming and maintain fairness.
