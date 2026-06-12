import '../services/nutrition_goal_calculator.dart';
import '../services/nutrition_planner_local_storage.dart';
import '../services/user_goals_service.dart';

/// Loads saved planner data + persists targets to device storage.
class NutritionGoalPlannerRepository {
  final NutritionPlannerLocalStorage _localStorage;
  final UserGoalsService _goalsService;

  NutritionGoalPlannerRepository({
    NutritionPlannerLocalStorage? localStorage,
    UserGoalsService? goalsService,
  })  : _localStorage = localStorage ?? NutritionPlannerLocalStorage(),
        _goalsService = goalsService ?? UserGoalsService();

  Future<PlannerProfileSnapshot> loadProfileSnapshot() async {
    final saved = await _localStorage.loadSavedState();
    if (saved == null) return const PlannerProfileSnapshot();

    return PlannerProfileSnapshot(
      age: saved.plannerAge,
      gender: saved.plannerGender,
      heightCm: saved.plannerHeightCm,
      weightKg: saved.currentWeightKg,
      targetWeightKg: saved.targetWeightKg,
      timelineDays: saved.timelineDays,
      goalType: saved.goalType,
      activityLevel: saved.activityLevel,
    );
  }

  Future<DietPreference> loadDietPreference() =>
      _localStorage.getDietPreference();

  Future<void> saveDietPreference(DietPreference diet) =>
      _localStorage.setDietPreference(diet);

  /// Saves planner output to device storage for Meal Tracker.
  Future<void> saveActiveGoal({
    required NutritionGoalResult result,
    required int age,
    required String gender,
    required double heightCm,
  }) async {
    final state = SavedNutritionPlannerState.fromResult(
      result: result,
      age: age,
      gender: gender,
      heightCm: heightCm,
    );
    await _localStorage.savePlannerState(state);
    await _goalsService.setWaterGoal(result.waterMl / 1000.0);
    await _goalsService.setCaloriesGoal(result.calories);
  }
}

class PlannerProfileSnapshot {
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final int? timelineDays;
  final String? goalType;
  final String? activityLevel;

  const PlannerProfileSnapshot({
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.timelineDays,
    this.goalType,
    this.activityLevel,
  });
}
