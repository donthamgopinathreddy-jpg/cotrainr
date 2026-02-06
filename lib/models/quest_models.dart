import 'package:flutter/material.dart';

/// Quest category
enum QuestCategory {
  steps,
  workout,
  nutrition,
  hydration,
  consistency,
  social,
  recovery,
}

/// Quest difficulty
enum QuestDifficulty {
  easy,
  medium,
  hard,
}

/// Time window for quests
enum QuestTimeWindow {
  anytime,
  morning,
  evening,
}

/// Quest status
enum QuestStatus {
  available,
  inProgress,
  completed,
  claimed,
  expired,
}

/// Base quest definition (from pool)
class QuestDefinition {
  final String id;
  final String title;
  final String description;
  final QuestCategory category;
  final QuestDifficulty difficulty;
  final QuestTimeWindow timeWindow;
  final int rewardXP;
  final int rewardPoints; // Leaderboard points (separate from XP)
  final Map<String, dynamic> requirements; // e.g., {"steps": 8000, "before": "08:00"}
  final int cooldownDays; // Days before this quest can appear again
  final IconData icon;
  final Color? iconColor;
  final List<String>? roles; // null = all, or ["client", "trainer", "nutritionist"]

  const QuestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.timeWindow,
    required this.rewardXP,
    required this.rewardPoints,
    required this.requirements,
    this.cooldownDays = 2,
    required this.icon,
    this.iconColor,
    this.roles,
  });
}

/// Active quest instance (assigned to user)
class ActiveQuest {
  final String id;
  final String questDefinitionId;
  final QuestType type; // daily, weekly, challenge
  final String title;
  final String description;
  final QuestCategory category;
  final IconData icon;
  final Color? iconColor;
  final double progress;
  final double maxProgress;
  final int rewardXP;
  final int rewardPoints;
  final QuestStatus status;
  final DateTime assignedAt;
  final DateTime expiresAt;
  final String? timeLeft; // Formatted time remaining
  final bool canClaim; // Progress >= maxProgress and not claimed
  final Map<String, dynamic> requirements;

  const ActiveQuest({
    required this.id,
    required this.questDefinitionId,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.iconColor,
    required this.progress,
    required this.maxProgress,
    required this.rewardXP,
    required this.rewardPoints,
    required this.status,
    required this.assignedAt,
    required this.expiresAt,
    this.timeLeft,
    required this.canClaim,
    required this.requirements,
  });
}

/// Quest type
enum QuestType {
  daily,
  weekly,
  challenge,
}

/// Challenge quest (time-bounded competition)
class ChallengeQuest extends ActiveQuest {
  final bool isJoined;
  final int participants;
  final ChallengeScope scope; // friends, local, global
  final String? challengeId;

  const ChallengeQuest({
    required super.id,
    required super.questDefinitionId,
    required super.type,
    required super.title,
    required super.description,
    required super.category,
    required super.icon,
    super.iconColor,
    required super.progress,
    required super.maxProgress,
    required super.rewardXP,
    required super.rewardPoints,
    required super.status,
    required super.assignedAt,
    required super.expiresAt,
    super.timeLeft,
    required super.canClaim,
    required super.requirements,
    required this.isJoined,
    required this.participants,
    required this.scope,
    this.challengeId,
  });
}

/// Challenge scope
enum ChallengeScope {
  friends,
  local,
  global,
}

/// Achievement model
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;
  final AchievementCategory category;
  final int tier; // 1, 2, 3, etc.
  final double currentProgress;
  final double targetProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int rewardXP;
  final String? badgeFrame; // Cosmetic frame name
  final String? titleReward; // e.g., "Rookie Runner"

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor,
    required this.category,
    required this.tier,
    required this.currentProgress,
    required this.targetProgress,
    required this.isUnlocked,
    this.unlockedAt,
    required this.rewardXP,
    this.badgeFrame,
    this.titleReward,
  });

  double get progressRatio => targetProgress > 0 
      ? (currentProgress / targetProgress).clamp(0.0, 1.0) 
      : 0.0;
}

/// Achievement category
enum AchievementCategory {
  streaks,
  steps,
  nutrition,
  hydration,
  challenges,
  social,
  consistency,
}

/// Leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String username;
  final int rank;
  final int level;
  final int points; // Leaderboard points (not XP)
  final int xp; // Total XP for display
  final String? avatarUrl;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.rank,
    required this.level,
    required this.points,
    required this.xp,
    this.avatarUrl,
  });
}

/// Leaderboard type
enum LeaderboardType {
  friends,
  local,
  global,
}

/// Leaderboard time window
enum LeaderboardTimeWindow {
  daily,
  weekly,
  monthly,
}
