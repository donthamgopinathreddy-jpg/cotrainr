import 'package:supabase_flutter/supabase_flutter.dart';

class SavedMealsException implements Exception {
  final String message;
  SavedMealsException(this.message);
  @override
  String toString() => message;
}

class SavedMealItemDraft {
  final String foodName;
  final double quantity;
  final String unit;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String? foodId;

  const SavedMealItemDraft({
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.foodId,
  });
}

class SavedMealItem {
  final String id;
  final String foodName;
  final double quantity;
  final String unit;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String? foodId;
  final int sortOrder;

  const SavedMealItem({
    required this.id,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.foodId,
    this.sortOrder = 0,
  });

  SavedMealItemDraft toDraft() => SavedMealItemDraft(
        foodName: foodName,
        quantity: quantity,
        unit: unit,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: fiber,
        foodId: foodId,
      );
}

class SavedMeal {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SavedMealItem> items;

  const SavedMeal({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  int get totalCalories => items.fold(0, (s, i) {
        final factor = _factor(i.unit, i.quantity);
        return s + (i.calories * factor).round();
      });

  static double _factor(String unit, double quantity) {
    final m = RegExp(r'(\d+)\s*g', caseSensitive: false).firstMatch(unit);
    if (m != null) {
      final base = double.tryParse(m.group(1) ?? '') ?? 100;
      if (base > 0) return quantity / base;
    }
    return quantity;
  }
}

class SavedMealsRepository {
  final SupabaseClient _supabase;

  SavedMealsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<List<SavedMeal>> listSavedMeals() async {
    if (_uid == null) throw SavedMealsException('Sign in to view saved meals');
    try {
      final mealsRes = await _supabase
          .from('saved_meals')
          .select('id, name, created_at, updated_at')
          .eq('user_id', _uid!)
          .order('updated_at', ascending: false);

      final meals = (mealsRes as List).cast<Map<String, dynamic>>();
      if (meals.isEmpty) return [];

      final ids = meals.map((m) => m['id'] as String).toList();
      final itemsRes = await _supabase
          .from('saved_meal_items')
          .select(
            'id, saved_meal_id, food_name, quantity, unit, calories, protein, carbs, fat, fiber, food_id, sort_order',
          )
          .inFilter('saved_meal_id', ids)
          .order('sort_order');

      final items = (itemsRes as List).cast<Map<String, dynamic>>();
      final byMeal = <String, List<SavedMealItem>>{};
      for (final row in items) {
        final mealId = row['saved_meal_id'] as String;
        byMeal.putIfAbsent(mealId, () => []).add(_itemFromRow(row));
      }

      return meals
          .map(
            (m) => SavedMeal(
              id: m['id'] as String,
              name: m['name'] as String,
              createdAt: DateTime.parse(m['created_at'] as String),
              updatedAt: DateTime.parse(m['updated_at'] as String),
              items: byMeal[m['id'] as String] ?? const [],
            ),
          )
          .toList();
    } catch (e) {
      throw SavedMealsException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<SavedMeal> createSavedMeal({
    required String name,
    required List<SavedMealItemDraft> items,
  }) async {
    if (_uid == null) throw SavedMealsException('Sign in to save meals');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw SavedMealsException('Enter a meal name');
    if (items.isEmpty) throw SavedMealsException('Add at least one food');

    try {
      final mealRow = await _supabase
          .from('saved_meals')
          .insert({
            'user_id': _uid,
            'name': trimmed,
          })
          .select('id, name, created_at, updated_at')
          .single();

      final mealId = mealRow['id'] as String;
      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final row = <String, dynamic>{
          'saved_meal_id': mealId,
          'food_name': it.foodName,
          'quantity': it.quantity,
          'unit': it.unit,
          'calories': it.calories,
          'protein': it.protein,
          'carbs': it.carbs,
          'fat': it.fat,
          'fiber': it.fiber,
          'sort_order': i,
        };
        if (it.foodId != null) row['food_id'] = it.foodId;
        payload.add(row);
      }

      final inserted = await _supabase
          .from('saved_meal_items')
          .insert(payload)
          .select(
            'id, saved_meal_id, food_name, quantity, unit, calories, protein, carbs, fat, fiber, food_id, sort_order',
          );

      return SavedMeal(
        id: mealId,
        name: mealRow['name'] as String,
        createdAt: DateTime.parse(mealRow['created_at'] as String),
        updatedAt: DateTime.parse(mealRow['updated_at'] as String),
        items: (inserted as List)
            .cast<Map<String, dynamic>>()
            .map(_itemFromRow)
            .toList(),
      );
    } catch (e) {
      throw SavedMealsException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> renameSavedMeal(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw SavedMealsException('Enter a meal name');
    try {
      await _supabase.from('saved_meals').update({
        'name': trimmed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw SavedMealsException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> replaceSavedMealItems({
    required String mealId,
    required String name,
    required List<SavedMealItemDraft> items,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw SavedMealsException('Enter a meal name');
    if (items.isEmpty) throw SavedMealsException('Add at least one food');
    try {
      await _supabase.from('saved_meals').update({
        'name': trimmed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', mealId);

      await _supabase.from('saved_meal_items').delete().eq('saved_meal_id', mealId);

      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final row = <String, dynamic>{
          'saved_meal_id': mealId,
          'food_name': it.foodName,
          'quantity': it.quantity,
          'unit': it.unit,
          'calories': it.calories,
          'protein': it.protein,
          'carbs': it.carbs,
          'fat': it.fat,
          'fiber': it.fiber,
          'sort_order': i,
        };
        if (it.foodId != null) row['food_id'] = it.foodId;
        payload.add(row);
      }
      await _supabase.from('saved_meal_items').insert(payload);
    } catch (e) {
      throw SavedMealsException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> deleteSavedMeal(String id) async {
    try {
      await _supabase.from('saved_meals').delete().eq('id', id);
    } catch (e) {
      throw SavedMealsException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  SavedMealItem _itemFromRow(Map<String, dynamic> row) {
    return SavedMealItem(
      id: row['id'] as String,
      foodName: row['food_name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String,
      calories: ((row['calories'] as num?)?.toDouble() ?? 0).round(),
      protein: (row['protein'] as num?)?.toDouble() ?? 0,
      carbs: (row['carbs'] as num?)?.toDouble() ?? 0,
      fat: (row['fat'] as num?)?.toDouble() ?? 0,
      fiber: (row['fiber'] as num?)?.toDouble() ?? 0,
      foodId: row['food_id'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
