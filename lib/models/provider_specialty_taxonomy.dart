/// Shared provider specialty taxonomy (trainers + nutritionists).
///
/// Stable [id] values are stored in `providers.specialization` TEXT[].
/// [label] is user-facing. Legacy signup labels map via [normalizeSpecialtyId].
library;

class ProviderSpecialty {
  final String id;
  final String label;
  final String group;

  const ProviderSpecialty({
    required this.id,
    required this.label,
    required this.group,
  });
}

abstract final class ProviderSpecialtyTaxonomy {
  static const trainer = <ProviderSpecialty>[
    // General fitness
    ProviderSpecialty(id: 'personal_training', label: 'Personal Training', group: 'General Fitness'),
    ProviderSpecialty(id: 'fat_loss', label: 'Fat Loss', group: 'General Fitness'),
    ProviderSpecialty(id: 'muscle_gain', label: 'Muscle Gain', group: 'General Fitness'),
    ProviderSpecialty(id: 'body_recomposition', label: 'Body Recomposition', group: 'General Fitness'),
    ProviderSpecialty(id: 'strength_training', label: 'Strength Training', group: 'General Fitness'),
    ProviderSpecialty(id: 'functional_fitness', label: 'Functional Fitness', group: 'General Fitness'),
    ProviderSpecialty(id: 'hiit', label: 'HIIT', group: 'General Fitness'),
    ProviderSpecialty(id: 'cardio_fitness', label: 'Cardio Fitness', group: 'General Fitness'),
    ProviderSpecialty(id: 'mobility', label: 'Mobility', group: 'General Fitness'),
    ProviderSpecialty(id: 'flexibility', label: 'Flexibility', group: 'General Fitness'),
    // Strength sports
    ProviderSpecialty(id: 'powerlifting', label: 'Powerlifting', group: 'Strength Sports'),
    ProviderSpecialty(id: 'olympic_weightlifting', label: 'Olympic Weightlifting', group: 'Strength Sports'),
    ProviderSpecialty(id: 'strength_and_conditioning', label: 'Strength & Conditioning', group: 'Strength Sports'),
    // Bodyweight
    ProviderSpecialty(id: 'calisthenics', label: 'Calisthenics', group: 'Bodyweight'),
    ProviderSpecialty(id: 'street_workout', label: 'Street Workout', group: 'Bodyweight'),
    // Combat
    ProviderSpecialty(id: 'boxing', label: 'Boxing', group: 'Combat Sports'),
    ProviderSpecialty(id: 'kickboxing', label: 'Kickboxing', group: 'Combat Sports'),
    ProviderSpecialty(id: 'mma', label: 'MMA', group: 'Combat Sports'),
    ProviderSpecialty(id: 'muay_thai', label: 'Muay Thai', group: 'Combat Sports'),
    // Mind & body
    ProviderSpecialty(id: 'yoga', label: 'Yoga', group: 'Mind & Body'),
    ProviderSpecialty(id: 'pilates', label: 'Pilates', group: 'Mind & Body'),
    // Group
    ProviderSpecialty(id: 'zumba', label: 'Zumba', group: 'Group Fitness'),
    ProviderSpecialty(id: 'dance_fitness', label: 'Dance Fitness', group: 'Group Fitness'),
    ProviderSpecialty(id: 'group_fitness', label: 'Group Fitness', group: 'Group Fitness'),
    // Endurance
    ProviderSpecialty(id: 'running', label: 'Running', group: 'Endurance & Sports'),
    ProviderSpecialty(id: 'cycling', label: 'Cycling', group: 'Endurance & Sports'),
    ProviderSpecialty(id: 'swimming', label: 'Swimming', group: 'Endurance & Sports'),
    ProviderSpecialty(id: 'sports_performance', label: 'Sports Performance', group: 'Endurance & Sports'),
    // Population
    ProviderSpecialty(id: 'womens_fitness', label: "Women's Fitness", group: 'Population-Specific'),
    ProviderSpecialty(id: 'senior_fitness', label: 'Senior Fitness', group: 'Population-Specific'),
    ProviderSpecialty(id: 'youth_fitness', label: 'Youth Fitness', group: 'Population-Specific'),
    ProviderSpecialty(id: 'prenatal_postnatal_fitness', label: 'Prenatal / Postnatal', group: 'Population-Specific'),
  ];

  static const nutritionist = <ProviderSpecialty>[
    ProviderSpecialty(id: 'weight_management', label: 'Weight Management', group: 'Nutrition'),
    ProviderSpecialty(id: 'sports_nutrition', label: 'Sports Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'general_wellness', label: 'General Wellness', group: 'Nutrition'),
    ProviderSpecialty(id: 'meal_planning', label: 'Meal Planning', group: 'Nutrition'),
    ProviderSpecialty(id: 'vegetarian_nutrition', label: 'Vegetarian Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'vegan_nutrition', label: 'Vegan Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'plant_based_nutrition', label: 'Plant-Based Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'clinical_nutrition', label: 'Clinical Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'diabetes_nutrition', label: 'Diabetes Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'digestive_health', label: 'Digestive Health', group: 'Nutrition'),
    ProviderSpecialty(id: 'lifestyle_nutrition', label: 'Lifestyle Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'body_recomposition_nutrition', label: 'Body Recomposition Nutrition', group: 'Nutrition'),
    ProviderSpecialty(id: 'maternal_nutrition', label: 'Maternal Nutrition', group: 'Nutrition'),
  ];

  static List<ProviderSpecialty> forRole(String? role) {
    final r = role?.toLowerCase();
    if (r == 'nutritionist') return nutritionist;
    return trainer;
  }

  static final Map<String, ProviderSpecialty> _byId = {
    for (final s in [...trainer, ...nutritionist]) s.id: s,
  };

  /// Legacy signup / Discover labels → canonical ids.
  static const legacyLabelToId = <String, String>{
    'Gym': 'personal_training',
    'gym': 'personal_training',
    'Boxing': 'boxing',
    'Yoga': 'yoga',
    'Pilates': 'pilates',
    'Zumba': 'zumba',
    'Calisthenics': 'calisthenics',
    'Strength': 'strength_training',
    'HIIT': 'hiit',
    'Cardio': 'cardio_fitness',
    'Weight Loss': 'weight_management',
    'Sports Nutrition': 'sports_nutrition',
    'Clinical': 'clinical_nutrition',
    'Plant-Based': 'plant_based_nutrition',
    'Lifestyle': 'lifestyle_nutrition',
    'Meal Planning': 'meal_planning',
    'Diabetes Care': 'diabetes_nutrition',
  };

  static String normalizeSpecialtyId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_byId.containsKey(trimmed)) return trimmed;
    final fromLegacy = legacyLabelToId[trimmed] ?? legacyLabelToId[trimmed.toLowerCase()];
    if (fromLegacy != null) return fromLegacy;
    final lower = trimmed.toLowerCase().replaceAll(' ', '_');
    if (_byId.containsKey(lower)) return lower;
    return trimmed; // preserve custom
  }

  static List<String> normalizeList(Iterable<String> raw) {
    final out = <String>[];
    for (final item in raw) {
      final id = normalizeSpecialtyId(item);
      if (id.isNotEmpty && !out.contains(id)) out.add(id);
    }
    return out;
  }

  static String labelFor(String idOrLegacy) {
    final id = normalizeSpecialtyId(idOrLegacy);
    return _byId[id]?.label ?? idOrLegacy;
  }

  static List<String> labelsFor(Iterable<String> ids) =>
      ids.map(labelFor).toList();

  /// Discover filter chip ids for a role (subset of full taxonomy).
  static List<String> discoverFilterIds(String? role) {
    final r = role?.toLowerCase();
    if (r == 'nutritionist') {
      return const [
        'weight_management',
        'sports_nutrition',
        'clinical_nutrition',
        'plant_based_nutrition',
        'lifestyle_nutrition',
        'meal_planning',
      ];
    }
    return const [
      'strength_training',
      'yoga',
      'cardio_fitness',
      'boxing',
      'hiit',
      'calisthenics',
      'pilates',
      'zumba',
      'personal_training',
    ];
  }
}

/// How a provider delivers sessions.
abstract final class ProviderSessionModes {
  static const online = 'online';
  static const providerLocation = 'provider_location';
  static const clientLocation = 'client_location';
  static const outdoor = 'outdoor';
  static const groupSession = 'group_session';

  static const all = <String>[
    online,
    providerLocation,
    clientLocation,
    outdoor,
    groupSession,
  ];

  static String labelFor(String id, {String? role}) {
    final isNutritionist = role?.toLowerCase() == 'nutritionist';
    return switch (id) {
      online => isNutritionist ? 'Online consultation' : 'Online coaching',
      providerLocation =>
        isNutritionist ? 'Clinic consultation' : 'At my gym / studio',
      clientLocation => 'At client location',
      outdoor => 'Outdoor',
      groupSession =>
        isNutritionist ? 'Group workshop' : 'Group classes',
      _ => id,
    };
  }
}
