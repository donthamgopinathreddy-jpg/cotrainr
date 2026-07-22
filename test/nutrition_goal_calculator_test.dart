import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/services/nutrition_goal_calculator.dart';

void main() {
  group('NutritionGoalCalculator calorie adjustment', () {
    NutritionGoalResult calc({
      CalorieAdjustmentMode mode = CalorieAdjustmentMode.auto,
      int? preset,
      int? custom,
      String goalType = 'fat_loss',
      double current = 90,
      double target = 80,
      int days = 90,
      String gender = 'Male',
    }) {
      return NutritionGoalCalculator.calculate(
        age: 30,
        gender: gender,
        heightCm: 180,
        currentWeightKg: current,
        targetWeightKg: target,
        timelineDays: days,
        activityLevel: 'moderately_active',
        goalType: goalType,
        adjustmentMode: mode,
        selectedPresetAdjustmentKcal: preset,
        customAdjustmentKcal: custom,
      );
    }

    test('auto is default and produces a deficit for fat loss', () {
      final r = calc();
      expect(r.calorieAdjustmentMode, CalorieAdjustmentMode.auto);
      expect(r.resolvedAdjustmentKcal, lessThan(0));
      expect(r.resolvedAdjustmentKcal, inInclusiveRange(-750, -250));
      expect(r.calories, r.maintenanceCalories + r.resolvedAdjustmentKcal);
    });

    test('preset deficit updates target and weekly estimate', () {
      final r = calc(
        mode: CalorieAdjustmentMode.preset,
        preset: -500,
      );
      expect(r.resolvedAdjustmentKcal, -500);
      expect(r.calories, r.maintenanceCalories - 500);
      expect(r.estimatedWeeklyChangeKg, closeTo((-500 * 7) / 7700, 0.01));
      expect(r.calculationModeLabel, 'Manual');
      expect(r.adjustmentRowLabel, 'Calorie deficit');
    });

    test('custom surplus for muscle gain', () {
      final r = calc(
        mode: CalorieAdjustmentMode.custom,
        custom: 250,
        goalType: 'muscle_gain',
        current: 70,
        target: 75,
      );
      expect(r.resolvedAdjustmentKcal, 250);
      expect(r.calories, r.maintenanceCalories + 250);
      expect(r.adjustmentRowLabel, 'Calorie surplus');
    });

    test('safety floor clamps unsafe deficit', () {
      final r = calc(
        mode: CalorieAdjustmentMode.custom,
        custom: -1000,
        gender: 'Male',
        current: 55,
        target: 50,
      );
      expect(r.calories, greaterThanOrEqualTo(1500));
      expect(r.safetyClamped, isTrue);
      expect(r.safetyClampMessage, isNotNull);
    });

    test('direction mismatch when surplus with weight loss target', () {
      final r = calc(
        mode: CalorieAdjustmentMode.preset,
        preset: 250,
        goalType: 'muscle_gain',
        current: 90,
        target: 80,
      );
      expect(r.directionMismatchMessage, isNotNull);
    });

    test('goal-aware presets hide surplus for fat loss', () {
      final presets = NutritionGoalCalculator.presetsForGoal('fat_loss');
      expect(presets.any((p) => (p.adjustmentKcal ?? 0) > 0), isFalse);
      expect(presets.any((p) => p.isAuto), isTrue);
      expect(presets.any((p) => p.isCustom), isTrue);
    });

    test('macros stay non-negative after low calories', () {
      final r = calc(
        mode: CalorieAdjustmentMode.custom,
        custom: -1000,
        gender: 'Female',
        current: 50,
        target: 45,
      );
      expect(r.carbsG, greaterThanOrEqualTo(0));
      expect(r.proteinG, greaterThan(0));
      expect(r.fatG, greaterThan(0));
    });
  });
}
