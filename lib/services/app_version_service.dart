import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/semantic_version.dart';

class AppVersionConfig {
  final String minimumVersion;
  final String recommendedVersion;
  final String? storeUrl;

  const AppVersionConfig({
    required this.minimumVersion,
    required this.recommendedVersion,
    this.storeUrl,
  });

  static const fallback = AppVersionConfig(
    minimumVersion: '1.0.0',
    recommendedVersion: '1.0.0',
  );
}

class AppVersionCheckResult {
  final VersionCheckOutcome outcome;
  final AppVersionConfig config;
  final String installedVersion;

  const AppVersionCheckResult({
    required this.outcome,
    required this.config,
    required this.installedVersion,
  });

  bool get isRequired => outcome == VersionCheckOutcome.requiredUpdate;
  bool get isOptional => outcome == VersionCheckOutcome.optionalUpdate;
}

class AppVersionService {
  AppVersionService._();
  static final AppVersionService instance = AppVersionService._();

  static const _cachedMinimumKey = 'app_version_cached_minimum';
  static const _dismissedRecommendedKey = 'app_update_dismissed_recommended';

  Future<AppVersionCheckResult> evaluate({PackageInfo? packageInfo}) async {
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    final installed = info.version.trim();
    final platform = Platform.isIOS ? 'ios' : 'android';

    AppVersionConfig config = AppVersionConfig.fallback;
    try {
      final rows = await Supabase.instance.client.rpc('get_app_version_config');
      if (rows is List) {
        for (final row in rows) {
          if (row is Map && row['platform'] == platform) {
            config = AppVersionConfig(
              minimumVersion:
                  (row['minimum_version'] as String?)?.trim() ?? '1.0.0',
              recommendedVersion:
                  (row['recommended_version'] as String?)?.trim() ?? '1.0.0',
              storeUrl: (row['store_url'] as String?)?.trim(),
            );
            break;
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedMinimumKey, config.minimumVersion);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppVersionService: remote config unavailable');
      }
      final prefs = await SharedPreferences.getInstance();
      final cachedMin = prefs.getString(_cachedMinimumKey);
      if (cachedMin != null && cachedMin.isNotEmpty) {
        config = AppVersionConfig(
          minimumVersion: cachedMin,
          recommendedVersion: cachedMin,
          storeUrl: config.storeUrl,
        );
      } else {
        return AppVersionCheckResult(
          outcome: VersionCheckOutcome.failOpen,
          config: config,
          installedVersion: installed,
        );
      }
    }

    final outcome = compareInstalledToConfig(
      installedVersion: installed,
      minimumVersion: config.minimumVersion,
      recommendedVersion: config.recommendedVersion,
    );
    return AppVersionCheckResult(
      outcome: outcome,
      config: config,
      installedVersion: installed,
    );
  }

  Future<bool> shouldShowOptionalPrompt(AppVersionCheckResult result) async {
    if (!result.isOptional) return false;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissedRecommendedKey);
    return dismissed != result.config.recommendedVersion;
  }

  Future<void> dismissOptionalForVersion(String recommendedVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedRecommendedKey, recommendedVersion);
  }

  Future<void> openStore({String? storeUrl}) async {
    final fallback = Platform.isIOS
        ? null
        : 'https://play.google.com/store/apps/details?id=com.cotrainr.app';
    final url = storeUrl ?? fallback;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
