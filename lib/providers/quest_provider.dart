import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quest_models.dart';
import '../services/quest_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for QuestService
final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService();
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Provider for daily quests
final dailyQuestsProvider = FutureProvider<List<ActiveQuest>>((ref) async {
  final service = ref.watch(questServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) return [];
  
  try {
    return await service.getDailyQuests(userId);
  } catch (e) {
    print('Error loading daily quests: $e');
    return [];
  }
});

/// Provider for weekly quests
final weeklyQuestsProvider = FutureProvider<List<ActiveQuest>>((ref) async {
  final service = ref.watch(questServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) return [];
  
  try {
    return await service.getWeeklyQuests(userId);
  } catch (e) {
    print('Error loading weekly quests: $e');
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
        .single();
    
    return (response['total_xp'] as int?) ?? 0;
  } catch (e) {
    return 0;
  }
});

/// Provider for user level
final userLevelProvider = Provider<int>((ref) {
  final xp = ref.watch(userXPProvider).value ?? 0;
  // Calculate level from XP (simplified: 100 XP per level)
  return (xp / 100).floor() + 1;
});
