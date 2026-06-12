import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/meal_repository.dart';
import 'nutrition_goal_calculator.dart';

/// Diet filter for food source suggestions.
enum DietPreference {
  all('all', 'All'),
  vegetarian('vegetarian', 'Vegetarian'),
  vegan('vegan', 'Vegan'),
  eggetarian('eggetarian', 'Eggetarian'),
  nonVeg('non_veg', 'Non-Veg');

  final String value;
  final String label;
  const DietPreference(this.value, this.label);

  static DietPreference fromValue(String? raw) {
    return DietPreference.values.firstWhere(
      (d) => d.value == raw,
      orElse: () => DietPreference.all,
    );
  }
}

/// Persisted planner output + inputs for device-only storage.
class SavedNutritionPlannerState {
  final int goalCalories;
  final int goalProtein;
  final int goalCarbs;
  final int goalFats;
  final int goalFiber;
  final int goalWaterMl;
  final int bmr;
  final int maintenanceCalories;
  final String goalType;
  final String activityLevel;
  final String formulaVersion;
  final int plannerAge;
  final String plannerGender;
  final double plannerHeightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final int timelineDays;
  final double weeklyChangeKg;
  final DateTime savedAt;

  const SavedNutritionPlannerState({
    required this.goalCalories,
    required this.goalProtein,
    required this.goalCarbs,
    required this.goalFats,
    required this.goalFiber,
    required this.goalWaterMl,
    required this.bmr,
    required this.maintenanceCalories,
    required this.goalType,
    required this.activityLevel,
    required this.formulaVersion,
    required this.plannerAge,
    required this.plannerGender,
    required this.plannerHeightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.timelineDays,
    required this.weeklyChangeKg,
    required this.savedAt,
  });

  NutritionGoals toNutritionGoals() => NutritionGoals(
        goalCalories: goalCalories,
        goalProtein: goalProtein,
        goalCarbs: goalCarbs,
        goalFats: goalFats,
        goalFiber: goalFiber,
        goalWaterMl: goalWaterMl,
      );

  Map<String, dynamic> toJson() => {
        'goal_calories': goalCalories,
        'goal_protein': goalProtein,
        'goal_carbs': goalCarbs,
        'goal_fats': goalFats,
        'goal_fiber': goalFiber,
        'goal_water_ml': goalWaterMl,
        'bmr': bmr,
        'maintenance_calories': maintenanceCalories,
        'goal_type': goalType,
        'activity_level': activityLevel,
        'formula_version': formulaVersion,
        'planner_age': plannerAge,
        'planner_gender': plannerGender,
        'planner_height_cm': plannerHeightCm,
        'current_weight_kg': currentWeightKg,
        'target_weight_kg': targetWeightKg,
        'timeline_days': timelineDays,
        'weekly_change_kg': weeklyChangeKg,
        'saved_at': savedAt.toIso8601String(),
      };

  factory SavedNutritionPlannerState.fromJson(Map<String, dynamic> json) {
    return SavedNutritionPlannerState(
      goalCalories: (json['goal_calories'] as num).toInt(),
      goalProtein: (json['goal_protein'] as num).toInt(),
      goalCarbs: (json['goal_carbs'] as num).toInt(),
      goalFats: (json['goal_fats'] as num).toInt(),
      goalFiber: (json['goal_fiber'] as num).toInt(),
      goalWaterMl: (json['goal_water_ml'] as num?)?.toInt() ?? 2500,
      bmr: (json['bmr'] as num?)?.toInt() ?? 0,
      maintenanceCalories: (json['maintenance_calories'] as num?)?.toInt() ?? 0,
      goalType: json['goal_type'] as String? ?? 'maintenance',
      activityLevel: json['activity_level'] as String? ?? 'moderately_active',
      formulaVersion: json['formula_version'] as String? ?? 'mifflin_st_jeor_v1',
      plannerAge: (json['planner_age'] as num?)?.toInt() ?? 25,
      plannerGender: json['planner_gender'] as String? ?? 'Male',
      plannerHeightCm: (json['planner_height_cm'] as num?)?.toDouble() ?? 170,
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble() ?? 70,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble() ?? 70,
      timelineDays: (json['timeline_days'] as num?)?.toInt() ?? 84,
      weeklyChangeKg: (json['weekly_change_kg'] as num?)?.toDouble() ?? 0,
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  factory SavedNutritionPlannerState.fromResult({
    required NutritionGoalResult result,
    required int age,
    required String gender,
    required double heightCm,
  }) {
    return SavedNutritionPlannerState(
      goalCalories: result.calories,
      goalProtein: result.proteinG,
      goalCarbs: result.carbsG,
      goalFats: result.fatG,
      goalFiber: result.fiberG,
      goalWaterMl: result.waterMl,
      bmr: result.bmr,
      maintenanceCalories: result.maintenanceCalories,
      goalType: result.goalType,
      activityLevel: result.activityLevel,
      formulaVersion: result.formulaVersion,
      plannerAge: age,
      plannerGender: gender,
      plannerHeightCm: heightCm,
      currentWeightKg: result.currentWeightKg,
      targetWeightKg: result.targetWeightKg,
      timelineDays: result.timelineDays,
      weeklyChangeKg: result.weeklyChangeKg,
      savedAt: DateTime.now(),
    );
  }
}

/// Device storage for nutrition planner targets and diet preference.
class NutritionPlannerLocalStorage {
  static const _keyDietPreference = 'nutrition_planner_diet_preference';
  static const _keySavedState = 'nutrition_planner_saved_state';

  Future<DietPreference> getDietPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return DietPreference.fromValue(prefs.getString(_keyDietPreference));
  }

  Future<void> setDietPreference(DietPreference diet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDietPreference, diet.value);
  }

  Future<SavedNutritionPlannerState?> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySavedState);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SavedNutritionPlannerState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlannerState(SavedNutritionPlannerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedState, jsonEncode(state.toJson()));
  }

  Future<NutritionGoals> loadMealTrackerGoals() async {
    final saved = await loadSavedState();
    if (saved != null) return saved.toNutritionGoals();
    return const NutritionGoals();
  }

  Future<void> saveMealTrackerGoals(NutritionGoals goals) async {
    final existing = await loadSavedState();
    final now = DateTime.now();
    final state = existing != null
        ? SavedNutritionPlannerState(
            goalCalories: goals.goalCalories,
            goalProtein: goals.goalProtein,
            goalCarbs: goals.goalCarbs,
            goalFats: goals.goalFats,
            goalFiber: goals.goalFiber,
            goalWaterMl: goals.goalWaterMl ?? existing.goalWaterMl,
            bmr: existing.bmr,
            maintenanceCalories: existing.maintenanceCalories,
            goalType: existing.goalType,
            activityLevel: existing.activityLevel,
            formulaVersion: existing.formulaVersion,
            plannerAge: existing.plannerAge,
            plannerGender: existing.plannerGender,
            plannerHeightCm: existing.plannerHeightCm,
            currentWeightKg: existing.currentWeightKg,
            targetWeightKg: existing.targetWeightKg,
            timelineDays: existing.timelineDays,
            weeklyChangeKg: existing.weeklyChangeKg,
            savedAt: now,
          )
        : SavedNutritionPlannerState(
            goalCalories: goals.goalCalories,
            goalProtein: goals.goalProtein,
            goalCarbs: goals.goalCarbs,
            goalFats: goals.goalFats,
            goalFiber: goals.goalFiber,
            goalWaterMl: goals.goalWaterMl ?? 2500,
            bmr: 0,
            maintenanceCalories: 0,
            goalType: 'maintenance',
            activityLevel: 'moderately_active',
            formulaVersion: 'mifflin_st_jeor_v1',
            plannerAge: 25,
            plannerGender: 'Male',
            plannerHeightCm: 170,
            currentWeightKg: 70,
            targetWeightKg: 70,
            timelineDays: 84,
            weeklyChangeKg: 0,
            savedAt: now,
          );
    await savePlannerState(state);
  }
}
