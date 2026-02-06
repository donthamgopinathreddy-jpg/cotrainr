import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quest_models.dart';
import 'health_tracking_service.dart';
import 'user_goals_service.dart';

/// Service for managing quests, achievements, and leaderboards
class QuestService {
  final SupabaseClient _supabase;
  final HealthTrackingService _healthService;
  final UserGoalsService _goalsService;

  QuestService({
    SupabaseClient? supabase,
    HealthTrackingService? healthService,
    UserGoalsService? goalsService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _healthService = healthService ?? HealthTrackingService(),
        _goalsService = goalsService ?? UserGoalsService();

  // Quest Pool - All available quest definitions
  static final List<QuestDefinition> _questPool = [
    // Daily Quests - Steps
    QuestDefinition(
      id: 'daily_steps_8k',
      title: 'Steps Sprint',
      description: 'Hit 8,000 steps today',
      category: QuestCategory.steps,
      difficulty: QuestDifficulty.easy,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 50,
      rewardPoints: 10,
      requirements: {'steps': 8000},
      icon: Icons.directions_walk_rounded,
      iconColor: Colors.orange,
    ),
    QuestDefinition(
      id: 'daily_steps_10k',
      title: '10K Steps',
      description: 'Hit 10,000 steps today',
      category: QuestCategory.steps,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 75,
      rewardPoints: 15,
      requirements: {'steps': 10000},
      icon: Icons.directions_walk_rounded,
      iconColor: Colors.orange,
    ),
    QuestDefinition(
      id: 'daily_steps_morning',
      title: 'Early Bird Steps',
      description: 'Hit 2,000 steps before 8:00 AM',
      category: QuestCategory.steps,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.morning,
      rewardXP: 60,
      rewardPoints: 12,
      requirements: {'steps': 2000, 'before': '08:00'},
      icon: Icons.wb_twilight_rounded,
      iconColor: Colors.amber,
    ),
    // Daily Quests - Hydration
    QuestDefinition(
      id: 'daily_water_2l',
      title: 'Hydration Boost',
      description: 'Drink 2.0L water today',
      category: QuestCategory.hydration,
      difficulty: QuestDifficulty.easy,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 40,
      rewardPoints: 8,
      requirements: {'water': 2.0},
      icon: Icons.water_drop_rounded,
      iconColor: Colors.blue,
    ),
    QuestDefinition(
      id: 'daily_water_goal',
      title: 'Meet Water Goal',
      description: 'Hit your daily water goal',
      category: QuestCategory.hydration,
      difficulty: QuestDifficulty.easy,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 50,
      rewardPoints: 10,
      requirements: {'water_goal': true},
      icon: Icons.water_drop_rounded,
      iconColor: Colors.blue,
    ),
    // Daily Quests - Nutrition
    QuestDefinition(
      id: 'daily_meals_2',
      title: 'Log Meals',
      description: 'Log 2 meals today',
      category: QuestCategory.nutrition,
      difficulty: QuestDifficulty.easy,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 40,
      rewardPoints: 8,
      requirements: {'meals': 2},
      icon: Icons.restaurant_rounded,
      iconColor: Colors.green,
    ),
    QuestDefinition(
      id: 'daily_protein_80g',
      title: 'Protein Power',
      description: 'Hit 80g protein today',
      category: QuestCategory.nutrition,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 60,
      rewardPoints: 12,
      requirements: {'protein': 80},
      icon: Icons.fitness_center_rounded,
      iconColor: Colors.red,
    ),
    // Daily Quests - Consistency
    QuestDefinition(
      id: 'daily_open_app',
      title: 'Daily Check-in',
      description: 'Open Cotrainr and log 1 metric',
      category: QuestCategory.consistency,
      difficulty: QuestDifficulty.easy,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 20,
      rewardPoints: 5,
      requirements: {'log_metric': true},
      icon: Icons.check_circle_rounded,
      iconColor: Colors.purple,
    ),
    // Daily Quests - Workout
    QuestDefinition(
      id: 'daily_workout_15min',
      title: 'Quick Workout',
      description: 'Complete 15 min workout today',
      category: QuestCategory.workout,
      difficulty: QuestDifficulty.easy,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 60,
      rewardPoints: 12,
      requirements: {'workout_minutes': 15},
      icon: Icons.fitness_center_rounded,
      iconColor: Colors.red,
    ),
    // Weekly Quests
    QuestDefinition(
      id: 'weekly_steps_50k',
      title: 'Steps Marathon',
      description: 'Total 50,000 steps this week',
      category: QuestCategory.steps,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 250,
      rewardPoints: 50,
      requirements: {'steps': 50000, 'period': 'week'},
      icon: Icons.directions_walk_rounded,
      iconColor: Colors.orange,
    ),
    QuestDefinition(
      id: 'weekly_meals_5days',
      title: 'Meal Consistency',
      description: 'Log meals 5 days this week',
      category: QuestCategory.nutrition,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 200,
      rewardPoints: 40,
      requirements: {'meals_days': 5, 'period': 'week'},
      icon: Icons.restaurant_rounded,
      iconColor: Colors.green,
    ),
    QuestDefinition(
      id: 'weekly_water_4days',
      title: 'Hydration Streak',
      description: 'Hit water goal 4 days this week',
      category: QuestCategory.hydration,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 180,
      rewardPoints: 35,
      requirements: {'water_goal_days': 4, 'period': 'week'},
      icon: Icons.water_drop_rounded,
      iconColor: Colors.blue,
    ),
    QuestDefinition(
      id: 'weekly_workouts_3',
      title: 'Workout Week',
      description: 'Complete 3 workouts this week',
      category: QuestCategory.workout,
      difficulty: QuestDifficulty.medium,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 220,
      rewardPoints: 45,
      requirements: {'workouts': 3, 'period': 'week'},
      icon: Icons.fitness_center_rounded,
      iconColor: Colors.red,
    ),
    QuestDefinition(
      id: 'weekly_streak_5days',
      title: '5-Day Streak',
      description: 'Maintain a 5-day streak',
      category: QuestCategory.consistency,
      difficulty: QuestDifficulty.hard,
      timeWindow: QuestTimeWindow.anytime,
      rewardXP: 300,
      rewardPoints: 60,
      requirements: {'streak_days': 5, 'period': 'week'},
      icon: Icons.local_fire_department_rounded,
      iconColor: Colors.orange,
    ),
  ];

  /// Get quest pool
  List<QuestDefinition> get questPool => _questPool;

  /// Get daily quests for user
  Future<List<ActiveQuest>> getDailyQuests(String userId) async {
    // Check if we need to refresh daily quests (new day)
    final lastRefresh = await _getLastDailyRefresh(userId);
    final now = DateTime.now();
    final shouldRefresh = lastRefresh == null ||
        !_isSameDay(lastRefresh, now);

    if (shouldRefresh) {
      await _refreshDailyQuests(userId);
    }

    // Get active daily quests from database
    final response = await _supabase
        .from('user_quests')
        .select()
        .eq('user_id', userId)
        .eq('type', 'daily')
        .eq('status', 'available')
        .or('status.eq.in_progress')
        .order('assigned_at');

    final quests = <ActiveQuest>[];
    for (final row in response) {
      final def = _questPool.firstWhere(
        (q) => q.id == row['quest_definition_id'],
        orElse: () => _questPool.first,
      );
      
      final progress = await _calculateQuestProgress(def, userId);
      final maxProgress = _getMaxProgress(def);
      final expiresAt = DateTime.parse(row['expires_at']);
      final canClaim = progress >= maxProgress && row['status'] != 'claimed';

      quests.add(ActiveQuest(
        id: row['id'],
        questDefinitionId: def.id,
        type: QuestType.daily,
        title: def.title,
        description: def.description,
        category: def.category,
        icon: def.icon,
        iconColor: def.iconColor,
        progress: progress,
        maxProgress: maxProgress,
        rewardXP: def.rewardXP,
        rewardPoints: def.rewardPoints,
        status: _parseQuestStatus(row['status']),
        assignedAt: DateTime.parse(row['assigned_at']),
        expiresAt: expiresAt,
        timeLeft: _formatTimeLeft(expiresAt),
        canClaim: canClaim,
        requirements: def.requirements,
      ));
    }

    return quests;
  }

  /// Get weekly quests for user
  Future<List<ActiveQuest>> getWeeklyQuests(String userId) async {
    // Check if we need to refresh weekly quests (new week)
    final lastRefresh = await _getLastWeeklyRefresh(userId);
    final now = DateTime.now();
    final shouldRefresh = lastRefresh == null ||
        !_isSameWeek(lastRefresh, now);

    if (shouldRefresh) {
      await _refreshWeeklyQuests(userId);
    }

    final response = await _supabase
        .from('user_quests')
        .select()
        .eq('user_id', userId)
        .eq('type', 'weekly')
        .eq('status', 'available')
        .or('status.eq.in_progress')
        .order('assigned_at');

    final quests = <ActiveQuest>[];
    for (final row in response) {
      final def = _questPool.firstWhere(
        (q) => q.id == row['quest_definition_id'],
        orElse: () => _questPool.first,
      );
      
      final progress = await _calculateQuestProgress(def, userId);
      final maxProgress = _getMaxProgress(def);
      final expiresAt = DateTime.parse(row['expires_at']);
      final canClaim = progress >= maxProgress && row['status'] != 'claimed';

      quests.add(ActiveQuest(
        id: row['id'],
        questDefinitionId: def.id,
        type: QuestType.weekly,
        title: def.title,
        description: def.description,
        category: def.category,
        icon: def.icon,
        iconColor: def.iconColor,
        progress: progress,
        maxProgress: maxProgress,
        rewardXP: def.rewardXP,
        rewardPoints: def.rewardPoints,
        status: _parseQuestStatus(row['status']),
        assignedAt: DateTime.parse(row['assigned_at']),
        expiresAt: expiresAt,
        timeLeft: _formatTimeLeft(expiresAt),
        canClaim: canClaim,
        requirements: def.requirements,
      ));
    }

    return quests;
  }

  /// Claim a quest
  Future<bool> claimQuest(String userId, String questId) async {
    try {
      // Get quest
      final questResponse = await _supabase
          .from('user_quests')
          .select()
          .eq('id', questId)
          .eq('user_id', userId)
          .single();

      if (questResponse['status'] == 'claimed') {
        return false; // Already claimed
      }

      final def = _questPool.firstWhere(
        (q) => q.id == questResponse['quest_definition_id'],
      );

      // Update quest status
      await _supabase
          .from('user_quests')
          .update({'status': 'claimed', 'claimed_at': DateTime.now().toIso8601String()})
          .eq('id', questId);

      // Award XP and points
      await _awardXP(userId, def.rewardXP);
      await _awardPoints(userId, def.rewardPoints);

      // Check for next quest (if daily and slot available)
      if (questResponse['type'] == 'daily') {
        await _maybeRefillDailySlot(userId, questId);
      }

      return true;
    } catch (e) {
      print('Error claiming quest: $e');
      return false;
    }
  }

  /// Calculate progress for a quest
  Future<double> _calculateQuestProgress(
    QuestDefinition def,
    String userId,
  ) async {
    final req = def.requirements;
    
    if (req.containsKey('steps')) {
      final target = req['steps'] as int;
      final current = await _healthService.getTodaySteps();
      return current.clamp(0, target).toDouble();
    }
    
    if (req.containsKey('water')) {
      final target = req['water'] as double;
      // TODO: Get current water intake from health tracking service
      // For now, return 0 as placeholder
      final current = 0.0; // await _healthService.getTodayWater();
      return current.clamp(0.0, target);
    }
    
    if (req.containsKey('water_goal')) {
      final goal = await _goalsService.getWaterGoal();
      // TODO: Get current water intake from health tracking service
      final current = 0.0; // await _healthService.getTodayWater();
      return current >= goal ? 1.0 : 0.0;
    }
    
    if (req.containsKey('meals')) {
      // TODO: Get meal count from nutrition service
      return 0.0;
    }
    
    if (req.containsKey('protein')) {
      // TODO: Get protein from nutrition service
      return 0.0;
    }
    
    if (req.containsKey('workout_minutes')) {
      // TODO: Get workout minutes
      return 0.0;
    }
    
    if (req.containsKey('log_metric')) {
      // TODO: Check if user logged any metric today
      return 0.0;
    }
    
    // Weekly quests
    if (req.containsKey('period') && req['period'] == 'week') {
      // TODO: Calculate weekly progress
      return 0.0;
    }
    
    return 0.0;
  }

  /// Get max progress for a quest
  double _getMaxProgress(QuestDefinition def) {
    final req = def.requirements;
    
    if (req.containsKey('steps')) {
      return (req['steps'] as int).toDouble();
    }
    
    if (req.containsKey('water')) {
      return req['water'] as double;
    }
    
    if (req.containsKey('water_goal')) {
      return 1.0;
    }
    
    if (req.containsKey('meals')) {
      return (req['meals'] as int).toDouble();
    }
    
    if (req.containsKey('protein')) {
      return (req['protein'] as int).toDouble();
    }
    
    if (req.containsKey('workout_minutes')) {
      return (req['workout_minutes'] as int).toDouble();
    }
    
    if (req.containsKey('log_metric')) {
      return 1.0;
    }
    
    // Weekly quests
    if (req.containsKey('period') && req['period'] == 'week') {
      if (req.containsKey('steps')) {
        return (req['steps'] as int).toDouble();
      }
      if (req.containsKey('meals_days')) {
        return (req['meals_days'] as int).toDouble();
      }
      if (req.containsKey('water_goal_days')) {
        return (req['water_goal_days'] as int).toDouble();
      }
      if (req.containsKey('workouts')) {
        return (req['workouts'] as int).toDouble();
      }
      if (req.containsKey('streak_days')) {
        return (req['streak_days'] as int).toDouble();
      }
    }
    
    return 1.0;
  }

  /// Refresh daily quests
  Future<void> _refreshDailyQuests(String userId) async {
    // Get user's completed quests in last 7 days (for cooldown)
    final completedResponse = await _supabase
        .from('user_quests')
        .select('quest_definition_id, claimed_at')
        .eq('user_id', userId)
        .eq('status', 'claimed')
        .gte('claimed_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String());

    final completedIds = completedResponse
        .map((r) => r['quest_definition_id'] as String)
        .toSet();

    // Get user's current daily quests
    final currentResponse = await _supabase
        .from('user_quests')
        .select('quest_definition_id')
        .eq('user_id', userId)
        .eq('type', 'daily');

    final currentIds = currentResponse
        .map((r) => r['quest_definition_id'] as String)
        .toSet();

    // Select 3 fixed + 2 rotating daily quests
    final dailyDefs = _questPool.where((q) => 
      q.category != QuestCategory.social && // No social in daily for now
      !completedIds.contains(q.id) || 
      DateTime.now().difference(DateTime.parse(
        completedResponse.firstWhere((r) => r['quest_definition_id'] == q.id)['claimed_at']
      )) >= Duration(days: q.cooldownDays)
    ).toList();

    // Shuffle and take 5
    dailyDefs.shuffle();
    final selected = dailyDefs.take(5).toList();

    // Assign to user
    final now = DateTime.now();
    final expiresAt = DateTime(now.year, now.month, now.day + 1);
    
    for (final def in selected) {
      if (!currentIds.contains(def.id)) {
        await _supabase.from('user_quests').insert({
          'user_id': userId,
          'quest_definition_id': def.id,
          'type': 'daily',
          'status': 'available',
          'assigned_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        });
      }
    }

    // Update last refresh
    await _supabase.from('user_quest_settings').upsert({
      'user_id': userId,
      'last_daily_refresh': now.toIso8601String(),
    });
  }

  /// Refresh weekly quests
  Future<void> _refreshWeeklyQuests(String userId) async {
    // Similar logic for weekly quests
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final weeklyDefs = _questPool.where((q) => 
      q.category != QuestCategory.social &&
      q.difficulty != QuestDifficulty.easy // Weekly quests are medium/hard
    ).toList();

    weeklyDefs.shuffle();
    final selected = weeklyDefs.take(4).toList();

    for (final def in selected) {
      await _supabase.from('user_quests').insert({
        'user_id': userId,
        'quest_definition_id': def.id,
        'type': 'weekly',
        'status': 'available',
        'assigned_at': now.toIso8601String(),
        'expires_at': weekEnd.toIso8601String(),
      });
    }

    await _supabase.from('user_quest_settings').upsert({
      'user_id': userId,
      'last_weekly_refresh': now.toIso8601String(),
    });
  }

  /// Maybe refill a daily quest slot after claiming
  Future<void> _maybeRefillDailySlot(String userId, String completedQuestId) async {
    // Check how many times we've refilled today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final refillsResponse = await _supabase
        .from('user_quest_refills')
        .select()
        .eq('user_id', userId)
        .gte('refilled_at', DateTime(today.year, today.month, today.day).toIso8601String())
        .lt('refilled_at', DateTime(today.year, today.month, today.day + 1).toIso8601String());

    if (refillsResponse.length >= 2) {
      return; // Max 2 refills per day
    }

    // Select a new quest (avoid same category, respect cooldown)
    final currentQuests = await _supabase
        .from('user_quests')
        .select('quest_definition_id, category')
        .eq('user_id', userId)
        .eq('type', 'daily');

    final currentCategories = currentQuests
        .map((q) => q['category'] as String)
        .toSet();

    final available = _questPool.where((q) =>
      q.category.toString() != currentCategories.firstOrNull &&
      !currentQuests.any((cq) => cq['quest_definition_id'] == q.id)
    ).toList();

    if (available.isEmpty) return;

    available.shuffle();
    final newDef = available.first;

    final expiresAt = DateTime(today.year, today.month, today.day + 1);
    await _supabase.from('user_quests').insert({
      'user_id': userId,
      'quest_definition_id': newDef.id,
      'type': 'daily',
      'status': 'available',
      'assigned_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    });

    await _supabase.from('user_quest_refills').insert({
      'user_id': userId,
      'refilled_at': now.toIso8601String(),
    });
  }

  /// Award XP to user
  Future<void> _awardXP(String userId, int xp) async {
    final response = await _supabase
        .from('user_profiles')
        .select('total_xp')
        .eq('user_id', userId)
        .single();

    final currentXP = (response['total_xp'] as int?) ?? 0;
    await _supabase
        .from('user_profiles')
        .update({'total_xp': currentXP + xp})
        .eq('user_id', userId);
  }

  /// Award leaderboard points to user
  Future<void> _awardPoints(String userId, int points) async {
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    // Daily points
    await _supabase.from('leaderboard_points').upsert({
      'user_id': userId,
      'date': today.toIso8601String().split('T')[0],
      'points': points,
    }, onConflict: 'user_id,date').select();

    // Weekly points
    await _supabase.from('leaderboard_points').upsert({
      'user_id': userId,
      'week_start': weekStart.toIso8601String().split('T')[0],
      'points': points,
    }, onConflict: 'user_id,week_start').select();
  }

  /// Get last daily refresh
  Future<DateTime?> _getLastDailyRefresh(String userId) async {
    try {
      final response = await _supabase
          .from('user_quest_settings')
          .select('last_daily_refresh')
          .eq('user_id', userId)
          .single();

      final dateStr = response['last_daily_refresh'] as String?;
      return dateStr != null ? DateTime.parse(dateStr) : null;
    } catch (e) {
      return null;
    }
  }

  /// Get last weekly refresh
  Future<DateTime?> _getLastWeeklyRefresh(String userId) async {
    try {
      final response = await _supabase
          .from('user_quest_settings')
          .select('last_weekly_refresh')
          .eq('user_id', userId)
          .single();

      final dateStr = response['last_weekly_refresh'] as String?;
      return dateStr != null ? DateTime.parse(dateStr) : null;
    } catch (e) {
      return null;
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Check if two dates are in the same week
  bool _isSameWeek(DateTime a, DateTime b) {
    final weekStartA = a.subtract(Duration(days: a.weekday - 1));
    final weekStartB = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(weekStartA, weekStartB);
  }

  /// Parse quest status
  QuestStatus _parseQuestStatus(String status) {
    switch (status) {
      case 'available':
        return QuestStatus.available;
      case 'in_progress':
        return QuestStatus.inProgress;
      case 'completed':
        return QuestStatus.completed;
      case 'claimed':
        return QuestStatus.claimed;
      case 'expired':
        return QuestStatus.expired;
      default:
        return QuestStatus.available;
    }
  }

  /// Format time left
  String? _formatTimeLeft(DateTime expiresAt) {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return null;
    
    final diff = expiresAt.difference(now);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m';
  }
}
