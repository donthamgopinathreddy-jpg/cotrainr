/// Pure calculation logic for Nutrition Goal Planner (estimates only).
class NutritionGoalCalculator {
  NutritionGoalCalculator._();

  static const String formulaVersion = 'mifflin_st_jeor_v1';
  static const double kcalPerKgFat = 7700;

  static const Map<String, String> goalTypeLabels = {
    'fat_loss': 'Fat Loss',
    'weight_loss': 'Weight Loss',
    'muscle_gain': 'Muscle Gain',
    'lean_bulk': 'Lean Bulk',
    'weight_gain': 'Weight Gain',
    'body_recomposition': 'Body Recomposition',
    'maintenance': 'Maintenance',
    'athletic_performance': 'Athletic Performance',
    'endurance_training': 'Endurance Training',
    'strength_training': 'Strength Training',
    'general_health': 'General Health',
  };

  static String normalizeActivityLevel(String level) {
    switch (level) {
      case 'light':
        return 'lightly_active';
      case 'moderate':
        return 'moderately_active';
      case 'active':
        return 'very_active';
      default:
        return level;
    }
  }

  static double activityMultiplier(String activityLevel) {
    switch (normalizeActivityLevel(activityLevel)) {
      case 'sedentary':
        return 1.2;
      case 'lightly_active':
        return 1.375;
      case 'moderately_active':
        return 1.55;
      case 'very_active':
        return 1.725;
      case 'extra_active':
        return 1.9;
      default:
        return 1.55;
    }
  }

  static WeightDirection inferDirection({
    required double currentWeightKg,
    required double targetWeightKg,
  }) {
    final diff = targetWeightKg - currentWeightKg;
    if (diff < -0.1) return WeightDirection.loss;
    if (diff > 0.1) return WeightDirection.gain;
    return WeightDirection.maintain;
  }

  static String directionLabel(WeightDirection direction) {
    switch (direction) {
      case WeightDirection.loss:
        return 'Weight loss direction';
      case WeightDirection.gain:
        return 'Weight gain direction';
      case WeightDirection.maintain:
        return 'Maintenance / recomposition direction';
    }
  }

  static String suggestGoalType(WeightDirection direction) {
    switch (direction) {
      case WeightDirection.loss:
        return 'fat_loss';
      case WeightDirection.gain:
        return 'muscle_gain';
      case WeightDirection.maintain:
        return 'body_recomposition';
    }
  }

  static int minCaloriesForGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'female':
        return 1200;
      case 'male':
        return 1500;
      default:
        return 1350;
    }
  }

  static double proteinPerKg(String goalType) {
    switch (goalType) {
      case 'fat_loss':
        return 2.1;
      case 'weight_loss':
        return 2.0;
      case 'body_recomposition':
        return 2.1;
      case 'muscle_gain':
      case 'lean_bulk':
        return 1.8;
      case 'weight_gain':
        return 1.6;
      case 'endurance_training':
        return 1.6;
      case 'strength_training':
      case 'athletic_performance':
        return 1.8;
      case 'maintenance':
        return 1.5;
      case 'general_health':
        return 1.4;
      default:
        return 1.6;
    }
  }

  static bool _isLossGoal(String goalType) =>
      goalType == 'fat_loss' || goalType == 'weight_loss';

  static bool _isGainGoal(String goalType) =>
      goalType == 'muscle_gain' ||
      goalType == 'lean_bulk' ||
      goalType == 'weight_gain';

  static bool _isMaintenanceGoal(String goalType) =>
      goalType == 'maintenance' || goalType == 'general_health';

  static bool _isPerformanceGoal(String goalType) =>
      goalType == 'athletic_performance' ||
      goalType == 'endurance_training' ||
      goalType == 'strength_training';

  /// Returns BMR in kcal/day (Mifflin–St Jeor).
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final g = gender.toLowerCase();
    if (g == 'female') return base - 161;
    if (g == 'male') return base + 5;
    return base - 78;
  }

  static NutritionGoalResult calculate({
    required int age,
    required String gender,
    required double heightCm,
    required double currentWeightKg,
    required double targetWeightKg,
    required int timelineDays,
    required String activityLevel,
    required String goalType,
  }) {
    final activity = normalizeActivityLevel(activityLevel);
    final direction = inferDirection(
      currentWeightKg: currentWeightKg,
      targetWeightKg: targetWeightKg,
    );

    final bmrVal = bmr(
      weightKg: currentWeightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final maintenance = bmrVal * activityMultiplier(activity);

    final totalChangeKg = (targetWeightKg - currentWeightKg).abs();
    final timelineWeeks = timelineDays > 0 ? timelineDays / 7.0 : 0.0;
    final weeklyChangeKg = timelineWeeks > 0
        ? totalChangeKg / timelineWeeks
        : 0.0;
    final pctBodyPerWeek =
        currentWeightKg > 0 ? (weeklyChangeKg / currentWeightKg) * 100 : 0.0;

    final warnings = <String>[];

    if (timelineDays > 0 && totalChangeKg > 0.01) {
      if (direction == WeightDirection.loss) {
        if (pctBodyPerWeek > 1.0) {
          final saferDays =
              ((totalChangeKg / (currentWeightKg * 0.01)) * 7).ceil().clamp(7, 3650);
          warnings.add(
            'Losing more than ~1% body weight per week is aggressive. '
            'Consider at least $saferDays days for a safer pace.',
          );
        } else if (pctBodyPerWeek < 0.25) {
          warnings.add(
            'Your timeline is very long for this weight change; targets use a moderate deficit.',
          );
        }
      } else if (direction == WeightDirection.gain) {
        if (pctBodyPerWeek > 0.5) {
          final saferDays =
              ((totalChangeKg / (currentWeightKg * 0.005)) * 7).ceil().clamp(7, 3650);
          warnings.add(
            'Gaining more than ~0.5% body weight per week is aggressive. '
            'Consider at least $saferDays days for leaner gains.',
          );
        }
      }
    }

    var targetCalories = maintenance.round();

    if (_isLossGoal(goalType)) {
      var dailyDeficit = maintenance * 0.15;
      if (timelineDays > 0 && weeklyChangeKg > 0) {
        dailyDeficit = weeklyChangeKg * kcalPerKgFat / 7;
        final maxDeficit = maintenance * 0.25;
        if (dailyDeficit > maxDeficit) {
          warnings.add(
            'Daily deficit capped at 25% of maintenance calories for safety.',
          );
          dailyDeficit = maxDeficit;
        }
      }
      targetCalories = (maintenance - dailyDeficit).round();
    } else if (_isGainGoal(goalType)) {
      var dailySurplus = maintenance * 0.08;
      if (timelineDays > 0 && weeklyChangeKg > 0) {
        dailySurplus = weeklyChangeKg * kcalPerKgFat / 7;
        final maxSurplus = maintenance * 0.15;
        if (dailySurplus > maxSurplus) {
          warnings.add(
            'Daily surplus capped at 15% of maintenance calories for safety.',
          );
          dailySurplus = maxSurplus;
        }
      }
      targetCalories = (maintenance + dailySurplus).round();
    } else if (goalType == 'body_recomposition') {
      targetCalories = (maintenance * 0.95).round();
    } else if (_isMaintenanceGoal(goalType)) {
      targetCalories = maintenance.round();
    } else if (_isPerformanceGoal(goalType)) {
      final factor = activity == 'very_active' || activity == 'extra_active'
          ? 1.10
          : 1.05;
      targetCalories = (maintenance * factor).round();
    }

    final minCal = minCaloriesForGender(gender);
    if (targetCalories < minCal) {
      warnings.add(
        'Target calories ($targetCalories kcal) are below the recommended '
        'minimum of $minCal kcal/day for your profile.',
      );
    }
    if (targetCalories < bmrVal.round()) {
      warnings.add(
        'Target calories are below your estimated BMR (${bmrVal.round()} kcal). '
        'Extended periods below BMR should be discussed with a professional.',
      );
    }

    var proteinG = (currentWeightKg * proteinPerKg(goalType)).round();
    var fatG = (currentWeightKg * 0.7).round();
    final minFatG = (currentWeightKg * 0.6).round();
    final fatFromCalories = (targetCalories * 0.25 / 9).round();
    if (fatG < fatFromCalories) fatG = fatFromCalories;

    var proteinCal = proteinG * 4;
    var fatCal = fatG * 9;
    var carbCal = targetCalories - proteinCal - fatCal;

    if (carbCal < 0) {
      fatG = minFatG;
      fatCal = fatG * 9;
      carbCal = targetCalories - proteinCal - fatCal;
      if (carbCal < 0) {
        warnings.add(
          'Calorie target may be too low for balanced macros. '
          'Consider a longer timeline or higher activity level.',
        );
        proteinG = (proteinG * 0.95).round().clamp(0, 10000);
        proteinCal = proteinG * 4;
        carbCal = targetCalories - proteinCal - fatCal;
      } else {
        warnings.add('Fat was reduced to the minimum safe level to allow carbs.');
      }
    }

    final carbsG = (carbCal / 4).round().clamp(0, 10000);
    final fiberG = (targetCalories / 1000 * 14).round().clamp(0, 100);
    var waterMl = (currentWeightKg * 35).round();
    if (activity == 'very_active' || activity == 'extra_active') {
      waterMl += 500;
    }

    return NutritionGoalResult(
      bmr: bmrVal.round(),
      maintenanceCalories: maintenance.round(),
      calories: targetCalories.clamp(minCal, 10000),
      proteinG: proteinG.clamp(0, 10000),
      carbsG: carbsG,
      fatG: fatG.clamp(0, 10000),
      fiberG: fiberG,
      waterMl: waterMl.clamp(0, 15000),
      activityLevel: activity,
      goalType: goalType,
      goalTypeLabel: goalTypeLabels[goalType] ?? goalType,
      currentWeightKg: currentWeightKg,
      targetWeightKg: targetWeightKg,
      timelineDays: timelineDays,
      weeklyChangeKg: double.parse(weeklyChangeKg.toStringAsFixed(2)),
      direction: direction,
      directionLabel: directionLabel(direction),
      warnings: warnings,
      belowMinimumCalories: targetCalories < minCal,
      belowBmr: targetCalories < bmrVal.round(),
      aggressiveTimeline: warnings.any((w) => w.contains('aggressive')),
      formulaVersion: formulaVersion,
    );
  }
}

enum WeightDirection { loss, gain, maintain }

class NutritionGoalResult {
  final int bmr;
  final int maintenanceCalories;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int waterMl;
  final String activityLevel;
  final String goalType;
  final String goalTypeLabel;
  final double currentWeightKg;
  final double targetWeightKg;
  final int timelineDays;
  final double weeklyChangeKg;
  final WeightDirection direction;
  final String directionLabel;
  final List<String> warnings;
  final bool belowMinimumCalories;
  final bool belowBmr;
  final bool aggressiveTimeline;
  final String formulaVersion;

  const NutritionGoalResult({
    required this.bmr,
    required this.maintenanceCalories,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.waterMl,
    required this.activityLevel,
    required this.goalType,
    required this.goalTypeLabel,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.timelineDays,
    required this.weeklyChangeKg,
    required this.direction,
    required this.directionLabel,
    this.warnings = const [],
    this.belowMinimumCalories = false,
    this.belowBmr = false,
    this.aggressiveTimeline = false,
    required this.formulaVersion,
  });

  String? get warning => warnings.isEmpty ? null : warnings.join('\n\n');
}
