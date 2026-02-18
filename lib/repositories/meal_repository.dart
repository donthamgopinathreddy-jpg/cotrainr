import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Nutrition goals for current user.
class NutritionGoals {
  final int goalCalories;
  final int goalProtein;
  final int goalCarbs;
  final int goalFats;
  final int goalFiber;

  const NutritionGoals({
    this.goalCalories = 2000,
    this.goalProtein = 150,
    this.goalCarbs = 200,
    this.goalFats = 65,
    this.goalFiber = 30,
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

  MealRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Format date as YYYY-MM-DD (user's local date for day bucketing).
  static String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Fetch meals + items for a given day. Returns data shaped for MealTrackerPageV2.
  Future<DayMealsData> getDayMeals(DateTime date) async {
    if (_currentUserId == null) return DayMealsData.empty();

    try {
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
      print('MealRepository.getDayMeals: $e');
      return DayMealsData.empty();
    }
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

  /// Fetch nutrition goals. Creates defaults row if missing (upsert).
  Future<NutritionGoals> getNutritionGoals() async {
    if (_currentUserId == null) {
      return const NutritionGoals();
    }

    try {
      final res = await _supabase
          .from('nutrition_goals')
          .select('goal_calories, goal_protein, goal_carbs, goal_fats, goal_fiber')
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      if (res != null) {
        return NutritionGoals(
          goalCalories: (res['goal_calories'] as num?)?.toInt() ?? 2000,
          goalProtein: (res['goal_protein'] as num?)?.toInt() ?? 150,
          goalCarbs: (res['goal_carbs'] as num?)?.toInt() ?? 200,
          goalFats: (res['goal_fats'] as num?)?.toInt() ?? 65,
          goalFiber: (res['goal_fiber'] as num?)?.toInt() ?? 30,
        );
      }
      // Insert defaults row when missing
      await _supabase.from('nutrition_goals').upsert(
        {
          'user_id': _currentUserId!,
          'goal_calories': 2000,
          'goal_protein': 150,
          'goal_carbs': 200,
          'goal_fats': 65,
          'goal_fiber': 30,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      return const NutritionGoals();
    } catch (e) {
      print('MealRepository.getNutritionGoals: $e');
      return const NutritionGoals();
    }
  }

  /// Upsert nutrition goals.
  Future<void> upsertNutritionGoals(NutritionGoals goals) async {
    if (_currentUserId == null) return;

    try {
      await _supabase.from('nutrition_goals').upsert(
        {
          'user_id': _currentUserId!,
          'goal_calories': goals.goalCalories,
          'goal_protein': goals.goalProtein,
          'goal_carbs': goals.goalCarbs,
          'goal_fats': goals.goalFats,
          'goal_fiber': goals.goalFiber,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
    } catch (e) {
      print('MealRepository.upsertNutritionGoals: $e');
      rethrow;
    }
  }

  /// Ensure meal row exists for (user, date, meal_type). Returns meal id.
  /// Uses upsert to avoid race: concurrent inserts become no-op update, return existing id.
  Future<String> _ensureMeal(DateTime date, String mealType) async {
    if (_currentUserId == null) throw StateError('Not authenticated');

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
      // Unique violation or conflict: refetch existing row
      final existing = await _supabase
          .from('meals')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('consumed_date', dateStr)
          .eq('meal_type', mealType)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;
      rethrow;
    }
  }

  /// Add food item. Ensures meal exists, inserts meal_item with fiber.
  /// [calories, protein, carbs, fats, fiber] are per-unit values.
  /// Normalizes unit/quantity before insert (e.g. "0.5x" → "1x", quantity 0.5) to avoid double-multiply.
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
  }) async {
    final mealId = await _ensureMeal(date, mealType);
    final normalized = normalizeUnitForStorage(unit, quantity);

    final insert = await _supabase.from('meal_items').insert({
      'meal_id': mealId,
      'food_name': foodName,
      'quantity': normalized.quantity,
      'unit': normalized.unit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fats,
      'fiber': fiber,
    }).select('id').single();

    return insert['id'] as String;
  }

  /// Update food item amount (quantity).
  Future<void> updateFoodItemAmount(String mealItemId, double quantity) async {
    await _supabase
        .from('meal_items')
        .update({'quantity': quantity})
        .eq('id', mealItemId);
  }

  /// Delete food item.
  Future<void> deleteFoodItem(String mealItemId) async {
    await _supabase.from('meal_items').delete().eq('id', mealItemId);
  }

  /// Weekly aggregates for 7 days ending on [endDate] (inclusive).
  Future<List<DayAggregate>> getWeeklyAggregates(DateTime endDate) async {
    if (_currentUserId == null) return [];

    try {
      final start = DateTime(endDate.year, endDate.month, endDate.day)
          .subtract(const Duration(days: 6));
      final startStr = _dateString(start);
      final endStr = _dateString(endDate);

      final mealsRes = await _supabase
          .from('meals')
          .select('id, consumed_date')
          .eq('user_id', _currentUserId!)
          .gte('consumed_date', startStr)
          .lte('consumed_date', endStr);

      final mealsList = (mealsRes as List).cast<Map<String, dynamic>>();
      if (mealsList.isEmpty) {
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

      final mealIds = mealsList.map((m) => m['id'] as String).toList();
      final itemsRes = await _supabase
          .from('meal_items')
          .select('meal_id, quantity, unit, calories, protein, carbs, fat, fiber')
          .inFilter('meal_id', mealIds);

      final itemsList = (itemsRes as List).cast<Map<String, dynamic>>();
      final mealIdToDate = {
        for (final m in mealsList) m['id'] as String: m['consumed_date'] as String
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
        final fi = (item['fiber'] as num?)?.toDouble() ?? 0;

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
    } catch (e) {
      print('MealRepository.getWeeklyAggregates: $e');
      return [];
    }
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
