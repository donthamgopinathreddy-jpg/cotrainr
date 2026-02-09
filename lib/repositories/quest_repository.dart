import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quest_models.dart';

/// Repository for quest, challenge, achievement, and leaderboard operations
class QuestRepository {
  final SupabaseClient _supabase;

  QuestRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // =========================================
  // DAILY QUESTS
  // =========================================

  /// Get daily quests for current user
  /// Returns list of active daily quests with progress
  Future<List<ActiveQuest>> getDailyQuests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure daily quests are allocated
    try {
      await _supabase.rpc('allocate_daily_quests', params: {
        'p_user_id': userId,
      });
    } catch (e) {
      // Ignore if already allocated today
    }

    // Fetch active daily quests
    final response = await _supabase
        .from('user_quests')
        .select('''
          id,
          quest_definition_id,
          type,
          category,
          difficulty,
          status,
          progress_current,
          progress_target,
          reward_xp,
          reward_coins,
          assigned_at,
          expires_at,
          quests:quest_definition_id (
            title,
            description,
            icon_name,
            icon_color,
            requirements,
            category
          )
        ''')
        .eq('user_id', userId)
        .eq('type', 'daily')
        .or('status.eq.available,status.eq.in_progress,status.eq.completed')
        .order('assigned_at');

    return response.map<ActiveQuest>((row) {
      final def = row['quests'] as Map<String, dynamic>? ?? {};
      return ActiveQuest(
        id: row['id'] as String,
        questDefinitionId: row['quest_definition_id'] as String,
        type: QuestType.daily,
        title: def['title'] as String? ?? 'Quest',
        description: def['description'] as String? ?? '',
        category: _parseCategory((def['category'] ?? row['category']) as String? ?? ''),
        icon: _parseIcon(def['icon_name'] as String?),
        iconColor: _parseColor(def['icon_color'] as String?),
        progress: (row['progress_current'] as num?)?.toDouble() ?? 0.0,
        maxProgress: (row['progress_target'] as num?)?.toDouble() ?? 1.0,
        rewardXP: row['reward_xp'] as int? ?? 0,
        rewardPoints: 0, // TODO: Add reward_points to user_quests table
        status: _parseStatus(row['status'] as String? ?? 'available'),
        assignedAt: DateTime.parse(row['assigned_at'] as String),
        expiresAt: row['expires_at'] != null
            ? DateTime.parse(row['expires_at'] as String)
            : DateTime.now().add(const Duration(days: 1)),
        timeLeft: _formatTimeLeft(
          row['expires_at'] != null
              ? DateTime.parse(row['expires_at'] as String)
              : DateTime.now().add(const Duration(days: 1)),
        ),
        canClaim: (row['status'] as String) == 'completed',
        requirements: def['requirements'] as Map<String, dynamic>? ?? {},
      );
    }).toList();
  }

  // =========================================
  // WEEKLY QUESTS
  // =========================================

  /// Get weekly quests for current user
  Future<List<ActiveQuest>> getWeeklyQuests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure weekly quests are allocated
    try {
      await _supabase.rpc('allocate_weekly_quests', params: {
        'p_user_id': userId,
      });
    } catch (e) {
      // Ignore if already allocated this week
    }

    final response = await _supabase
        .from('user_quests')
        .select('''
          id,
          quest_definition_id,
          type,
          category,
          difficulty,
          status,
          progress_current,
          progress_target,
          reward_xp,
          reward_coins,
          assigned_at,
          expires_at,
          quests:quest_definition_id (
            title,
            description,
            icon_name,
            icon_color,
            requirements,
            category
          )
        ''')
        .eq('user_id', userId)
        .eq('type', 'weekly')
        .or('status.eq.available,status.eq.in_progress,status.eq.completed')
        .order('assigned_at');

    return response.map<ActiveQuest>((row) {
      final def = row['quests'] as Map<String, dynamic>? ?? {};
      return ActiveQuest(
        id: row['id'] as String,
        questDefinitionId: row['quest_definition_id'] as String,
        type: QuestType.weekly,
        title: def['title'] as String? ?? 'Quest',
        description: def['description'] as String? ?? '',
        category: _parseCategory((def['category'] ?? row['category']) as String? ?? ''),
        icon: _parseIcon(def['icon_name'] as String?),
        iconColor: _parseColor(def['icon_color'] as String?),
        progress: (row['progress_current'] as num?)?.toDouble() ?? 0.0,
        maxProgress: (row['progress_target'] as num?)?.toDouble() ?? 1.0,
        rewardXP: row['reward_xp'] as int? ?? 0,
        rewardPoints: 0,
        status: _parseStatus(row['status'] as String? ?? 'available'),
        assignedAt: DateTime.parse(row['assigned_at'] as String),
        expiresAt: row['expires_at'] != null
            ? DateTime.parse(row['expires_at'] as String)
            : DateTime.now().add(const Duration(days: 7)),
        timeLeft: _formatTimeLeft(
          row['expires_at'] != null
              ? DateTime.parse(row['expires_at'] as String)
              : DateTime.now().add(const Duration(days: 7)),
        ),
        canClaim: (row['status'] as String) == 'completed',
        requirements: def['requirements'] as Map<String, dynamic>? ?? {},
      );
    }).toList();
  }

  // =========================================
  // QUEST PROGRESS & CLAIMS
  // =========================================

  /// Update quest progress
  /// Returns updated progress info
  Future<Map<String, dynamic>> updateQuestProgress(
    String questInstanceId,
    double delta,
  ) async {
    final response = await _supabase.rpc('update_quest_progress', params: {
      'p_quest_instance_id': questInstanceId,
      'p_delta': delta,
    });

    return response.first as Map<String, dynamic>;
  }

  /// Claim quest rewards
  /// Returns awarded XP, coins, and new level
  Future<Map<String, dynamic>> claimQuestRewards(String questInstanceId) async {
    final response = await _supabase.rpc('claim_quest_rewards', params: {
      'p_quest_instance_id': questInstanceId,
    });

    return response.first as Map<String, dynamic>;
  }

  /// Refill daily quest slot (max 2 per day)
  Future<List<Map<String, dynamic>>> refillQuests() async {
    final response = await _supabase.rpc('refill_quests');

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================================
  // ACTIVE CHALLENGES
  // =========================================

  /// Get active challenges for current user
  Future<List<ChallengeQuest>> getActiveChallenges() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('challenges')
        .select('''
          id,
          title,
          description,
          challenge_type,
          scope,
          goal_value,
          goal_unit,
          start_date,
          end_date,
          reward_xp,
          reward_points,
          created_by,
          challenge_members!inner(user_id),
          challenge_progress!inner(user_id, current_progress)
        ''')
        .eq('is_active', true)
        .eq('challenge_members.user_id', userId)
        .gte('end_date', DateTime.now().toIso8601String())
        .order('start_date', ascending: false);

    return response.map<ChallengeQuest>((row) {
      final members = row['challenge_members'] as List? ?? [];
      final progress = (row['challenge_progress'] as List? ?? []).firstOrNull
          as Map<String, dynamic>?;
      final currentProgress =
          (progress?['current_progress'] as num?)?.toDouble() ?? 0.0;
      final goalValue = (row['goal_value'] as num?)?.toDouble() ?? 1.0;

      return ChallengeQuest(
        id: row['id'] as String,
        questDefinitionId: row['id'] as String,
        type: QuestType.challenge,
        title: row['title'] as String? ?? 'Challenge',
        description: row['description'] as String? ?? '',
        category: _parseCategory(row['challenge_type'] as String? ?? ''),
        icon: Icons.emoji_events,
        iconColor: null,
        progress: currentProgress,
        maxProgress: goalValue,
        rewardXP: row['reward_xp'] as int? ?? 0,
        rewardPoints: row['reward_points'] as int? ?? 0,
        status: currentProgress >= goalValue
            ? QuestStatus.completed
            : QuestStatus.inProgress,
        assignedAt: DateTime.parse(row['start_date'] as String),
        expiresAt: DateTime.parse(row['end_date'] as String),
        timeLeft: _formatTimeLeft(DateTime.parse(row['end_date'] as String)),
        canClaim: currentProgress >= goalValue,
        requirements: {
          'goal': goalValue,
          'unit': row['goal_unit'] as String? ?? '',
        },
        isJoined: true,
        participants: members.length,
        scope: _parseChallengeScope(row['scope'] as String? ?? 'friends'),
        challengeId: row['id'] as String,
      );
    }).toList();
  }

  /// Get challenge detail by ID
  Future<Map<String, dynamic>> getChallengeDetail(String challengeId) async {
    final response = await _supabase
        .from('challenges')
        .select('''
          *,
          challenge_members(count),
          challenge_progress(
            user_id,
            current_progress,
            profiles:user_id(username, avatar_url)
          )
        ''')
        .eq('id', challengeId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// Create a new challenge
  Future<String> createChallenge({
    required String title,
    required String description,
    required String challengeType,
    required String scope,
    required double goalValue,
    String? goalUnit,
    required DateTime startDate,
    required DateTime endDate,
    int rewardXP = 0,
    int rewardPoints = 0,
    int? maxParticipants,
  }) async {
    final response = await _supabase.rpc('create_challenge', params: {
      'p_title': title,
      'p_description': description,
      'p_challenge_type': challengeType,
      'p_scope': scope,
      'p_goal_value': goalValue,
      'p_goal_unit': goalUnit,
      'p_start_date': startDate.toIso8601String(),
      'p_end_date': endDate.toIso8601String(),
      'p_reward_xp': rewardXP,
      'p_reward_points': rewardPoints,
      'p_max_participants': maxParticipants,
    });

    return (response.first as Map<String, dynamic>)['challenge_id'] as String;
  }

  /// Join a challenge
  Future<bool> joinChallenge(String challengeId) async {
    final response = await _supabase.rpc('join_challenge', params: {
      'p_challenge_id': challengeId,
    });

    final result = response.first as Map<String, dynamic>;
    return result['success'] as bool? ?? false;
  }

  /// Update challenge progress
  Future<Map<String, dynamic>> updateChallengeProgress(
    String challengeId,
    double delta,
  ) async {
    final response = await _supabase.rpc('update_challenge_progress', params: {
      'p_challenge_id': challengeId,
      'p_delta': delta,
    });

    return response.first as Map<String, dynamic>;
  }

  // =========================================
  // ACHIEVEMENTS
  // =========================================

  /// Get all achievements with user progress
  Future<List<Achievement>> getAchievements() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('achievements')
        .select('''
          *,
          user_achievements!left(
            current_progress,
            is_unlocked,
            unlocked_at
          )
        ''')
        .eq('is_active', true)
        .eq('user_achievements.user_id', userId)
        .order('category', ascending: true)
        .order('tier', ascending: true);

    return response.map<Achievement>((row) {
      final userAchievement = (row['user_achievements'] as List? ?? []).firstOrNull
          as Map<String, dynamic>?;
      final currentProgress =
          (userAchievement?['current_progress'] as num?)?.toDouble() ?? 0.0;
      final isUnlocked = userAchievement?['is_unlocked'] as bool? ?? false;
      final unlockedAt = userAchievement?['unlocked_at'] != null
          ? DateTime.parse(userAchievement!['unlocked_at'] as String)
          : null;

      return Achievement(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        icon: _parseIcon(row['icon_name'] as String?),
        iconColor: _parseColor(row['icon_color'] as String?),
        category: _parseAchievementCategory(row['category'] as String),
        tier: row['tier'] as int? ?? 1,
        currentProgress: currentProgress,
        targetProgress: (row['target_progress'] as num).toDouble(),
        isUnlocked: isUnlocked,
        unlockedAt: unlockedAt,
        rewardXP: row['reward_xp'] as int? ?? 0,
        badgeFrame: row['badge_frame'] as String?,
        titleReward: row['title_reward'] as String?,
      );
    }).toList();
  }

  // =========================================
  // LEADERBOARD
  // =========================================

  /// Get leaderboard with cursor-based pagination
  /// periodType: 'daily', 'weekly', 'monthly'
  /// periodStart: Date for the period (e.g., today for daily, week start for weekly)
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String periodType,
    required DateTime periodStart,
    int limit = 50,
    int? cursorPoints,
    String? cursorUserId,
  }) async {
    final response = await _supabase.rpc('get_leaderboard', params: {
      'p_period_type': periodType,
      'p_period_start': periodStart.toIso8601String().split('T')[0],
      'p_limit': limit,
      'p_cursor_points': cursorPoints,
      'p_cursor_user_id': cursorUserId,
    });

    return response.map<LeaderboardEntry>((row) {
      return LeaderboardEntry(
        userId: row['user_id'] as String,
        username: row['username'] as String? ?? 'User',
        rank: (row['rank'] as num).toInt(),
        level: row['level'] as int? ?? 1,
        points: row['points'] as int? ?? 0,
        xp: row['total_xp'] as int? ?? 0,
        avatarUrl: row['avatar_url'] as String?,
      );
    }).toList();
  }

  // =========================================
  // HELPER METHODS
  // =========================================

  QuestCategory _parseCategory(String category) {
    switch (category.toLowerCase()) {
      case 'steps':
        return QuestCategory.steps;
      case 'workout':
        return QuestCategory.workout;
      case 'nutrition':
        return QuestCategory.nutrition;
      case 'hydration':
        return QuestCategory.hydration;
      case 'consistency':
        return QuestCategory.consistency;
      case 'social':
        return QuestCategory.social;
      case 'recovery':
        return QuestCategory.recovery;
      default:
        return QuestCategory.steps;
    }
  }

  AchievementCategory _parseAchievementCategory(String category) {
    switch (category.toLowerCase()) {
      case 'streaks':
        return AchievementCategory.streaks;
      case 'steps':
        return AchievementCategory.steps;
      case 'nutrition':
        return AchievementCategory.nutrition;
      case 'hydration':
        return AchievementCategory.hydration;
      case 'challenges':
        return AchievementCategory.challenges;
      case 'social':
        return AchievementCategory.social;
      case 'consistency':
        return AchievementCategory.consistency;
      default:
        return AchievementCategory.streaks;
    }
  }

  QuestStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
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

  ChallengeScope _parseChallengeScope(String scope) {
    switch (scope.toLowerCase()) {
      case 'friends':
        return ChallengeScope.friends;
      case 'local':
        return ChallengeScope.local;
      case 'global':
        return ChallengeScope.global;
      default:
        return ChallengeScope.friends;
    }
  }

  IconData _parseIcon(String? iconName) {
    // Map icon names to Flutter icons
    // You can extend this with custom icons
    switch (iconName) {
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'check_circle':
        return Icons.check_circle_rounded;
      case 'wb_twilight':
        return Icons.wb_twilight_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color? _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return null;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF'), radix: 16));
    } catch (e) {
      return null;
    }
  }

  String? _formatTimeLeft(DateTime expiresAt) {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return null;

    final diff = expiresAt.difference(now);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return '${diff.inMinutes}m';
    }
  }
}
