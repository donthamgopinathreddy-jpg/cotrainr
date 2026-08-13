import 'provider_specialty_taxonomy.dart';

/// Signup-only specialty choices. Full taxonomy stays on provider profile.
class OnboardingSpecialtyOption {
  const OnboardingSpecialtyOption({
    required this.id,
    required this.label,
    required this.persistIds,
    this.isOther = false,
  });

  final String id;
  final String label;

  /// Canonical ids written to `providers.specialization`.
  final List<String> persistIds;
  final bool isOther;
}

abstract final class OnboardingSpecialtyOptions {
  static const trainer = <OnboardingSpecialtyOption>[
    OnboardingSpecialtyOption(
      id: 'fitness_trainer',
      label: 'Fitness Trainer',
      persistIds: ['personal_training'],
    ),
    OnboardingSpecialtyOption(
      id: 'strength_conditioning',
      label: 'Strength & Conditioning',
      persistIds: ['strength_and_conditioning'],
    ),
    OnboardingSpecialtyOption(
      id: 'yoga',
      label: 'Yoga',
      persistIds: ['yoga'],
    ),
    OnboardingSpecialtyOption(
      id: 'pilates',
      label: 'Pilates',
      persistIds: ['pilates'],
    ),
    OnboardingSpecialtyOption(
      id: 'boxing',
      label: 'Boxing',
      persistIds: ['boxing'],
    ),
    OnboardingSpecialtyOption(
      id: 'calisthenics',
      label: 'Calisthenics',
      persistIds: ['calisthenics'],
    ),
    OnboardingSpecialtyOption(
      id: 'other',
      label: 'Other',
      persistIds: [],
      isOther: true,
    ),
  ];

  static const nutritionist = <OnboardingSpecialtyOption>[
    OnboardingSpecialtyOption(
      id: 'general_nutrition',
      label: 'General Nutrition',
      persistIds: ['general_wellness'],
    ),
    OnboardingSpecialtyOption(
      id: 'sports_nutrition',
      label: 'Sports Nutrition',
      persistIds: ['sports_nutrition'],
    ),
    OnboardingSpecialtyOption(
      id: 'weight_management',
      label: 'Weight Management',
      persistIds: ['weight_management'],
    ),
    OnboardingSpecialtyOption(
      id: 'clinical_nutrition',
      label: 'Clinical Nutrition',
      persistIds: ['clinical_nutrition'],
    ),
    OnboardingSpecialtyOption(
      id: 'diet_planning',
      label: 'Diet Planning',
      persistIds: ['meal_planning'],
    ),
    OnboardingSpecialtyOption(
      id: 'other',
      label: 'Other',
      persistIds: [],
      isOther: true,
    ),
  ];

  static List<OnboardingSpecialtyOption> forRole(String role) {
    return role == 'Nutritionist' ? nutritionist : trainer;
  }

  /// Expand selected onboarding chips + custom Other text into persist ids.
  static List<String> persistSelection({
    required String role,
    required Set<String> selectedIds,
    String? otherText,
  }) {
    final options = forRole(role);
    final out = <String>[];
    for (final option in options) {
      if (!selectedIds.contains(option.id)) continue;
      if (option.isOther) {
        final custom = otherText?.trim() ?? '';
        if (custom.isNotEmpty) {
          out.add(ProviderSpecialtyTaxonomy.normalizeSpecialtyId(custom));
        }
      } else {
        for (final id in option.persistIds) {
          if (!out.contains(id)) out.add(id);
        }
      }
    }
    return ProviderSpecialtyTaxonomy.normalizeList(out);
  }

  static bool otherSelected(Set<String> selectedIds) =>
      selectedIds.contains('other');
}
