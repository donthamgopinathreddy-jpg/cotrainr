import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/profile_repository.dart';

/// MVP sharing preferences. Each field maps 1:1 to a `profiles` column
/// that RLS actually enforces.
class PrivacyPreferences {
  final bool shareActivityWithTrainer;
  final bool shareMealsWithTrainer;
  final bool shareNutritionWithNutritionist;

  const PrivacyPreferences({
    this.shareActivityWithTrainer = true,
    this.shareMealsWithTrainer = true,
    this.shareNutritionWithNutritionist = true,
  });

  /// Persisted as `profiles.share_metrics_with_trainer`.
  bool get shareMetricsWithTrainer => shareActivityWithTrainer;

  PrivacyPreferences copyWith({
    bool? shareActivityWithTrainer,
    bool? shareMealsWithTrainer,
    bool? shareNutritionWithNutritionist,
  }) {
    return PrivacyPreferences(
      shareActivityWithTrainer:
          shareActivityWithTrainer ?? this.shareActivityWithTrainer,
      shareMealsWithTrainer:
          shareMealsWithTrainer ?? this.shareMealsWithTrainer,
      shareNutritionWithNutritionist: shareNutritionWithNutritionist ??
          this.shareNutritionWithNutritionist,
    );
  }
}

abstract class PrivacyPreferencesStore {
  Future<PrivacyPreferences> load();
  Future<void> save(PrivacyPreferences prefs);
}

class PrivacyPreferencesService implements PrivacyPreferencesStore {
  static const _prefix = 'privacy_pref_';
  final ProfileRepository _profileRepo;

  PrivacyPreferencesService({ProfileRepository? profileRepo})
      : _profileRepo = profileRepo ?? ProfileRepository();

  /// Loads sharing preferences from Supabase (authoritative) and caches locally.
  @override
  Future<PrivacyPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (profile != null) {
        final loaded = PrivacyPreferences(
          shareActivityWithTrainer:
              profile['share_metrics_with_trainer'] as bool? ?? true,
          shareMealsWithTrainer:
              profile['share_meals_with_trainer'] as bool? ?? true,
          shareNutritionWithNutritionist:
              profile['share_nutrition_with_nutritionist'] as bool? ?? true,
        );
        await _cacheToSharedPreferences(loaded, prefs);
        return loaded;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PrivacyPreferences] load failed, using local cache: $e');
      }
    }

    return PrivacyPreferences(
      shareActivityWithTrainer:
          prefs.getBool('${_prefix}share_activity_trainer') ?? true,
      shareMealsWithTrainer:
          prefs.getBool('${_prefix}share_meals_trainer') ?? true,
      shareNutritionWithNutritionist:
          prefs.getBool('${_prefix}share_nutrition_nutritionist') ?? true,
    );
  }

  @override
  Future<void> save(PrivacyPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await _cacheToSharedPreferences(prefs, sp);

    await _profileRepo.updateProfile({
      'share_metrics_with_trainer': prefs.shareMetricsWithTrainer,
      'share_meals_with_trainer': prefs.shareMealsWithTrainer,
      'share_nutrition_with_nutritionist': prefs.shareNutritionWithNutritionist,
    });
  }

  Future<void> _cacheToSharedPreferences(
    PrivacyPreferences prefs,
    SharedPreferences sp,
  ) async {
    await sp.setBool(
      '${_prefix}share_activity_trainer',
      prefs.shareActivityWithTrainer,
    );
    await sp.setBool(
      '${_prefix}share_meals_trainer',
      prefs.shareMealsWithTrainer,
    );
    await sp.setBool(
      '${_prefix}share_nutrition_nutritionist',
      prefs.shareNutritionWithNutritionist,
    );
  }
}
