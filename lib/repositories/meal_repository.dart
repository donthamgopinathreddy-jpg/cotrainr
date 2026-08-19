import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/nutrition_planner_local_storage.dart';
import '../services/recent_foods_logic.dart';

class MealRepositoryException implements Exception {
  final String message;
  MealRepositoryException(this.message);
  @override
  String toString() => message;
}

bool _isMissingColumnError(Object e, String column) {
  final s = e.toString().toLowerCase();
  return s.contains(column.toLowerCase()) &&
      (s.contains('column') ||
          s.contains('42703') ||
          s.contains('does not exist') ||
          s.contains('schema cache'));
}

bool _isPermissionError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('42501') ||
      s.contains('permission denied') ||
      s.contains('row-level security');
}

bool _isProfilesPermissionError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('profiles') &&
      (s.contains('42501') || s.contains('permission denied'));
}

String _permissionDeniedMessage(Object e, {required String fallback}) {
  if (_isProfilesPermissionError(e)) {
    return 'Meal access blocked by a DB policy on profiles. '
        'Apply supabase/migrations/20260731_fix_meal_rls_profiles_join.sql';
  }
  return fallback;
}

/// Day data for meal tracker: meals grouped by meal_type with items and daily totals.
class DayMealsData {
  final Map<String, List<MealItemRow>> mealsByType;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final double totalFiber;

  const DayMealsData({
    required this.mealsByType,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.totalFiber,
  });

  factory DayMealsData.empty() => DayMealsData(
        mealsByType: {},
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFats: 0,
        totalFiber: 0,
      );

  int get loggedItemCount =>
      mealsByType.values.fold(0, (sum, items) => sum + items.length);

  bool get hasLoggedMeals => loggedItemCount > 0;
}

/// Single food item from DB (maps to FoodItem in UI).
class MealItemRow {
  final String id;
  final String foodName;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const MealItemRow({
    required this.id,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  /// UI uses 'fats', DB uses 'fat'.
  double get fats => fat;

  int get caloriesInt => calories.round();
}

/// One Recent food derived from the user's meal history (deduped).
class RecentFoodItem {
  final String? foodId;
  final String foodName;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final DateTime lastUsedAt;

  const RecentFoodItem({
    this.foodId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    required this.lastUsedAt,
  });

  double get fats => fat;
  int get caloriesInt => calories.round();
}

/// Nutrition goals for current user.
class NutritionGoals {
  final int goalCalories;
  final int goalProtein;
  final int goalCarbs;
  final int goalFats;
  final int goalFiber;
  final int? goalWaterMl;

  const NutritionGoals({
    this.goalCalories = 2000,
    this.goalProtein = 150,
    this.goalCarbs = 200,
    this.goalFats = 65,
    this.goalFiber = 30,
    this.goalWaterMl,
  });
}

/// Per-day aggregates for weekly insights.
class DayAggregate {
  final DateTime date;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;

  const DayAggregate({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
  });
}

/// Repository for meal tracker: meals, meal_items, nutrition_goals.
class MealRepository {
  final SupabaseClient _supabase;
  final NutritionPlannerLocalStorage _plannerStorage;

  MealRepository({
    SupabaseClient? supabase,
    NutritionPlannerLocalStorage? plannerStorage,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _plannerStorage = plannerStorage ?? NutritionPlannerLocalStorage();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Format date as YYYY-MM-DD (user's local date for day bucketing).
  static String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Recent foods derived from this user's meal_items (newest first, deduped).
  /// No dedicated recent table — uses historical logs only.
  Future<List<RecentFoodItem>> getRecentFoods({int limit = 30}) async {
    if (_currentUserId == null) {
      throw MealRepositoryException('Sign in to load recent foods');
    }
    try {
      return await _fetchRecentFoods(limit: limit, includeFiber: true);
    } catch (e) {
      if (_isMissingColumnError(e, 'fiber')) {
        return _fetchRecentFoods(limit: limit, includeFiber: false);
      }
      if (_isMissingColumnError(e, 'food_id')) {
        return _fetchRecentFoods(
          limit: limit,
          includeFiber: true,
          includeFoodId: false,
        );
      }
      if (_isPermissionError(e)) {
        throw MealRepositoryException(
          _permissionDeniedMessage(
            e,
            fallback: 'Permission denied reading recent foods.',
          ),
        );
      }
      throw MealRepositoryException('Could not load recent foods: $e');
    }
  }

  Future<List<RecentFoodItem>> _fetchRecentFoods({
    required int limit,
    required bool includeFiber,
    bool includeFoodId = true,
  }) async {
    final foodIdCol = includeFoodId ? ', food_id' : '';
    final fiberCol = includeFiber ? ', fiber' : '';
    final select =
        'food_name, quantity, unit, calories, protein, carbs, fat$fiberCol$foodIdCol, created_at, meals!inner(user_id)';

    final res = await _supabase
        .from('meal_items')
        .select(select)
        .eq('meals.user_id', _currentUserId!)
        .order('created_at', ascending: false)
        .limit(200);

    final rows = (res as List).cast<Map<String, dynamic>>();
    final mapped = rows.map((row) {
      final created = row['created_at'];
      return RecentFoodItem(
        foodId: includeFoodId ? row['food_id'] as String? : null,
        foodName: row['food_name'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        unit: row['unit'] as String,
        calories: (row['calories'] as num?)?.toDouble() ?? 0,
        protein: (row['protein'] as num?)?.toDouble() ?? 0,
        carbs: (row['carbs'] as num?)?.toDouble() ?? 0,
        fat: (row['fat'] as num?)?.toDouble() ?? 0,
        fiber: includeFiber ? ((row['fiber'] as num?)?.toDouble() ?? 0) : 0,
        lastUsedAt: created is String
            ? DateTime.tryParse(created) ?? DateTime.now()
            : (created is DateTime ? created : DateTime.now()),
      );
    });

    return dedupeRecentFoodsByKey(
      newestFirst: mapped,
      dedupeKey: (item) => recentFoodDedupeKey(
        foodId: item.foodId,
        foodName: item.foodName,
      ),
      limit: limit,
    );
  }

  /// Fetch meals + items for a given day. Returns data shaped for MealTrackerPageV2.
  /// Throws [MealRepositoryException] on auth/schema/permission failures (not silent empty).
  Future<DayMealsData> getDayMeals(DateTime date) async {
    if (_currentUserId == null) {
      throw MealRepositoryException('Sign in to load meals');
    }

    try {
      return await _fetchDayMeals(date, includeFiber: true);
    } catch (e) {
      if (_isMissingColumnError(e, 'fiber')) {
        if (kDebugMode) {
          debugPrint('MealRepository.getDayMeals: retry without fiber — $e');
        }
        return _fetchDayMeals(date, includeFiber: false);
      }
      if (_isMissingColumnError(e, 'consumed_date')) {
        throw MealRepositoryException(
          'Meal tracker DB needs update (consumed_date). '
          'Apply supabase/migrations/20250215_meal_tracker_supabase.sql',
        );
      }
      if (_isPermissionError(e)) {
        throw MealRepositoryException(
          _permissionDeniedMessage(
            e,
            fallback:
                'Permission denied reading meals. Check RLS/grants on meals & meal_items.',
          ),
        );
      }
      debugPrint('MealRepository.getDayMeals: $e');
      throw MealRepositoryException('Could not load meals: $e');
    }
  }

  Future<DayMealsData> _fetchDayMeals(
    DateTime date, {
    required bool includeFiber,
  }) async {
    final dateStr = _dateString(date);
    final mealsRes = await _supabase
        .from('meals')
        .select('id, meal_type')
        .eq('user_id', _currentUserId!)
        .eq('consumed_date', dateStr)
        .order('meal_type');

    final mealsList = mealsRes as List;
    if (mealsList.isEmpty) return DayMealsData.empty();

    final mealIds = mealsList.map((m) => m['id'] as String).toList();
    final selectCols = includeFiber
        ? 'id, meal_id, food_name, quantity, unit, calories, protein, carbs, fat, fiber'
        : 'id, meal_id, food_name, quantity, unit, calories, protein, carbs, fat';
    final itemsRes = await _supabase
        .from('meal_items')
        .select(selectCols)
        .inFilter('meal_id', mealIds);

    final itemsList = (itemsRes as List).cast<Map<String, dynamic>>();
    final mealIdToType = {
      for (final m in mealsList) m['id'] as String: m['meal_type'] as String
    };

    final mealsByType = <String, List<MealItemRow>>{};
    int totalCal = 0;
    double totalP = 0, totalC = 0, totalF = 0, totalFi = 0;

    for (final item in itemsList) {
      final mealId = item['meal_id'] as String;
      final mealType = mealIdToType[mealId] ?? 'Other';
      final row = MealItemRow(
        id: item['id'] as String,
        foodName: item['food_name'] as String,
        quantity: (item['quantity'] as num).toDouble(),
        unit: item['unit'] as String,
        calories: (item['calories'] as num?)?.toDouble() ?? 0,
        protein: (item['protein'] as num?)?.toDouble() ?? 0,
        carbs: (item['carbs'] as num?)?.toDouble() ?? 0,
        fat: (item['fat'] as num?)?.toDouble() ?? 0,
        fiber: includeFiber
            ? ((item['fiber'] as num?)?.toDouble() ?? 0)
            : 0,
      );
      final factor = _factorForUnit(row.unit, row.quantity);
      totalCal += (row.calories * factor).round();
      totalP += row.protein * factor;
      totalC += row.carbs * factor;
      totalF += row.fat * factor;
      totalFi += row.fiber * factor;

      mealsByType.putIfAbsent(mealType, () => []).add(row);
    }

    return DayMealsData(
      mealsByType: mealsByType,
      totalCalories: totalCal,
      totalProtein: totalP,
      totalCarbs: totalC,
      totalFats: totalF,
      totalFiber: totalFi,
    );
  }

  /// Fetch meals for a client (coach only - requires accepted lead, RLS enforces)
  Future<DayMealsData> getClientDayMeals(String clientId, DateTime date) async {
    if (_currentUserId == null) return DayMealsData.empty();
    try {
      final dateStr = _dateString(date);
      final mealsRes = await _supabase
          .from('meals')
          .select('id, meal_type')
          .eq('user_id', clientId)
          .eq('consumed_date', dateStr)
          .order('meal_type');

      final mealsList = mealsRes as List;
      if (mealsList.isEmpty) return DayMealsData.empty();

      final mealIds = mealsList.map((m) => m['id'] as String).toList();
      final itemsRes = await _supabase
          .from('meal_items')
          .select('id, meal_id, food_name, quantity, unit, calories, protein, carbs, fat, fiber')
          .inFilter('meal_id', mealIds);

      final itemsList = (itemsRes as List).cast<Map<String, dynamic>>();
      final mealIdToType = {
        for (final m in mealsList) m['id'] as String: m['meal_type'] as String
      };

      final mealsByType = <String, List<MealItemRow>>{};
      int totalCal = 0;
      double totalP = 0, totalC = 0, totalF = 0, totalFi = 0;

      for (final item in itemsList) {
        final mealId = item['meal_id'] as String;
        final mealType = mealIdToType[mealId] ?? 'Other';
        final row = MealItemRow(
          id: item['id'] as String,
          foodName: item['food_name'] as String,
          quantity: (item['quantity'] as num).toDouble(),
          unit: item['unit'] as String,
          calories: (item['calories'] as num?)?.toDouble() ?? 0,
          protein: (item['protein'] as num?)?.toDouble() ?? 0,
          carbs: (item['carbs'] as num?)?.toDouble() ?? 0,
          fat: (item['fat'] as num?)?.toDouble() ?? 0,
          fiber: (item['fiber'] as num?)?.toDouble() ?? 0,
        );
        final factor = _factorForUnit(row.unit, row.quantity);
        totalCal += (row.calories * factor).round();
        totalP += row.protein * factor;
        totalC += row.carbs * factor;
        totalF += row.fat * factor;
        totalFi += row.fiber * factor;

        mealsByType.putIfAbsent(mealType, () => []).add(row);
      }

      return DayMealsData(
        mealsByType: mealsByType,
        totalCalories: totalCal,
        totalProtein: totalP,
        totalCarbs: totalC,
        totalFats: totalF,
        totalFiber: totalFi,
      );
    } catch (e) {
      print('MealRepository.getClientDayMeals: $e');
      return DayMealsData.empty();
    }
  }

  /// Compute factor for macro totals. Normalized units only:
  /// - Gram-based ("100g", "50 g"): quantity = grams, factor = quantity / base.
  /// - Serving/multiplier ("1x", "1 medium"): quantity = count, factor = quantity.
  /// Use [normalizeUnitForStorage] before insert to avoid double-multiply (e.g. "0.5x" → "1x", q*=0.5).
  double _factorForUnit(String unit, double quantity) {
    final gramMatch = RegExp(r'(\d+)\s*g', caseSensitive: false).firstMatch(unit);
    if (gramMatch != null) {
      final base = int.tryParse(gramMatch.group(1) ?? '');
      if (base != null && base > 0) return quantity / base;
    }
    return quantity; // Serving/multiplier: factor = quantity
  }

  /// Normalize unit before storing to prevent double-multiply.
  ///
  /// **Invariant:** Unit is always a base unit; quantity is the multiplier or grams.
  /// - Gram-based: `"100g"`, `"50 g"` — quantity = grams consumed. Unchanged.
  /// - Serving-based: `"1 medium"`, `"1x"` — quantity = count (0.5, 1, 2). Unchanged.
  /// - Multiplier-in-unit: `"0.5x"`, `"2x"` — quantity MUST be 1 for correct scaling.
  ///   Store as `"1x"` with quantity = N. If quantity != 1, assume UI already scaled (release-safe).
  ///
  /// **Examples:**
  /// - `"0.5x"`, qty=1 → `"1x"`, qty=0.5
  /// - `"2x"`, qty=1 → `"1x"`, qty=2
  /// - `"0.5x"`, qty=2 → debug: assert fails; release: `"1x"`, qty=2 (assume already scaled)
  /// - `"100g"`, qty=150 → unchanged
  /// - `"1 medium"`, qty=2 → unchanged
  ({String unit, double quantity}) normalizeUnitForStorage(String unit, double quantity) {
    final multMatch = RegExp(r'^(\d*\.?\d+)\s*x$', caseSensitive: false).firstMatch(unit.trim());
    if (multMatch != null) {
      final m = double.tryParse(multMatch.group(1) ?? '');
      if (m != null && m != 1.0) {
        if (quantity != 1.0) {
          assert(
            quantity == 1.0,
            'MealRepository invariant violated: unit="$unit" but quantity=$quantity. '
            'Expected quantity=1.0 for Nx units to avoid double scaling.',
          );
          // Release-safe: assume quantity already includes scaling; do not multiply by N
          return (unit: '1x', quantity: quantity);
        }
        return (unit: '1x', quantity: quantity * m);
      }
    }
    return (unit: unit, quantity: quantity);
  }

  /// Fetch nutrition goals from device storage (Nutrition Goal Planner).
  Future<NutritionGoals> getNutritionGoals() async {
    try {
      return await _plannerStorage.loadMealTrackerGoals();
    } catch (e) {
      print('MealRepository.getNutritionGoals: $e');
      return const NutritionGoals();
    }
  }

  /// Save nutrition goals to device storage.
  Future<void> upsertNutritionGoals(NutritionGoals goals) async {
    try {
      await _plannerStorage.saveMealTrackerGoals(goals);
    } catch (e) {
      print('MealRepository.upsertNutritionGoals: $e');
      rethrow;
    }
  }

  /// Ensure meal row exists for (user, date, meal_type). Returns meal id.
  Future<String> _ensureMeal(DateTime date, String mealType) async {
    if (_currentUserId == null) {
      throw MealRepositoryException('Not authenticated');
    }

    final dateStr = _dateString(date);
    final consumedAt = DateTime(date.year, date.month, date.day, 12, 0, 0);

    try {
      final result = await _supabase.from('meals').upsert(
        {
          'user_id': _currentUserId!,
          'meal_type': mealType,
          'consumed_at': consumedAt.toUtc().toIso8601String(),
          'consumed_date': dateStr,
        },
        onConflict: 'user_id,consumed_date,meal_type',
      ).select('id').single();
      return result['id'] as String;
    } catch (e) {
      if (_isMissingColumnError(e, 'consumed_date')) {
        throw MealRepositoryException(
          'Meal tracker DB needs update (consumed_date). '
          'Apply supabase/migrations/20250215_meal_tracker_supabase.sql',
        );
      }
      if (_isPermissionError(e)) {
        throw MealRepositoryException(
          _permissionDeniedMessage(
            e,
            fallback: 'Permission denied creating meal. Check RLS on meals.',
          ),
        );
      }
      try {
        final existing = await _supabase
            .from('meals')
            .select('id')
            .eq('user_id', _currentUserId!)
            .eq('consumed_date', dateStr)
            .eq('meal_type', mealType)
            .maybeSingle();
        if (existing != null) return existing['id'] as String;

        final inserted = await _supabase.from('meals').insert({
          'user_id': _currentUserId!,
          'meal_type': mealType,
          'consumed_at': consumedAt.toUtc().toIso8601String(),
          'consumed_date': dateStr,
        }).select('id').single();
        return inserted['id'] as String;
      } catch (e2) {
        if (_isPermissionError(e2)) {
          throw MealRepositoryException(
            _permissionDeniedMessage(
              e2,
              fallback: 'Permission denied creating meal. Check RLS on meals.',
            ),
          );
        }
        throw MealRepositoryException('Could not create meal: $e2');
      }
    }
  }

  /// Add food item. Ensures meal exists, inserts meal_item with fiber.
  Future<String> addFoodItem({
    required DateTime date,
    required String mealType,
    required String foodName,
    required double quantity,
    required String unit,
    required int calories,
    required double protein,
    required double carbs,
    required double fats,
    double fiber = 0,
    String? foodId,
  }) async {
    if (_currentUserId == null) {
      throw MealRepositoryException('Sign in to add food');
    }

    final mealId = await _ensureMeal(date, mealType);
    final normalized = normalizeUnitForStorage(unit, quantity);

    Future<String> insert(Map<String, dynamic> payload) async {
      final row = await _supabase
          .from('meal_items')
          .insert(payload)
          .select('id')
          .single();
      return row['id'] as String;
    }

    final base = <String, dynamic>{
      'meal_id': mealId,
      'food_name': foodName,
      'quantity': normalized.quantity,
      'unit': normalized.unit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fats,
      'fiber': fiber,
    };
    if (foodId != null) base['food_id'] = foodId;

    try {
      return await insert(base);
    } catch (e) {
      if (foodId != null &&
          (_isMissingColumnError(e, 'food_id') ||
              e.toString().toLowerCase().contains('foreign key'))) {
        final withoutFoodId = Map<String, dynamic>.from(base)..remove('food_id');
        try {
          return await insert(withoutFoodId);
        } catch (e2) {
          if (_isMissingColumnError(e2, 'fiber')) {
            withoutFoodId.remove('fiber');
            return insert(withoutFoodId);
          }
          rethrow;
        }
      }
      if (_isMissingColumnError(e, 'fiber')) {
        final withoutFiber = Map<String, dynamic>.from(base)..remove('fiber');
        return insert(withoutFiber);
      }
      if (_isPermissionError(e)) {
        throw MealRepositoryException(
          _permissionDeniedMessage(
            e,
            fallback: 'Permission denied adding food. Check RLS on meal_items.',
          ),
        );
      }
      throw MealRepositoryException('Failed to add food: $e');
    }
  }

  /// Update food item amount (quantity).
  Future<void> updateFoodItemAmount(String mealItemId, double quantity) async {
    await updateFoodItem(mealItemId: mealItemId, quantity: quantity);
  }

  /// Update a logged food item (serving, name, or per-unit macros).
  Future<void> updateFoodItem({
    required String mealItemId,
    double? quantity,
    String? foodName,
    String? unit,
    int? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? fiber,
  }) async {
    final updates = <String, dynamic>{};
    if (foodName != null) updates['food_name'] = foodName;
    if (calories != null) updates['calories'] = calories;
    if (protein != null) updates['protein'] = protein;
    if (carbs != null) updates['carbs'] = carbs;
    if (fats != null) updates['fat'] = fats;
    if (fiber != null) updates['fiber'] = fiber;

    if (quantity != null) {
      if (unit != null) {
        final normalized = normalizeUnitForStorage(unit, quantity);
        updates['unit'] = normalized.unit;
        updates['quantity'] = normalized.quantity;
      } else {
        updates['quantity'] = quantity;
      }
    } else if (unit != null) {
      updates['unit'] = unit;
    }

    if (updates.isEmpty) return;

    await _supabase.from('meal_items').update(updates).eq('id', mealItemId);
  }

  /// Delete food item.
  Future<void> deleteFoodItem(String mealItemId) async {
    await _supabase.from('meal_items').delete().eq('id', mealItemId);
  }

  List<DayAggregate> _emptyWeek(DateTime start) {
    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return DayAggregate(
        date: d,
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
        fiber: 0,
      );
    });
  }

  String _normalizeDateKey(Object? raw) {
    final s = raw?.toString() ?? '';
    return s.split('T').first;
  }

  /// Weekly aggregates for 7 days ending on [endDate] (inclusive).
  /// Always returns 7 entries (zeros on auth/error) so UI never hangs on length checks.
  Future<List<DayAggregate>> getWeeklyAggregates(DateTime endDate) async {
    final start = DateTime(endDate.year, endDate.month, endDate.day)
        .subtract(const Duration(days: 6));
    if (_currentUserId == null) return _emptyWeek(start);

    try {
      return await _fetchWeeklyAggregates(start, endDate, includeFiber: true);
    } catch (e) {
      if (_isMissingColumnError(e, 'fiber')) {
        try {
          return await _fetchWeeklyAggregates(start, endDate, includeFiber: false);
        } catch (e2) {
          print('MealRepository.getWeeklyAggregates: $e2');
          return _emptyWeek(start);
        }
      }
      print('MealRepository.getWeeklyAggregates: $e');
      return _emptyWeek(start);
    }
  }

  Future<List<DayAggregate>> _fetchWeeklyAggregates(
    DateTime start,
    DateTime endDate, {
    required bool includeFiber,
  }) async {
    final startStr = _dateString(start);
    final endStr = _dateString(endDate);

    final mealsRes = await _supabase
        .from('meals')
        .select('id, consumed_date')
        .eq('user_id', _currentUserId!)
        .gte('consumed_date', startStr)
        .lte('consumed_date', endStr);

    final mealsList = (mealsRes as List).cast<Map<String, dynamic>>();
    if (mealsList.isEmpty) return _emptyWeek(start);

    final mealIds = mealsList.map((m) => m['id'] as String).toList();
    final selectCols = includeFiber
        ? 'meal_id, quantity, unit, calories, protein, carbs, fat, fiber'
        : 'meal_id, quantity, unit, calories, protein, carbs, fat';
    final itemsRes = await _supabase
        .from('meal_items')
        .select(selectCols)
        .inFilter('meal_id', mealIds);

    final itemsList = (itemsRes as List).cast<Map<String, dynamic>>();
    final mealIdToDate = {
      for (final m in mealsList)
        m['id'] as String: _normalizeDateKey(m['consumed_date']),
    };

    final dateToTotals = <String, _DayTotals>{};
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      dateToTotals[_dateString(d)] = _DayTotals();
    }

    for (final item in itemsList) {
      final mealId = item['meal_id'] as String;
      final dateStr = mealIdToDate[mealId];
      if (dateStr == null || !dateToTotals.containsKey(dateStr)) continue;

      final quantity = (item['quantity'] as num).toDouble();
      final unit = item['unit'] as String;
      final factor = _factorForUnit(unit, quantity);
      final cal = (item['calories'] as num?)?.toDouble() ?? 0;
      final p = (item['protein'] as num?)?.toDouble() ?? 0;
      final c = (item['carbs'] as num?)?.toDouble() ?? 0;
      final f = (item['fat'] as num?)?.toDouble() ?? 0;
      final fi = includeFiber ? ((item['fiber'] as num?)?.toDouble() ?? 0) : 0.0;

      dateToTotals[dateStr]!.add(
        (cal * factor).round(),
        p * factor,
        c * factor,
        f * factor,
        fi * factor,
      );
    }

    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      final ds = _dateString(d);
      final t = dateToTotals[ds] ?? _DayTotals();
      return DayAggregate(
        date: d,
        calories: t.calories,
        protein: t.protein,
        carbs: t.carbs,
        fats: t.fats,
        fiber: t.fiber,
      );
    });
  }
}

class _DayTotals {
  int calories = 0;
  double protein = 0, carbs = 0, fats = 0, fiber = 0;

  void add(int c, double p, double carb, double f, double fi) {
    calories += c;
    protein += p;
    carbs += carb;
    fats += f;
    fiber += fi;
  }
}
