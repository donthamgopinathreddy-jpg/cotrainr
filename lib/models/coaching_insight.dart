import 'package:flutter/material.dart';

enum CoachingInsightCategory {
  steps,
  calories,
  water,
  protein,
  weeklyProgress,
  streak,
  allComplete,
  empty,
}

class CoachingInsight {
  final String id;
  final String emoji;
  final String message;
  final Color accentColor;
  final CoachingInsightCategory category;

  const CoachingInsight({
    required this.id,
    required this.emoji,
    required this.message,
    required this.accentColor,
    required this.category,
  });

  String get displayText => '$emoji $message';
}

/// Snapshot of user progress used to generate coaching messages.
class CoachingInsightContext {
  final int steps;
  final int stepsGoal;
  final double calories;
  final double caloriesGoal;
  final double waterLiters;
  final double waterGoalLiters;
  final double proteinGrams;
  final double proteinGoalGrams;
  final int weeklyWorkoutsDone;
  final int weeklyWorkoutsGoal;
  final int streakDays;
  final bool hasMetricsData;

  const CoachingInsightContext({
    this.steps = 0,
    this.stepsGoal = 10000,
    this.calories = 0,
    this.caloriesGoal = 2000,
    this.waterLiters = 0,
    this.waterGoalLiters = 2.5,
    this.proteinGrams = 0,
    this.proteinGoalGrams = 150,
    this.weeklyWorkoutsDone = 0,
    this.weeklyWorkoutsGoal = 3,
    this.streakDays = 0,
    this.hasMetricsData = false,
  });
}

/// Generates dynamic coaching messages from real user progress.
class CoachingInsightGenerator {
  static const _stepsOrange = Color(0xFFE8952E);
  static const _caloriesRed = Color(0xFFE06B5A);
  static const _waterBlue = Color(0xFF4DA8D8);
  static const _proteinGreen = Color(0xFF5BA86B);
  static const _weeklyPurple = Color(0xFF9B7FD4);
  static const _streakAmber = Color(0xFFD4A843);
  static const _completeGreen = Color(0xFF6BBF8A);

  static List<CoachingInsight> generate(CoachingInsightContext ctx) {
    if (!ctx.hasMetricsData &&
        ctx.steps == 0 &&
        ctx.calories == 0 &&
        ctx.waterLiters == 0 &&
        ctx.proteinGrams == 0) {
      return const [
        CoachingInsight(
          id: 'empty',
          emoji: '💪',
          message: "Let's start building healthy habits today.",
          accentColor: _stepsOrange,
          category: CoachingInsightCategory.empty,
        ),
      ];
    }

    if (_dailyGoalsComplete(ctx)) {
      final weeklyInsights = _weeklyInsights(ctx);
      if (weeklyInsights.isNotEmpty) return weeklyInsights;
      return const [
        CoachingInsight(
          id: 'all_complete',
          emoji: '🎉',
          message: 'All daily goals completed. Keep the momentum going.',
          accentColor: _completeGreen,
          category: CoachingInsightCategory.allComplete,
        ),
      ];
    }

    final insights = <CoachingInsight>[];

    // Priority 1: Steps
    if (ctx.stepsGoal > 0) {
      final remaining = ctx.stepsGoal - ctx.steps;
      final pct = (ctx.steps / ctx.stepsGoal * 100).clamp(0.0, 100.0);
      if (remaining > 0) {
        insights.add(CoachingInsight(
          id: 'steps_remaining',
          emoji: '👣',
          message:
              'Walk ${_formatInt(remaining)} more steps to reach today\'s goal.',
          accentColor: _stepsOrange,
          category: CoachingInsightCategory.steps,
        ));
        if (pct >= 25) {
          insights.add(CoachingInsight(
            id: 'steps_pct',
            emoji: '👣',
            message:
                'You\'re ${pct.round()}% of the way to your step target.',
            accentColor: _stepsOrange,
            category: CoachingInsightCategory.steps,
          ));
        }
      }
    }

    // Priority 2: Calories (active calories burned goal)
    if (ctx.caloriesGoal > 0) {
      final remaining = ctx.caloriesGoal - ctx.calories;
      final pct = (ctx.calories / ctx.caloriesGoal * 100).clamp(0.0, 100.0);
      if (remaining > 0) {
        insights.add(CoachingInsight(
          id: 'calories_remaining',
          emoji: '🔥',
          message:
              'Burn ${_formatInt(remaining.round())} more kcal to hit today\'s activity goal.',
          accentColor: _caloriesRed,
          category: CoachingInsightCategory.calories,
        ));
        if (remaining <= ctx.caloriesGoal * 0.15 && remaining > 0) {
          insights.add(CoachingInsight(
            id: 'calories_close',
            emoji: '🔥',
            message:
                'Great job. Only ${_formatInt(remaining.round())} kcal remaining.',
            accentColor: _caloriesRed,
            category: CoachingInsightCategory.calories,
          ));
        } else if (pct >= 30) {
          insights.add(CoachingInsight(
            id: 'calories_pct',
            emoji: '🔥',
            message:
                'You\'re ${pct.round()}% toward today\'s calorie burn goal.',
            accentColor: _caloriesRed,
            category: CoachingInsightCategory.calories,
          ));
        }
      }
    }

    // Priority 3: Water
    if (ctx.waterGoalLiters > 0) {
      final remainingMl =
          ((ctx.waterGoalLiters - ctx.waterLiters) * 1000).round();
      if (remainingMl > 0) {
        insights.add(CoachingInsight(
          id: 'water_remaining',
          emoji: '💧',
          message:
              'Drink ${_formatInt(remainingMl)} ml more water to reach your goal.',
          accentColor: _waterBlue,
          category: CoachingInsightCategory.water,
        ));
        if (remainingMl <= 500) {
          insights.add(CoachingInsight(
            id: 'water_close',
            emoji: '💧',
            message: 'You\'re just one bottle away from today\'s target.',
            accentColor: _waterBlue,
            category: CoachingInsightCategory.water,
          ));
        }
      }
    }

    // Priority 4: Protein
    if (ctx.proteinGoalGrams > 0) {
      final remaining = ctx.proteinGoalGrams - ctx.proteinGrams;
      if (remaining > 0) {
        insights.add(CoachingInsight(
          id: 'protein_remaining',
          emoji: '🥩',
          message:
              'Eat ${remaining.round()} g more protein to hit your nutrition goal.',
          accentColor: _proteinGreen,
          category: CoachingInsightCategory.protein,
        ));
        if (remaining <= ctx.proteinGoalGrams * 0.25) {
          insights.add(CoachingInsight(
            id: 'protein_close',
            emoji: '🥩',
            message: 'Only one high-protein meal remaining.',
            accentColor: _proteinGreen,
            category: CoachingInsightCategory.protein,
          ));
        }
      }
    }

    // Priority 5: Weekly progress
    insights.addAll(_weeklyInsights(ctx));

    // Priority 6: Streak
    if (ctx.streakDays >= 0) {
      final target = ctx.streakDays + 1;
      insights.add(CoachingInsight(
        id: 'streak_today',
        emoji: '🔥',
        message:
            'Complete today\'s goals to reach a $target-day streak.',
        accentColor: _streakAmber,
        category: CoachingInsightCategory.streak,
      ));
      if (ctx.streakDays >= 1) {
        insights.add(CoachingInsight(
          id: 'streak_extend',
          emoji: '🔥',
          message: 'Keep going. One more day extends your streak.',
          accentColor: _streakAmber,
          category: CoachingInsightCategory.streak,
        ));
      }
    }

    if (insights.isEmpty) {
      return const [
        CoachingInsight(
          id: 'all_complete',
          emoji: '🎉',
          message: 'All daily goals completed. Keep the momentum going.',
          accentColor: _completeGreen,
          category: CoachingInsightCategory.allComplete,
        ),
      ];
    }

    // One insight at a time — return highest-priority category first,
    // but include alternates within categories for rotation variety.
    return _dedupeByCategory(insights);
  }

  static bool _dailyGoalsComplete(CoachingInsightContext ctx) {
    final stepsDone =
        ctx.stepsGoal <= 0 || ctx.steps >= ctx.stepsGoal;
    final calDone =
        ctx.caloriesGoal <= 0 || ctx.calories >= ctx.caloriesGoal;
    final waterDone = ctx.waterGoalLiters <= 0 ||
        ctx.waterLiters >= ctx.waterGoalLiters;
    final proteinDone = ctx.proteinGoalGrams <= 0 ||
        ctx.proteinGrams >= ctx.proteinGoalGrams;
    return stepsDone && calDone && waterDone && proteinDone;
  }

  static List<CoachingInsight> _weeklyInsights(CoachingInsightContext ctx) {
    final insights = <CoachingInsight>[];
    if (ctx.weeklyWorkoutsGoal <= 0) return insights;
    final remaining = ctx.weeklyWorkoutsGoal - ctx.weeklyWorkoutsDone;
    final pct = (ctx.weeklyWorkoutsDone / ctx.weeklyWorkoutsGoal * 100)
        .clamp(0.0, 100.0);
    if (remaining > 0) {
      insights.add(CoachingInsight(
        id: 'weekly_remaining',
        emoji: '🎯',
        message:
            'Complete $remaining more workout${remaining == 1 ? '' : 's'} to hit this week\'s goal.',
        accentColor: _weeklyPurple,
        category: CoachingInsightCategory.weeklyProgress,
      ));
    }
    if (pct >= 40 && remaining > 0) {
      insights.add(CoachingInsight(
        id: 'weekly_pct',
        emoji: '🎯',
        message: 'You\'re ${pct.round()}% through your weekly target.',
        accentColor: _weeklyPurple,
        category: CoachingInsightCategory.weeklyProgress,
      ));
    }
    return insights;
  }

  static List<CoachingInsight> _dedupeByCategory(List<CoachingInsight> all) {
    final order = CoachingInsightCategory.values;
    final byCategory = <CoachingInsightCategory, List<CoachingInsight>>{};
    for (final i in all) {
      byCategory.putIfAbsent(i.category, () => []).add(i);
    }
    final result = <CoachingInsight>[];
    for (final cat in order) {
      final list = byCategory[cat];
      if (list != null) result.addAll(list);
    }
    return result;
  }

  static String _formatInt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '$n';
  }
}
