import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/quest_repository.dart';
import '../repositories/metrics_repository.dart';

/// Service to automatically sync user metrics with quest progress
class QuestProgressSyncService {
  final QuestRepository _questRepo;
  final MetricsRepository _metricsRepo;
  final SupabaseClient _supabase;
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  QuestProgressSyncService({
    QuestRepository? questRepo,
    MetricsRepository? metricsRepo,
    SupabaseClient? supabase,
  })  : _questRepo = questRepo ?? QuestRepository(),
        _metricsRepo = metricsRepo ?? MetricsRepository(),
        _supabase = supabase ?? Supabase.instance.client;

  /// Start automatic syncing (every 30 seconds)
  void startAutoSync() {
    if (_syncTimer != null) return;
    
    // Initial sync
    syncMetricsToQuests();
    
    // Periodic sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncMetricsToQuests();
    });
  }

  /// Stop automatic syncing
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Sync current metrics to all active quests
  Future<void> syncMetricsToQuests() async {
    if (_isSyncing) return;
    
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isSyncing = true;
    
    try {
      // Get today's metrics from Supabase
      final metrics = await _metricsRepo.getTodayMetrics();
      if (metrics == null) {
        print('QuestProgressSync: No metrics found for today, skipping quest sync');
        _isSyncing = false;
        return;
      }

      final steps = (metrics['steps'] as num?)?.toInt() ?? 0;
      final calories = (metrics['calories_burned'] as num?)?.toDouble() ?? 0.0;
      final distance = (metrics['distance_km'] as num?)?.toDouble() ?? 0.0;
      final water = (metrics['water_intake_liters'] as num?)?.toDouble() ?? 0.0;

      print('QuestProgressSync: Syncing quests with metrics - Steps: $steps, Calories: $calories, Distance: $distance km, Water: $water L');

      // Get all active daily and weekly quests
      final dailyQuests = await _questRepo.getDailyQuests();
      final weeklyQuests = await _questRepo.getWeeklyQuests();

      // Sync each quest based on its category
      for (final quest in [...dailyQuests, ...weeklyQuests]) {
        if (quest.status.name == 'completed' || quest.status.name == 'claimed') {
          continue; // Skip completed/claimed quests
        }

        double progressDelta = 0.0;
        bool shouldUpdate = false;

        // Determine progress based on quest category
        switch (quest.category.name) {
          case 'steps':
            // Update progress based on steps
            final targetSteps = (quest.requirements['target'] as num?)?.toDouble() ?? quest.maxProgress;
            final newProgress = steps.toDouble().clamp(0.0, targetSteps);
            progressDelta = newProgress - quest.progress;
            shouldUpdate = progressDelta > 0;
            break;

          case 'workout':
            // Update based on calories or distance
            if (quest.requirements['type'] == 'calories') {
              final targetCalories = (quest.requirements['target'] as num?)?.toDouble() ?? quest.maxProgress;
              final newProgress = calories.clamp(0.0, targetCalories);
              progressDelta = newProgress - quest.progress;
              shouldUpdate = progressDelta > 0;
            } else if (quest.requirements['type'] == 'distance') {
              final targetDistance = (quest.requirements['target'] as num?)?.toDouble() ?? quest.maxProgress;
              final newProgress = distance.clamp(0.0, targetDistance);
              progressDelta = newProgress - quest.progress;
              shouldUpdate = progressDelta > 0;
            }
            break;

          case 'hydration':
            // Update based on water intake
            final targetWater = (quest.requirements['target'] as num?)?.toDouble() ?? quest.maxProgress;
            final newProgress = water.clamp(0.0, targetWater);
            progressDelta = newProgress - quest.progress;
            shouldUpdate = progressDelta > 0;
            break;

          case 'consistency':
            // Consistency quests are handled separately (streak-based)
            // Skip for now
            break;

          default:
            break;
        }

        // Update quest progress if needed
        if (shouldUpdate && progressDelta > 0) {
          try {
            await _questRepo.updateQuestProgress(quest.id, progressDelta);
            print('QuestProgressSync: Updated quest ${quest.id} by $progressDelta');
          } catch (e) {
            print('QuestProgressSync: Error updating quest ${quest.id}: $e');
          }
        }
      }
    } catch (e) {
      print('QuestProgressSync: Error syncing metrics to quests: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Manually trigger a sync (useful after updating metrics)
  Future<void> triggerSync() async {
    await syncMetricsToQuests();
  }

  /// Sync metrics when steps are updated
  Future<void> onStepsUpdated(int newSteps) async {
    // Update metrics first
    await _metricsRepo.updateTodayMetrics(steps: newSteps);
    // Then sync to quests
    await syncMetricsToQuests();
  }

  /// Sync metrics when water is updated
  Future<void> onWaterUpdated(double newWater) async {
    await _metricsRepo.updateTodayMetrics(waterIntakeLiters: newWater);
    await syncMetricsToQuests();
  }

  /// Sync metrics when calories/distance are updated
  Future<void> onWorkoutUpdated({
    double? calories,
    double? distance,
  }) async {
    await _metricsRepo.updateTodayMetrics(
      caloriesBurned: calories,
      distanceKm: distance,
    );
    await syncMetricsToQuests();
  }
}
