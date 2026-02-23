import 'package:supabase_flutter/supabase_flutter.dart';

/// Catalog food with per-100g nutrition. Macros are computed as (value_100g * grams / 100).
class CatalogFood {
  final String id;
  final String name;
  final double kcal100g;
  final double protein100g;
  final double carbs100g;
  final double fat100g;
  final double fiber100g;
  final bool verified;

  const CatalogFood({
    required this.id,
    required this.name,
    required this.kcal100g,
    required this.protein100g,
    required this.carbs100g,
    required this.fat100g,
    required this.fiber100g,
    required this.verified,
  });

  /// Compute macros for [grams] consumed.
  ({int calories, double protein, double carbs, double fats, double fiber}) macrosForGrams(double grams) {
    if (grams <= 0) return (calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0);
    final factor = grams / 100.0;
    return (
      calories: (kcal100g * factor).round(),
      protein: protein100g * factor,
      carbs: carbs100g * factor,
      fats: fat100g * factor,
      fiber: fiber100g * factor,
    );
  }
}

/// Saved portion (e.g. "1 cup" = 240g).
class FoodPortion {
  final String id;
  final String label;
  final double grams;
  final bool isDefault;

  const FoodPortion({
    required this.id,
    required this.label,
    required this.grams,
    required this.isDefault,
  });
}

/// Repository for food catalog: search foods, get portions.
class FoodCatalogRepository {
  final SupabaseClient _supabase;

  FoodCatalogRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Search foods by name. Returns catalog entries with per-100g nutrition.
  /// [verifiedOnly] restricts to verified foods when true.
  Future<List<CatalogFood>> searchFoods(String query, {bool verifiedOnly = false}) async {
    try {
      var q = _supabase
          .from('foods')
          .select('id, name, kcal_100g, protein_100g, carbs_100g, fat_100g, fiber_100g, verified');

      if (verifiedOnly) {
        q = q.eq('verified', true);
      }
      if (query.trim().isNotEmpty) {
        q = q.ilike('name', '%${query.trim()}%');
      }

      final res = await q.order('name').limit(50);
      final list = (res as List).cast<Map<String, dynamic>>();
      return list.map((r) => CatalogFood(
        id: r['id'] as String,
        name: r['name'] as String,
        kcal100g: (r['kcal_100g'] as num?)?.toDouble() ?? 0,
        protein100g: (r['protein_100g'] as num?)?.toDouble() ?? 0,
        carbs100g: (r['carbs_100g'] as num?)?.toDouble() ?? 0,
        fat100g: (r['fat_100g'] as num?)?.toDouble() ?? 0,
        fiber100g: (r['fiber_100g'] as num?)?.toDouble() ?? 0,
        verified: (r['verified'] as bool?) ?? false,
      )).toList();
    } catch (e) {
      // ignore: avoid_print
      print('FoodCatalogRepository.searchFoods: $e');
      return [];
    }
  }

  /// Get saved portions for a food.
  Future<List<FoodPortion>> getFoodPortions(String foodId) async {
    try {
      final res = await _supabase
          .from('food_portions')
          .select('id, label, grams, is_default')
          .eq('food_id', foodId)
          .order('grams');

      final list = (res as List).cast<Map<String, dynamic>>();
      return list.map((r) => FoodPortion(
        id: r['id'] as String,
        label: r['label'] as String,
        grams: (r['grams'] as num).toDouble(),
        isDefault: (r['is_default'] as bool?) ?? false,
      )).toList();
    } catch (e) {
      // ignore: avoid_print
      print('FoodCatalogRepository.getFoodPortions: $e');
      return [];
    }
  }
}
