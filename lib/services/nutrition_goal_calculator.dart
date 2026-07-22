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

  static bool isLossGoal(String goalType) =>
      goalType == 'fat_loss' || goalType == 'weight_loss';

  static bool isGainGoal(String goalType) =>
      goalType == 'muscle_gain' ||
      goalType == 'lean_bulk' ||
      goalType == 'weight_gain';

  static bool _isPerformanceGoal(String goalType) =>
      goalType == 'athletic_performance' ||
      goalType == 'endurance_training' ||
      goalType == 'strength_training';

  /// Goal-aware calorie adjustment chips for the advanced options UI.
  static List<CalorieAdjustmentPreset> presetsForGoal(String goalType) {
    switch (goalType) {
      case 'fat_loss':
      case 'weight_loss':
        return const [
          CalorieAdjustmentPreset.auto(),
          CalorieAdjustmentPreset(
            id: 'def_250',
            title: '250 kcal deficit',
            subtitle: 'Slow fat loss',
            adjustmentKcal: -250,
          ),
          CalorieAdjustmentPreset(
            id: 'def_500',
            title: '500 kcal deficit',
            subtitle: 'Moderate fat loss',
            adjustmentKcal: -500,
          ),
          CalorieAdjustmentPreset(
            id: 'def_750',
            title: '750 kcal deficit',
            subtitle: 'Aggressive fat loss',
            adjustmentKcal: -750,
          ),
          CalorieAdjustmentPreset.custom(),
        ];
      case 'muscle_gain':
      case 'lean_bulk':
      case 'weight_gain':
        return const [
          CalorieAdjustmentPreset.auto(),
          CalorieAdjustmentPreset(
            id: 'sur_250',
            title: '250 kcal surplus',
            subtitle: 'Lean bulk',
            adjustmentKcal: 250,
          ),
          CalorieAdjustmentPreset(
            id: 'sur_500',
            title: '500 kcal surplus',
            subtitle: 'Muscle gain',
            adjustmentKcal: 500,
          ),
          CalorieAdjustmentPreset.custom(),
        ];
      case 'body_recomposition':
        return const [
          CalorieAdjustmentPreset.auto(),
          CalorieAdjustmentPreset(
            id: 'def_100',
            title: '100 kcal deficit',
            subtitle: 'Gentle cut',
            adjustmentKcal: -100,
          ),
          CalorieAdjustmentPreset(
            id: 'def_250',
            title: '250 kcal deficit',
            subtitle: 'Leaner recomp',
            adjustmentKcal: -250,
          ),
          CalorieAdjustmentPreset(
            id: 'maint_0',
            title: 'Maintenance',
            subtitle: 'Hold calories',
            adjustmentKcal: 0,
          ),
          CalorieAdjustmentPreset(
            id: 'sur_100',
            title: '100 kcal surplus',
            subtitle: 'Gentle build',
            adjustmentKcal: 100,
          ),
          CalorieAdjustmentPreset.custom(),
        ];
      case 'maintenance':
        return const [
          CalorieAdjustmentPreset.auto(),
          CalorieAdjustmentPreset(
            id: 'maint_0',
            title: 'Maintenance',
            subtitle: '0 kcal adjustment',
            adjustmentKcal: 0,
          ),
          CalorieAdjustmentPreset.custom(),
        ];
      default:
        return const [
          CalorieAdjustmentPreset.auto(),
          CalorieAdjustmentPreset(
            id: 'maint_0',
            title: 'Maintenance',
            subtitle: '0 kcal adjustment',
            adjustmentKcal: 0,
          ),
          CalorieAdjustmentPreset.custom(),
        ];
    }
  }

  /// Clamp auto timeline-derived adjustment to safe goal-specific bands.
  static int clampAutoAdjustment(String goalType, double raw) {
    final v = raw.round();
    switch (goalType) {
      case 'fat_loss':
      case 'weight_loss':
        return v.clamp(-750, -250);
      case 'body_recomposition':
        return v.clamp(-250, 100);
      case 'muscle_gain':
      case 'lean_bulk':
        return v.clamp(150, 350);
      case 'weight_gain':
        return v.clamp(250, 500);
      case 'maintenance':
      case 'general_health':
        return 0;
      default:
        return v.clamp(-350, 350);
    }
  }

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
    CalorieAdjustmentMode adjustmentMode = CalorieAdjustmentMode.auto,
    int? selectedPresetAdjustmentKcal,
    int? customAdjustmentKcal,
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
    final maintenanceRounded = maintenance.round();

    final weightDiffKg = targetWeightKg - currentWeightKg;
    final totalChangeKg = weightDiffKg.abs();
    final timelineWeeks = timelineDays > 0 ? timelineDays / 7.0 : 0.0;
    final timelineWeeklyChangeKg = timelineWeeks > 0
        ? totalChangeKg / timelineWeeks
        : 0.0;
    final pctBodyPerWeek = currentWeightKg > 0
        ? (timelineWeeklyChangeKg / currentWeightKg) * 100
        : 0.0;

    final warnings = <String>[];
    String? timelineConflictMessage;
    String? directionMismatchMessage;
    String? safetyClampMessage;
    var safetyClamped = false;

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

    // --- Resolve calorie adjustment ---
    int resolvedAdjustment;
    if (adjustmentMode == CalorieAdjustmentMode.custom) {
      resolvedAdjustment = (customAdjustmentKcal ?? 0).clamp(-1000, 1000);
    } else if (adjustmentMode == CalorieAdjustmentMode.preset) {
      resolvedAdjustment = selectedPresetAdjustmentKcal ?? 0;
    } else {
      // Auto: derive from timeline weight change, then clamp to goal band.
      // Prefer signed: loss → negative, gain → positive.
      double raw;
      if (timelineDays > 0 && totalChangeKg > 0.01) {
        raw = (weightDiffKg * kcalPerKgFat) / timelineDays;
      } else if (isLossGoal(goalType)) {
        raw = -(maintenance * 0.15);
      } else if (isGainGoal(goalType)) {
        raw = maintenance * 0.08;
      } else if (goalType == 'body_recomposition') {
        raw = -(maintenance * 0.05);
      } else if (_isPerformanceGoal(goalType)) {
        raw = maintenance *
            ((activity == 'very_active' || activity == 'extra_active')
                ? 0.10
                : 0.05);
      } else {
        raw = 0;
      }
      resolvedAdjustment = clampAutoAdjustment(goalType, raw);
    }

    // Direction consistency for manual modes
    if (adjustmentMode != CalorieAdjustmentMode.auto) {
      if (weightDiffKg < -0.1 && resolvedAdjustment > 0) {
        directionMismatchMessage =
            'This calorie adjustment does not match your selected weight goal.';
      } else if (weightDiffKg > 0.1 && resolvedAdjustment < 0) {
        directionMismatchMessage =
            'This calorie adjustment does not match your selected weight goal.';
      }
    }

    // Timeline conflict when manual adjustment differs from requested pace
    if (adjustmentMode != CalorieAdjustmentMode.auto &&
        resolvedAdjustment != 0 &&
        totalChangeKg > 0.01 &&
        directionMismatchMessage == null) {
      final matchesLoss =
          weightDiffKg < 0 && resolvedAdjustment < 0;
      final matchesGain =
          weightDiffKg > 0 && resolvedAdjustment > 0;
      if (matchesLoss || matchesGain) {
        final estimatedDays =
            (totalChangeKg * kcalPerKgFat / resolvedAdjustment.abs()).round();
        if (timelineDays > 0 &&
            (estimatedDays - timelineDays).abs() >= 7) {
          timelineConflictMessage =
              'At a ${resolvedAdjustment.abs()} kcal daily '
              '${resolvedAdjustment < 0 ? 'deficit' : 'surplus'}, '
              'your estimated timeline is about $estimatedDays days '
              'instead of $timelineDays days.';
        }
      }
    }

    var targetCalories = maintenanceRounded + resolvedAdjustment;
    final minCal = minCaloriesForGender(gender);
    if (targetCalories < minCal) {
      safetyClamped = true;
      safetyClampMessage =
          'Your selected deficit would create a very low calorie target. '
          'Cotrainr adjusted it to ${minCal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} kcal/day.';
      // Fix common formatting for 1200/1500 without weird commas on 4 digits - use simple:
      safetyClampMessage =
          'Your selected deficit would create a very low calorie target. '
          'Cotrainr adjusted it to $minCal kcal/day.';
      // Recalculate effective adjustment after clamp
      targetCalories = minCal;
      resolvedAdjustment = targetCalories - maintenanceRounded;
      warnings.add(safetyClampMessage);
    }

    if (targetCalories < bmrVal.round()) {
      warnings.add(
        'Target calories are below your estimated BMR (${bmrVal.round()} kcal). '
        'Extended periods below BMR should be discussed with a professional.',
      );
    }

    final estimatedWeeklyFromAdj =
        double.parse(((resolvedAdjustment * 7) / kcalPerKgFat).toStringAsFixed(2));

    // Prefer adjustment-based weekly estimate when not pure auto-timeline display;
    // still store signed estimate from adjustment for results.
    final weeklyChangeKg = adjustmentMode == CalorieAdjustmentMode.auto &&
            totalChangeKg > 0.01
        ? double.parse(
            (weightDiffKg.isNegative
                    ? -timelineWeeklyChangeKg
                    : timelineWeeklyChangeKg)
                .toStringAsFixed(2),
          )
        : estimatedWeeklyFromAdj;

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
      maintenanceCalories: maintenanceRounded,
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
      weeklyChangeKg: weeklyChangeKg,
      direction: direction,
      directionLabel: directionLabel(direction),
      warnings: warnings,
      belowMinimumCalories: targetCalories < minCal && !safetyClamped,
      belowBmr: targetCalories < bmrVal.round(),
      aggressiveTimeline: warnings.any((w) => w.contains('aggressive')),
      formulaVersion: formulaVersion,
      calorieAdjustmentMode: adjustmentMode,
      selectedPresetAdjustmentKcal: selectedPresetAdjustmentKcal,
      customAdjustmentKcal: customAdjustmentKcal,
      resolvedAdjustmentKcal: resolvedAdjustment,
      estimatedWeeklyChangeKg: estimatedWeeklyFromAdj,
      safetyClamped: safetyClamped,
      safetyClampMessage: safetyClampMessage,
      timelineConflictMessage: timelineConflictMessage,
      directionMismatchMessage: directionMismatchMessage,
    );
  }
}

enum WeightDirection { loss, gain, maintain }

enum CalorieAdjustmentMode { auto, preset, custom }

class CalorieAdjustmentPreset {
  final String id;
  final String title;
  final String subtitle;
  /// Null means Auto or Custom (not a fixed preset value).
  final int? adjustmentKcal;
  final bool isAuto;
  final bool isCustom;

  const CalorieAdjustmentPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    this.adjustmentKcal,
    this.isAuto = false,
    this.isCustom = false,
  });

  const CalorieAdjustmentPreset.auto()
      : id = 'auto',
        title = 'Auto — Recommended',
        subtitle = 'Calculated from your goal and timeline',
        adjustmentKcal = null,
        isAuto = true,
        isCustom = false;

  const CalorieAdjustmentPreset.custom()
      : id = 'custom',
        title = 'Custom',
        subtitle = 'Set your own daily adjustment',
        adjustmentKcal = null,
        isAuto = false,
        isCustom = true;

  String get semanticsLabel {
    if (isAuto) return 'Auto, recommended calorie adjustment';
    if (isCustom) return 'Custom calorie adjustment';
    final v = adjustmentKcal ?? 0;
    if (v == 0) return 'Maintenance, zero kilocalories per day';
    if (v < 0) {
      return 'Minus ${v.abs()} kilocalories per day, $subtitle';
    }
    return 'Plus $v kilocalories per day, $subtitle';
  }
}

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

  final CalorieAdjustmentMode calorieAdjustmentMode;
  final int? selectedPresetAdjustmentKcal;
  final int? customAdjustmentKcal;
  final int resolvedAdjustmentKcal;
  final double estimatedWeeklyChangeKg;
  final bool safetyClamped;
  final String? safetyClampMessage;
  final String? timelineConflictMessage;
  final String? directionMismatchMessage;

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
    this.calorieAdjustmentMode = CalorieAdjustmentMode.auto,
    this.selectedPresetAdjustmentKcal,
    this.customAdjustmentKcal,
    this.resolvedAdjustmentKcal = 0,
    this.estimatedWeeklyChangeKg = 0,
    this.safetyClamped = false,
    this.safetyClampMessage,
    this.timelineConflictMessage,
    this.directionMismatchMessage,
  });

  String? get warning => warnings.isEmpty ? null : warnings.join('\n\n');

  String get calculationModeLabel {
    switch (calorieAdjustmentMode) {
      case CalorieAdjustmentMode.auto:
        return 'Auto';
      case CalorieAdjustmentMode.preset:
      case CalorieAdjustmentMode.custom:
        return 'Manual';
    }
  }

  String get adjustmentRowLabel {
    final v = resolvedAdjustmentKcal;
    if (v < 0) return 'Calorie deficit';
    if (v > 0) return 'Calorie surplus';
    return 'Maintenance';
  }

  String get adjustmentRowValue {
    final v = resolvedAdjustmentKcal;
    if (v == 0) return '0 kcal/day';
    return '${v.abs()} kcal/day';
  }

  String get signedAdjustmentLabel {
    final v = resolvedAdjustmentKcal;
    if (v > 0) return '+$v kcal';
    if (v < 0) return '−${v.abs()} kcal';
    return '0 kcal';
  }
}
