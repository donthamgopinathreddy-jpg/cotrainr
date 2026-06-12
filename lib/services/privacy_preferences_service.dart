import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPreferences {
  final bool shareActivityWithTrainer;
  final bool shareNutritionWithNutritionist;
  final bool shareHealthMetricsWithProviders;
  final bool locationAccess;

  const PrivacyPreferences({
    this.shareActivityWithTrainer = true,
    this.shareNutritionWithNutritionist = true,
    this.shareHealthMetricsWithProviders = true,
    this.locationAccess = true,
  });

  PrivacyPreferences copyWith({
    bool? shareActivityWithTrainer,
    bool? shareNutritionWithNutritionist,
    bool? shareHealthMetricsWithProviders,
    bool? locationAccess,
  }) {
    return PrivacyPreferences(
      shareActivityWithTrainer:
          shareActivityWithTrainer ?? this.shareActivityWithTrainer,
      shareNutritionWithNutritionist:
          shareNutritionWithNutritionist ?? this.shareNutritionWithNutritionist,
      shareHealthMetricsWithProviders: shareHealthMetricsWithProviders ??
          this.shareHealthMetricsWithProviders,
      locationAccess: locationAccess ?? this.locationAccess,
    );
  }
}

class PrivacyPreferencesService {
  static const _prefix = 'privacy_pref_';

  Future<PrivacyPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PrivacyPreferences(
      shareActivityWithTrainer:
          prefs.getBool('${_prefix}share_activity_trainer') ?? true,
      shareNutritionWithNutritionist:
          prefs.getBool('${_prefix}share_nutrition_nutritionist') ?? true,
      shareHealthMetricsWithProviders:
          prefs.getBool('${_prefix}share_health_providers') ?? true,
      locationAccess: prefs.getBool('${_prefix}location_access') ?? true,
    );
  }

  Future<void> save(PrivacyPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(
        '${_prefix}share_activity_trainer', prefs.shareActivityWithTrainer);
    await sp.setBool('${_prefix}share_nutrition_nutritionist',
        prefs.shareNutritionWithNutritionist);
    await sp.setBool('${_prefix}share_health_providers',
        prefs.shareHealthMetricsWithProviders);
    await sp.setBool('${_prefix}location_access', prefs.locationAccess);
  }
}
