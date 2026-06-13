import '../../models/coaching_insight.dart';

/// Builds coaching insight lists from home-page metric state.
class CoachingInsightBuilder {
  static List<CoachingInsight> build({
    required int steps,
    required int stepsGoal,
    required double calories,
    required double caloriesGoal,
    required double waterLiters,
    required double waterGoalLiters,
    required double proteinGrams,
    required double proteinGoalGrams,
    required List<double> stepsWeekly,
    required int streakDays,
    int weeklyWorkoutsGoal = 3,
  }) {
    var weeklyActiveDays = 0;
    for (final daySteps in stepsWeekly) {
      if (daySteps >= stepsGoal) weeklyActiveDays++;
    }

    return CoachingInsightGenerator.generate(
      CoachingInsightContext(
        steps: steps,
        stepsGoal: stepsGoal,
        calories: calories,
        caloriesGoal: caloriesGoal,
        waterLiters: waterLiters,
        waterGoalLiters: waterGoalLiters,
        proteinGrams: proteinGrams,
        proteinGoalGrams: proteinGoalGrams,
        weeklyWorkoutsDone: weeklyActiveDays,
        weeklyWorkoutsGoal: weeklyWorkoutsGoal,
        streakDays: streakDays,
        hasMetricsData:
            steps > 0 || calories > 0 || waterLiters > 0 || proteinGrams > 0,
      ),
    );
  }
}
