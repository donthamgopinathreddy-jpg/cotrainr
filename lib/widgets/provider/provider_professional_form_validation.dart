import '../../models/provider_specialty_taxonomy.dart';

/// Shared validation for provider professional onboarding / edit.
abstract final class ProviderProfessionalFormValidation {
  static const headlineMaxLen = 80;
  static const bioMinLen = 40;
  static const bioMaxLen = 1000;
  static const experienceMin = 0;
  static const experienceMax = 60;

  static const suggestedLanguages = <String>[
    'English',
    'Hindi',
    'Telugu',
    'Tamil',
    'Urdu',
    'Spanish',
    'French',
    'Arabic',
  ];

  static String headlinePlaceholder(String? role) {
    final isNutritionist = role?.toLowerCase() == 'nutritionist';
    return isNutritionist
        ? 'e.g. Sports Nutritionist'
        : 'e.g. Calisthenics Coach';
  }

  /// Returns error message, or null if valid.
  static String? validate({
    required String headline,
    required String experienceText,
    required String bio,
    required Iterable<String> specializationIds,
    required Iterable<String> languages,
    required Iterable<String> sessionModes,
  }) {
    final h = headline.trim();
    if (h.isEmpty) return 'Professional headline is required';
    if (h.length > headlineMaxLen) {
      return 'Headline must be at most $headlineMaxLen characters';
    }

    final exp = int.tryParse(experienceText.trim());
    if (experienceText.trim().isEmpty || exp == null) {
      return 'Years of experience is required';
    }
    if (exp < experienceMin || exp > experienceMax) {
      return 'Experience must be between $experienceMin and $experienceMax';
    }

    final b = bio.trim();
    if (b.isEmpty) return 'Professional bio is required';
    if (b.length < bioMinLen) {
      return 'Bio must be at least $bioMinLen characters';
    }
    if (b.length > bioMaxLen) {
      return 'Bio must be at most $bioMaxLen characters';
    }

    if (specializationIds.isEmpty) {
      return 'Select at least one specialty';
    }
    if (languages.isEmpty) {
      return 'Add at least one language';
    }
    if (sessionModes.isEmpty) {
      return 'Select at least one session mode';
    }
    return null;
  }
}

/// Pure post-permissions destination (deterministic, testable).
String postPermissionsDestination(String role) {
  final r = role.trim().toLowerCase();
  if (r == 'trainer' || r == 'nutritionist') return '/verification';
  return '/home';
}

/// Re-export session mode label helper for form UIs.
String sessionModeLabel(String id, {String? role}) =>
    ProviderSessionModes.labelFor(id, role: role);
