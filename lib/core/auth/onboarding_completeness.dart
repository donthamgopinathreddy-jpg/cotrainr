/// Derived Cotrainr onboarding completeness (no username-only shortcut).
///
/// Server RPC [get_onboarding_state] is authoritative at runtime.
/// This pure evaluator is the same rule for tests and client fallback.
class OnboardingSnapshot {
  const OnboardingSnapshot({
    this.username,
    this.role,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.fitnessGoals = const [],
    this.hasCurrentLegal = false,
    this.providerSpecialties = const [],
    this.isLegacyBodyComplete = false,
  });

  final String? username;
  final String? role;
  final DateTime? dateOfBirth;
  final String? gender;
  final num? heightCm;
  final num? weightKg;
  final List<String> fitnessGoals;
  final bool hasCurrentLegal;
  final List<String> providerSpecialties;

  /// Pre-migration users with full body fields and null fitness_goals.
  final bool isLegacyBodyComplete;
}

class OnboardingState {
  const OnboardingState({
    required this.isComplete,
    this.missing = const [],
  });

  final bool isComplete;
  final List<String> missing;

  static const requiredCodes = <String>[
    'username',
    'role',
    'dob',
    'gender',
    'height',
    'weight',
    'goals',
    'legal',
    'specialties',
  ];
}

abstract final class OnboardingCompleteness {
  static OnboardingState evaluate(OnboardingSnapshot snap) {
    final missing = <String>[];
    final username = snap.username?.trim() ?? '';
    if (username.isEmpty) missing.add('username');

    final role = snap.role?.trim().toLowerCase() ?? '';
    if (role != 'client' && role != 'trainer' && role != 'nutritionist') {
      missing.add('role');
    }

    if (snap.dateOfBirth == null) missing.add('dob');

    final gender = snap.gender?.trim() ?? '';
    if (gender.isEmpty) missing.add('gender');

    if (snap.heightCm == null) missing.add('height');
    if (snap.weightKg == null) missing.add('weight');

    final goalsOk = snap.fitnessGoals.any((g) => g.trim().isNotEmpty) ||
        snap.isLegacyBodyComplete;
    if (!goalsOk) missing.add('goals');

    final legalOk = snap.hasCurrentLegal || snap.isLegacyBodyComplete;
    if (!legalOk) missing.add('legal');

    if (role == 'trainer' || role == 'nutritionist') {
      if (!snap.providerSpecialties.any((s) => s.trim().isNotEmpty)) {
        missing.add('specialties');
      }
    }

    return OnboardingState(
      isComplete: missing.isEmpty,
      missing: missing,
    );
  }
}
