import 'package:flutter/material.dart';

/// Status of a quest
enum QuestStatus {
  inProgress,
  completed,
  missed,
}

/// Base quest model
abstract class BaseQuest {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final double progress;
  final double maxProgress;
  final int rewardXP;
  final QuestStatus status;
  final Color? iconColor;

  const BaseQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.maxProgress,
    required this.rewardXP,
    required this.status,
    this.iconColor,
  });
}

/// Daily quest model
class DailyQuest extends BaseQuest {
  final String? timeLeft;

  const DailyQuest({
    required super.id,
    required super.title,
    required super.description,
    required super.icon,
    required super.progress,
    required super.maxProgress,
    required super.rewardXP,
    required super.status,
    super.iconColor,
    this.timeLeft,
  });
}

/// Weekly quest model
class WeeklyQuest extends BaseQuest {
  const WeeklyQuest({
    required super.id,
    required super.title,
    required super.description,
    required super.icon,
    required super.progress,
    required super.maxProgress,
    required super.rewardXP,
    required super.status,
    super.iconColor,
  });
}

/// Challenge quest model
class ChallengeQuest extends BaseQuest {
  final bool isJoined;
  final int participants;
  final String timeRemaining;

  const ChallengeQuest({
    required super.id,
    required super.title,
    required super.description,
    required super.icon,
    required super.progress,
    required super.maxProgress,
    required super.rewardXP,
    required super.status,
    super.iconColor,
    required this.isJoined,
    required this.participants,
    required this.timeRemaining,
  });
}

/// Leaderboard entry model
class LeaderboardEntry {
  final String userId;
  final String username;
  final int rank;
  final int level;
  final int xp;
  final String? avatarUrl;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.rank,
    required this.level,
    required this.xp,
    this.avatarUrl,
  });
}
