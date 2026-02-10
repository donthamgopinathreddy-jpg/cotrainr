import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quest_models.dart';
import '../repositories/quest_repository.dart';
import '../services/quest_progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for QuestRepository
final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return QuestRepository();
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Provider for daily quests
final dailyQuestsProvider = FutureProvider<List<ActiveQuest>>((ref) async {
  final repo = ref.watch(questRepositoryProvider);
  
  try {
    return await repo.getDailyQuests();
  } catch (e) {
    print('Error loading daily quests: $e');
    return [];
  }
});

/// Provider for weekly quests
final weeklyQuestsProvider = FutureProvider<List<ActiveQuest>>((ref) async {
  final repo = ref.watch(questRepositoryProvider);
  
  try {
    return await repo.getWeeklyQuests();
  } catch (e) {
    print('Error loading weekly quests: $e');
    return [];
  }
});

/// Provider for active challenges
final activeChallengesProvider = FutureProvider<List<ChallengeQuest>>((ref) async {
  final repo = ref.watch(questRepositoryProvider);
  
  try {
    return await repo.getActiveChallenges();
  } catch (e) {
    print('Error loading challenges: $e');
    return [];
  }
});

/// Provider for achievements
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final repo = ref.watch(questRepositoryProvider);
  
  try {
    return await repo.getAchievements();
  } catch (e) {
    print('Error loading achievements: $e');
    return [];
  }
});

/// Provider for leaderboard (daily)
final dailyLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final repo = ref.watch(questRepositoryProvider);
  final now = DateTime.now();
  
  try {
    return await repo.getLeaderboard(
      periodType: 'daily',
      periodStart: now,
      limit: 50,
    );
  } catch (e) {
    print('Error loading leaderboard: $e');
    return [];
  }
});

/// Provider for user XP
final userXPProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  
  try {
    final response = await Supabase.instance.client
        .from('user_profiles')
        .select('total_xp')
        .eq('user_id', userId)
        .maybeSingle();
    
    return (response?['total_xp'] as int?) ?? 0;
  } catch (e) {
    return 0;
  }
});

/// Provider for user level
final userLevelProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 1;
  
  try {
    final response = await Supabase.instance.client
        .from('user_profiles')
        .select('level')
        .eq('user_id', userId)
        .maybeSingle();
    
    return (response?['level'] as int?) ?? 1;
  } catch (e) {
    return 1;
  }
});

/// Provider for XP needed for next level
final xpForNextLevelProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final levelAsync = ref.watch(userLevelProvider);
  final xpAsync = ref.watch(userXPProvider);
  
  if (userId == null) return 100;
  
  final level = levelAsync.value ?? 1;
  final totalXP = xpAsync.value ?? 0;
  
  try {
    final response = await Supabase.instance.client.rpc(
      'get_xp_for_next_level',
      params: {
        'p_current_level': level,
        'p_total_xp': totalXP,
      },
    );
    
    return (response as int?) ?? 100;
  } catch (e) {
    // Fallback calculation
    return (100 * (1.15 * (level - 1))).round();
  }
});

/// Provider for quest progress sync service
final questProgressSyncServiceProvider = Provider<QuestProgressSyncService>((ref) {
  return QuestProgressSyncService();
});
