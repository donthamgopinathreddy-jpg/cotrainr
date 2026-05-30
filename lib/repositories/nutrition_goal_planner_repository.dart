import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_goal_calculator.dart';
import '../services/user_goals_service.dart';

/// Loads profile + saves planner output to nutrition_goals (meal tracker table).
class NutritionGoalPlannerRepository {
  final SupabaseClient _supabase;
  final UserGoalsService _goalsService;

  NutritionGoalPlannerRepository({
    SupabaseClient? supabase,
    UserGoalsService? goalsService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _goalsService = goalsService ?? UserGoalsService();

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<PlannerProfileSnapshot> loadProfileSnapshot() async {
    if (_userId == null) {
      return const PlannerProfileSnapshot();
    }
    try {
      final list =
          (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return const PlannerProfileSnapshot();

      final profile = list.first;
      final dobStr = profile['date_of_birth'] as String?;
      int? age;
      if (dobStr != null && dobStr.isNotEmpty) {
        try {
          final dob = DateTime.parse(dobStr);
          final now = DateTime.now();
          age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age = age - 1;
          }
        } catch (_) {}
      }

      return PlannerProfileSnapshot(
        age: age,
        gender: profile['gender'] as String?,
        heightCm: (profile['height_cm'] as num?)?.toDouble(),
        weightKg: (profile['weight_kg'] as num?)?.toDouble(),
      );
    } catch (_) {
      return const PlannerProfileSnapshot();
    }
  }

  /// Upserts the user's single nutrition_goals row (PK = user_id).
  /// Must use upsert with onConflict: user_id — not insert-only (one row per user).
  /// DB trigger trg_nutrition_goals_updated_at sets updated_at on UPDATE.
  Future<void> saveActiveGoal({
    required NutritionGoalResult result,
    required int age,
    required String gender,
    required double heightCm,
  }) async {
    if (_userId == null) throw StateError('Not authenticated');

    final now = DateTime.now().toIso8601String();
    await _supabase.from('nutrition_goals').upsert(
      {
        'user_id': _userId!,
        'goal_calories': result.calories,
        'goal_protein': result.proteinG,
        'goal_carbs': result.carbsG,
        'goal_fats': result.fatG,
        'goal_fiber': result.fiberG,
        'goal_water_ml': result.waterMl,
        'goal_type': result.goalType,
        'activity_level': result.activityLevel,
        'planner_age': age,
        'planner_gender': gender,
        'planner_height_cm': heightCm,
        'planner_weight_kg': result.currentWeightKg,
        'current_weight_kg': result.currentWeightKg,
        'target_weight_kg': result.targetWeightKg,
        'timeline_days': result.timelineDays,
        'timeline_weeks': (result.timelineDays / 7).ceil(),
        'weekly_change_kg': result.weeklyChangeKg,
        'maintenance_calories': result.maintenanceCalories,
        'bmr': result.bmr,
        'formula_version': result.formulaVersion,
        'is_active': true,
        'updated_at': now,
      },
      onConflict: 'user_id',
    );

    await _goalsService.setWaterGoal(result.waterMl / 1000.0);
    await _goalsService.setCaloriesGoal(result.calories);
  }
}

class PlannerProfileSnapshot {
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;

  const PlannerProfileSnapshot({
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
  });
}
