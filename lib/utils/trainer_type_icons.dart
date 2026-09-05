import 'package:flutter/material.dart';

import '../models/provider_specialty_taxonomy.dart';

/// Maps a trainer specialty id, legacy label, or freeform title to a Material icon.
///
/// Safe for null/unknown values. Does not invent DB specialty ids — only maps
/// known [ProviderSpecialtyTaxonomy] values (plus common freeform title text).
IconData trainerTypeIcon(String? trainerType) {
  if (trainerType == null) return Icons.fitness_center_rounded;

  final raw = trainerType.trim();
  if (raw.isEmpty) return Icons.fitness_center_rounded;

  final id = ProviderSpecialtyTaxonomy.normalizeSpecialtyId(raw);
  final byId = _iconForSpecialtyId(id);
  if (byId != null) return byId;

  return _iconForFreeformTitle(raw) ?? Icons.fitness_center_rounded;
}

IconData? _iconForSpecialtyId(String id) {
  switch (id) {
    // Gym / personal / strength family
    case 'personal_training':
    case 'strength_training':
    case 'strength_and_conditioning':
    case 'powerlifting':
    case 'olympic_weightlifting':
    case 'muscle_gain':
    case 'fat_loss':
    case 'body_recomposition':
    case 'functional_fitness':
    case 'hiit':
      return Icons.fitness_center_rounded;

    case 'yoga':
      return Icons.self_improvement_rounded;

    case 'pilates':
    case 'mobility':
    case 'flexibility':
    case 'prenatal_postnatal_fitness':
    case 'senior_fitness':
      return Icons.accessibility_new_rounded;

    case 'boxing':
    case 'kickboxing':
    case 'mma':
    case 'muay_thai':
      return Icons.sports_mma;

    case 'running':
    case 'cardio_fitness':
      return Icons.directions_run_rounded;

    case 'cycling':
      return Icons.directions_bike_rounded;

    case 'swimming':
      return Icons.pool_rounded;

    case 'sports_performance':
      return Icons.sports_rounded;

    case 'calisthenics':
    case 'street_workout':
      return Icons.sports_gymnastics;

    case 'zumba':
    case 'dance_fitness':
      return Icons.music_note_rounded;

    case 'group_fitness':
      return Icons.groups_rounded;

    case 'womens_fitness':
    case 'youth_fitness':
      return Icons.fitness_center_rounded;

    default:
      return null;
  }
}

/// Freeform headlines / display strings (e.g. "Yoga Trainer", "Gym Trainer").
IconData? _iconForFreeformTitle(String raw) {
  final lower = raw.toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');

  if (_containsAny(lower, const ['yoga'])) {
    return Icons.self_improvement_rounded;
  }
  if (_containsAny(lower, const ['pilates'])) {
    return Icons.accessibility_new_rounded;
  }
  if (_containsAny(lower, const [
    'rehab',
    'rehabilitation',
    'mobility',
    'flexibility',
  ])) {
    return Icons.accessibility_new_rounded;
  }
  if (_containsAny(lower, const [
    'boxing',
    'kickboxing',
    'mma',
    'muay thai',
    'muaythai',
  ])) {
    return Icons.sports_mma;
  }
  if (_containsAny(lower, const ['running', 'runner', 'marathon'])) {
    return Icons.directions_run_rounded;
  }
  if (_containsAny(lower, const ['cycling', 'bike', 'bicycle'])) {
    return Icons.directions_bike_rounded;
  }
  if (_containsAny(lower, const ['swim', 'swimming'])) {
    return Icons.pool_rounded;
  }
  if (_containsAny(lower, const [
    'sports performance',
    'sport performance',
    'athletic performance',
  ])) {
    return Icons.sports_rounded;
  }
  // Broad "sports" after more specific sport keywords.
  if (RegExp(r'\bsports?\b').hasMatch(lower) &&
      !_containsAny(lower, const ['nutrition'])) {
    return Icons.sports_rounded;
  }
  if (_containsAny(lower, const [
    'gym',
    'personal train',
    'strength',
    'weightlift',
    'powerlift',
    'bodybuild',
  ])) {
    return Icons.fitness_center_rounded;
  }

  return null;
}

bool _containsAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}
