/// Onboarding fitness goals with stable ids and persistence-compatible labels.
///
/// [storageValue] is written to `profiles.fitness_goals`. Legacy labels
/// (`Weight Loss`, `Muscle Gain`, `Strength`, `Nutrition`, …) are preserved
/// where they already exist so recommendations keep working.
class FitnessGoal {
  const FitnessGoal({
    required this.id,
    required this.label,
    required this.storageValue,
    required this.subtitle,
    required this.iconName,
    required this.primary,
  });

  final String id;
  final String label;
  final String storageValue;
  final String subtitle;
  final String iconName;
  final bool primary;
}

abstract final class FitnessGoalTaxonomy {
  static const loseWeight = FitnessGoal(
    id: 'lose_weight',
    label: 'Lose Weight',
    storageValue: 'Weight Loss',
    subtitle: 'Cut fat and feel lighter',
    iconName: 'monitor_weight',
    primary: true,
  );
  static const buildMuscle = FitnessGoal(
    id: 'build_muscle',
    label: 'Build Muscle',
    storageValue: 'Muscle Gain',
    subtitle: 'Gain lean mass and strength',
    iconName: 'fitness_center',
    primary: true,
  );
  static const getStronger = FitnessGoal(
    id: 'get_stronger',
    label: 'Get Stronger',
    storageValue: 'Strength',
    subtitle: 'Build power you can use',
    iconName: 'bolt',
    primary: true,
  );
  static const improveFitness = FitnessGoal(
    id: 'improve_fitness',
    label: 'Improve Fitness',
    storageValue: 'Improve Fitness',
    subtitle: 'Move better, more often',
    iconName: 'directions_run',
    primary: true,
  );
  static const improveEndurance = FitnessGoal(
    id: 'improve_endurance',
    label: 'Endurance',
    storageValue: 'Improve Endurance',
    subtitle: 'Go longer with less fade',
    iconName: 'timer',
    primary: false,
  );
  static const improveMobility = FitnessGoal(
    id: 'improve_mobility',
    label: 'Mobility',
    storageValue: 'Improve Mobility',
    subtitle: 'Move freely and recover',
    iconName: 'self_improvement',
    primary: false,
  );
  static const improveNutrition = FitnessGoal(
    id: 'improve_nutrition',
    label: 'Nutrition',
    storageValue: 'Nutrition',
    subtitle: 'Eat in a way that lasts',
    iconName: 'restaurant',
    primary: false,
  );
  static const maintain = FitnessGoal(
    id: 'maintain',
    label: 'Maintain',
    storageValue: 'Maintain / General Fitness',
    subtitle: 'Stay consistent',
    iconName: 'balance',
    primary: false,
  );

  static const all = <FitnessGoal>[
    loseWeight,
    buildMuscle,
    getStronger,
    improveFitness,
    improveEndurance,
    improveMobility,
    improveNutrition,
    maintain,
  ];

  static List<FitnessGoal> get primary =>
      all.where((g) => g.primary).toList(growable: false);

  static List<FitnessGoal> get secondary =>
      all.where((g) => !g.primary).toList(growable: false);

  static const _legacyToId = <String, String>{
    'Weight Loss': 'lose_weight',
    'Muscle Gain': 'build_muscle',
    'Strength': 'get_stronger',
    'Cardio Fitness': 'improve_fitness',
    'Improve Fitness': 'improve_fitness',
    'Improve Endurance': 'improve_endurance',
    'Improve Mobility': 'improve_mobility',
    'Nutrition': 'improve_nutrition',
    'Maintain / General Fitness': 'maintain',
    'Yoga': 'improve_mobility',
    'Boxing': 'get_stronger',
    'Pilates': 'improve_mobility',
    'Zumba': 'improve_fitness',
    'Calisthenics': 'get_stronger',
  };

  static FitnessGoal? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }

  static String idFromStorage(String raw) {
    final trimmed = raw.trim();
    if (_legacyToId.containsKey(trimmed)) return _legacyToId[trimmed]!;
    final goal = byId(trimmed);
    if (goal != null) return goal.id;
    return trimmed;
  }

  static String storageForId(String id) =>
      byId(id)?.storageValue ?? id;

  static List<String> toStorage(Iterable<String> ids) {
    final out = <String>[];
    for (final id in ids) {
      final value = storageForId(id);
      if (value.isNotEmpty && !out.contains(value)) out.add(value);
    }
    return out;
  }
}
