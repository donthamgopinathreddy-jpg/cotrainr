import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/profile_repository.dart';

class PrivacyPreferences {
  final bool shareActivityWithTrainer;
  final bool shareMealsWithTrainer;
  final bool shareNutritionWithNutritionist;
  final bool shareHealthMetricsWithProviders;
  final bool locationAccess;

  const PrivacyPreferences({
    this.shareActivityWithTrainer = true,
    this.shareMealsWithTrainer = true,
    this.shareNutritionWithNutritionist = true,
    this.shareHealthMetricsWithProviders = true,
    this.locationAccess = true,
  });

  PrivacyPreferences copyWith({
    bool? shareActivityWithTrainer,
    bool? shareMealsWithTrainer,
    bool? shareNutritionWithNutritionist,
    bool? shareHealthMetricsWithProviders,
    bool? locationAccess,
  }) {
    return PrivacyPreferences(
      shareActivityWithTrainer:
          shareActivityWithTrainer ?? this.shareActivityWithTrainer,
      shareMealsWithTrainer:
          shareMealsWithTrainer ?? this.shareMealsWithTrainer,
      shareNutritionWithNutritionist:
          shareNutritionWithNutritionist ?? this.shareNutritionWithNutritionist,
      shareHealthMetricsWithProviders: shareHealthMetricsWithProviders ??
          this.shareHealthMetricsWithProviders,
      locationAccess: locationAccess ?? this.locationAccess,
    );
  }

  bool get shareMetricsWithTrainer =>
      shareActivityWithTrainer && shareHealthMetricsWithProviders;
}

class PrivacyPreferencesService {
  static const _prefix = 'privacy_pref_';
  final ProfileRepository _profileRepo = ProfileRepository();

  /// Loads sharing preferences from Supabase (authoritative) and caches locally.
  Future<PrivacyPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (profile != null) {
        final shareMetrics =
            profile['share_metrics_with_trainer'] as bool? ?? true;
        final shareMeals =
            profile['share_meals_with_trainer'] as bool? ?? true;
        final shareNutrition =
            profile['share_nutrition_with_nutritionist'] as bool? ?? true;
        final loaded = PrivacyPreferences(
          shareActivityWithTrainer: shareMetrics,
          shareMealsWithTrainer: shareMeals,
          shareNutritionWithNutritionist: shareNutrition,
          shareHealthMetricsWithProviders: shareMetrics,
          locationAccess:
              prefs.getBool('${_prefix}location_access') ?? true,
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
      shareHealthMetricsWithProviders:
          prefs.getBool('${_prefix}share_health_providers') ?? true,
      locationAccess: prefs.getBool('${_prefix}location_access') ?? true,
    );
  }

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
    await sp.setBool(
      '${_prefix}share_health_providers',
      prefs.shareHealthMetricsWithProviders,
    );
    await sp.setBool('${_prefix}location_access', prefs.locationAccess);
  }
}
