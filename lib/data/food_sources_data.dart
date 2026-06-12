import '../services/nutrition_planner_local_storage.dart';

/// Macro category for food source suggestions.
enum FoodMacroCategory {
  protein,
  carbs,
  fats,
  fiber,
}

/// Diet classification for a food item.
enum FoodDietType {
  vegetarian('vegetarian', 'Vegetarian'),
  vegan('vegan', 'Vegan'),
  eggetarian('eggetarian', 'Eggetarian'),
  nonVeg('non_veg', 'Non-Veg');

  final String value;
  final String label;
  const FoodDietType(this.value, this.label);
}

/// Regional tag for a food item.
enum FoodRegion {
  indian('indian', 'Indian'),
  global('global', 'Global');

  final String value;
  final String label;
  const FoodRegion(this.value, this.label);
}

class FoodSource {
  final String name;
  final FoodMacroCategory category;
  final FoodDietType dietType;
  final FoodRegion region;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatsPer100g;
  final double fiberPer100g;
  final double sugarPer100g;

  const FoodSource({
    required this.name,
    required this.category,
    required this.dietType,
    required this.region,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatsPer100g,
    required this.fiberPer100g,
    required this.sugarPer100g,
  });

  double get mainMacroValue {
    switch (category) {
      case FoodMacroCategory.protein:
        return proteinPer100g;
      case FoodMacroCategory.carbs:
        return carbsPer100g;
      case FoodMacroCategory.fats:
        return fatsPer100g;
      case FoodMacroCategory.fiber:
        return fiberPer100g;
    }
  }

  String get mainMacroLabel {
    switch (category) {
      case FoodMacroCategory.protein:
        return '${proteinPer100g.toStringAsFixed(0)}g protein';
      case FoodMacroCategory.carbs:
        return '${carbsPer100g.toStringAsFixed(0)}g carbs';
      case FoodMacroCategory.fats:
        return '${fatsPer100g.toStringAsFixed(0)}g fats';
      case FoodMacroCategory.fiber:
        return '${fiberPer100g.toStringAsFixed(0)}g fiber';
    }
  }
}

/// Static local food suggestions — no API or database.
const List<FoodSource> kFoodSources = [
  // Protein
  FoodSource(
    name: 'Chicken breast',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.nonVeg,
    region: FoodRegion.global,
    caloriesPer100g: 165,
    proteinPer100g: 31,
    carbsPer100g: 0,
    fatsPer100g: 3.6,
    fiberPer100g: 0,
    sugarPer100g: 0,
  ),
  FoodSource(
    name: 'Eggs',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.eggetarian,
    region: FoodRegion.global,
    caloriesPer100g: 155,
    proteinPer100g: 13,
    carbsPer100g: 1.1,
    fatsPer100g: 11,
    fiberPer100g: 0,
    sugarPer100g: 1.1,
  ),
  FoodSource(
    name: 'Greek yogurt',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegetarian,
    region: FoodRegion.global,
    caloriesPer100g: 59,
    proteinPer100g: 10,
    carbsPer100g: 3.6,
    fatsPer100g: 0.4,
    fiberPer100g: 0,
    sugarPer100g: 3.2,
  ),
  FoodSource(
    name: 'Paneer',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegetarian,
    region: FoodRegion.indian,
    caloriesPer100g: 265,
    proteinPer100g: 18,
    carbsPer100g: 1.2,
    fatsPer100g: 20,
    fiberPer100g: 0,
    sugarPer100g: 1.2,
  ),
  FoodSource(
    name: 'Tofu',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 76,
    proteinPer100g: 8,
    carbsPer100g: 1.9,
    fatsPer100g: 4.8,
    fiberPer100g: 0.3,
    sugarPer100g: 0.7,
  ),
  FoodSource(
    name: 'Soy chunks',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 345,
    proteinPer100g: 52,
    carbsPer100g: 33,
    fatsPer100g: 0.5,
    fiberPer100g: 13,
    sugarPer100g: 10,
  ),
  FoodSource(
    name: 'Lentils (dal)',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 116,
    proteinPer100g: 9,
    carbsPer100g: 20,
    fatsPer100g: 0.4,
    fiberPer100g: 8,
    sugarPer100g: 1.8,
  ),
  FoodSource(
    name: 'Whey protein',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegetarian,
    region: FoodRegion.global,
    caloriesPer100g: 400,
    proteinPer100g: 80,
    carbsPer100g: 8,
    fatsPer100g: 5,
    fiberPer100g: 0,
    sugarPer100g: 4,
  ),
  FoodSource(
    name: 'Fish (rohu)',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.nonVeg,
    region: FoodRegion.indian,
    caloriesPer100g: 97,
    proteinPer100g: 17,
    carbsPer100g: 0,
    fatsPer100g: 2.5,
    fiberPer100g: 0,
    sugarPer100g: 0,
  ),
  FoodSource(
    name: 'Chickpeas',
    category: FoodMacroCategory.protein,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 164,
    proteinPer100g: 9,
    carbsPer100g: 27,
    fatsPer100g: 2.6,
    fiberPer100g: 8,
    sugarPer100g: 5,
  ),

  // Carbs
  FoodSource(
    name: 'Rice (cooked)',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 130,
    proteinPer100g: 2.7,
    carbsPer100g: 28,
    fatsPer100g: 0.3,
    fiberPer100g: 0.4,
    sugarPer100g: 0.1,
  ),
  FoodSource(
    name: 'Oats',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 389,
    proteinPer100g: 17,
    carbsPer100g: 66,
    fatsPer100g: 7,
    fiberPer100g: 11,
    sugarPer100g: 1,
  ),
  FoodSource(
    name: 'Chapati',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 297,
    proteinPer100g: 11,
    carbsPer100g: 46,
    fatsPer100g: 9,
    fiberPer100g: 4,
    sugarPer100g: 2,
  ),
  FoodSource(
    name: 'Potato',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 77,
    proteinPer100g: 2,
    carbsPer100g: 17,
    fatsPer100g: 0.1,
    fiberPer100g: 2.2,
    sugarPer100g: 0.8,
  ),
  FoodSource(
    name: 'Sweet potato',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 86,
    proteinPer100g: 1.6,
    carbsPer100g: 20,
    fatsPer100g: 0.1,
    fiberPer100g: 3,
    sugarPer100g: 4.2,
  ),
  FoodSource(
    name: 'Banana',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 89,
    proteinPer100g: 1.1,
    carbsPer100g: 23,
    fatsPer100g: 0.3,
    fiberPer100g: 2.6,
    sugarPer100g: 12,
  ),
  FoodSource(
    name: 'Pasta (cooked)',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 131,
    proteinPer100g: 5,
    carbsPer100g: 25,
    fatsPer100g: 1.1,
    fiberPer100g: 1.8,
    sugarPer100g: 0.6,
  ),
  FoodSource(
    name: 'Bread (whole wheat)',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 247,
    proteinPer100g: 13,
    carbsPer100g: 41,
    fatsPer100g: 3.4,
    fiberPer100g: 7,
    sugarPer100g: 5,
  ),
  FoodSource(
    name: 'Idli',
    category: FoodMacroCategory.carbs,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 156,
    proteinPer100g: 4,
    carbsPer100g: 32,
    fatsPer100g: 0.5,
    fiberPer100g: 1.5,
    sugarPer100g: 1,
  ),

  // Fiber
  FoodSource(
    name: 'Apple',
    category: FoodMacroCategory.fiber,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 52,
    proteinPer100g: 0.3,
    carbsPer100g: 14,
    fatsPer100g: 0.2,
    fiberPer100g: 2.4,
    sugarPer100g: 10,
  ),
  FoodSource(
    name: 'Beans (rajma)',
    category: FoodMacroCategory.fiber,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 127,
    proteinPer100g: 9,
    carbsPer100g: 23,
    fatsPer100g: 0.5,
    fiberPer100g: 7,
    sugarPer100g: 0.3,
  ),
  FoodSource(
    name: 'Mixed vegetables',
    category: FoodMacroCategory.fiber,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 65,
    proteinPer100g: 2.5,
    carbsPer100g: 12,
    fatsPer100g: 0.5,
    fiberPer100g: 4,
    sugarPer100g: 4,
  ),
  FoodSource(
    name: 'Chia seeds',
    category: FoodMacroCategory.fiber,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 486,
    proteinPer100g: 17,
    carbsPer100g: 42,
    fatsPer100g: 31,
    fiberPer100g: 34,
    sugarPer100g: 0,
  ),
  FoodSource(
    name: 'Spinach',
    category: FoodMacroCategory.fiber,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 23,
    proteinPer100g: 2.9,
    carbsPer100g: 3.6,
    fatsPer100g: 0.4,
    fiberPer100g: 2.2,
    sugarPer100g: 0.4,
  ),
  FoodSource(
    name: 'Pear',
    category: FoodMacroCategory.fiber,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 57,
    proteinPer100g: 0.4,
    carbsPer100g: 15,
    fatsPer100g: 0.1,
    fiberPer100g: 3.1,
    sugarPer100g: 10,
  ),

  // Fats
  FoodSource(
    name: 'Almonds',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 579,
    proteinPer100g: 21,
    carbsPer100g: 22,
    fatsPer100g: 50,
    fiberPer100g: 12,
    sugarPer100g: 4.4,
  ),
  FoodSource(
    name: 'Peanut butter',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 588,
    proteinPer100g: 25,
    carbsPer100g: 20,
    fatsPer100g: 50,
    fiberPer100g: 6,
    sugarPer100g: 9,
  ),
  FoodSource(
    name: 'Avocado',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 160,
    proteinPer100g: 2,
    carbsPer100g: 9,
    fatsPer100g: 15,
    fiberPer100g: 7,
    sugarPer100g: 0.7,
  ),
  FoodSource(
    name: 'Olive oil',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegan,
    region: FoodRegion.global,
    caloriesPer100g: 884,
    proteinPer100g: 0,
    carbsPer100g: 0,
    fatsPer100g: 100,
    fiberPer100g: 0,
    sugarPer100g: 0,
  ),
  FoodSource(
    name: 'Peanuts',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 567,
    proteinPer100g: 26,
    carbsPer100g: 16,
    fatsPer100g: 49,
    fiberPer100g: 9,
    sugarPer100g: 4,
  ),
  FoodSource(
    name: 'Cashews',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegan,
    region: FoodRegion.indian,
    caloriesPer100g: 553,
    proteinPer100g: 18,
    carbsPer100g: 30,
    fatsPer100g: 44,
    fiberPer100g: 3,
    sugarPer100g: 6,
  ),
  FoodSource(
    name: 'Ghee',
    category: FoodMacroCategory.fats,
    dietType: FoodDietType.vegetarian,
    region: FoodRegion.indian,
    caloriesPer100g: 900,
    proteinPer100g: 0,
    carbsPer100g: 0,
    fatsPer100g: 100,
    fiberPer100g: 0,
    sugarPer100g: 0,
  ),
];

List<FoodSource> foodsForCategory(
  FoodMacroCategory category, {
  required DietPreference diet,
}) {
  return kFoodSources
      .where((f) => f.category == category && _matchesDiet(f.dietType, diet))
      .toList();
}

bool _matchesDiet(FoodDietType foodDiet, DietPreference filter) {
  switch (filter) {
    case DietPreference.all:
      return true;
    case DietPreference.vegetarian:
      return foodDiet != FoodDietType.nonVeg;
    case DietPreference.vegan:
      return foodDiet == FoodDietType.vegan;
    case DietPreference.eggetarian:
      return foodDiet == FoodDietType.eggetarian ||
          foodDiet == FoodDietType.vegetarian ||
          foodDiet == FoodDietType.vegan;
    case DietPreference.nonVeg:
      return foodDiet == FoodDietType.nonVeg;
  }
}
