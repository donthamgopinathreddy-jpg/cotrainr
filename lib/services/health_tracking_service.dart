import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/daily_metrics_snapshot.dart';
import 'metrics/health_connect_metrics_source.dart';
import 'metrics/metrics_source.dart';
import 'metrics/sensor_metrics_source.dart';
import 'health_connect_settings_info.dart';
import 'health_connect_connect_result.dart';

/// Orchestrates a single active [MetricsSource] — Health Connect primary,
/// device sensors fallback only when Health Connect is unavailable.
/// Never runs both simultaneously.
class HealthTrackingService {
  static final HealthTrackingService _instance =
      HealthTrackingService._internal();
  factory HealthTrackingService() => _instance;
  HealthTrackingService._internal();

  Health? _health;
  MetricsSource? _activeSource;
  bool _isInitialized = false;
  bool _loggedActiveSource = false;
  double? _heightCm;

  static const _healthDataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.WATER,
  ];

  MetricsSourceKind? get activeSourceKind => _activeSource?.kind;
  String get activeSourceLabel =>
      _activeSource?.debugLabel ?? 'Not initialized';

  /// User height (cm) for step-based distance estimation when HC distance is missing.
  void setUserHeightCm(double? heightCm) {
    _heightCm = heightCm;
    _activeSource?.setUserHeightCm(heightCm);
  }

  /// Initialize and select Health Connect or sensor fallback.
  Future<bool> initialize() async {
    if (_isInitialized && _activeSource != null) return true;

    try {
      await _requestCorePermissions();

      _health = Health();
      await _health!.configure();

      final useHealthConnect = await _shouldUseHealthConnect();
      await _disposeActiveSource();

      if (useHealthConnect) {
        _activeSource = HealthConnectMetricsSource(_health!);
      } else {
        _activeSource = SensorMetricsSource();
      }

      _activeSource!.setUserHeightCm(_heightCm);
      await _activeSource!.initialize();
      _logActiveSourceOnce();

      _isInitialized = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Metrics] initialize failed: $e');
      }
      return false;
    }
  }

  Future<bool> _shouldUseHealthConnect() async {
    if (_health == null) return false;

    // iOS — always route through Apple Health (same plugin / primary source).
    if (Platform.isIOS) return true;

    if (!Platform.isAndroid) return false;

    try {
      final status = await _health!.getHealthConnectSdkStatus();
      final available =
          await _health!.isHealthConnectAvailable() &&
          status == HealthConnectSdkStatus.sdkAvailable;

      if (kDebugMode) {
        debugPrint('[Metrics] Health Connect SDK status: $status');
      }

      return available;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Metrics] Health Connect availability check failed: $e');
      }
      return false;
    }
  }

  Future<void> _requestCorePermissions() async {
    try {
      final activityStatus = await Permission.activityRecognition.request();
      if (activityStatus.isDenied && kDebugMode) {
        debugPrint(
          '[Metrics] Activity recognition denied — required for Health Connect steps',
        );
      }
      await Permission.notification.request();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Metrics] Permission request error: $e');
      }
    }
  }

  void _logActiveSourceOnce() {
    if (_loggedActiveSource || _activeSource == null) return;
    logActiveMetricsSource(_activeSource!);
    _loggedActiveSource = true;
  }

  Future<void> _ensureReady() async {
    if (!_isInitialized || _activeSource == null) {
      await initialize();
    }
  }

  Future<DailyMetricsSnapshot> getTodaySnapshot() async {
    await _ensureReady();
    return _activeSource?.getTodaySnapshot() ??
        DailyMetricsSnapshot.empty();
  }

  Future<int> getTodaySteps() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.steps;
  }

  Future<double> getTodayCalories() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.activeCalories;
  }

  Future<double> getTodayDistance() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.distanceKm;
  }

  Future<double> getTodayWater() async {
    await _ensureReady();
    return _activeSource?.getTodayWater() ?? 0.0;
  }

  Future<Map<String, bool>> checkPermissions() async {
    final permissions = <String, bool>{
      'metrics_source': _activeSource != null,
      'health_connect_active':
          _activeSource?.kind == MetricsSourceKind.healthConnect,
      'sensor_fallback_active':
          _activeSource?.kind == MetricsSourceKind.deviceSensors,
    };

    if (_health != null) {
      try {
        for (final type in _healthDataTypes) {
          final hasType = await _health!.hasPermissions([type]);
          permissions['health_${type.name}'] = hasType == true;
        }
        if (Platform.isAndroid) {
          permissions['health_connect_available'] =
              await _health!.isHealthConnectAvailable();
        }
      } catch (e) {
        permissions['health'] = false;
      }
    }

    return permissions;
  }

  Future<Map<String, dynamic>> testSensors() async {
    final results = <String, dynamic>{
      'initialized': _isInitialized,
      'active_source': activeSourceLabel,
      'active_source_kind': activeSourceKind?.name,
      'permissions': await checkPermissions(),
      'sensor_data': <String, dynamic>{},
    };

    if (!_isInitialized || _activeSource == null) {
      results['error'] = 'Service not initialized';
      return results;
    }

    try {
      final snapshot = await getTodaySnapshot();
      results['sensor_data'] = {
        'steps': snapshot.steps,
        'calories': snapshot.activeCalories,
        'calories_source': snapshot.caloriesSource.name,
        'distance': snapshot.distanceKm,
        'distance_source': snapshot.distanceSource.name,
        'water': snapshot.waterLiters,
      };
    } catch (e) {
      results['error'] = e.toString();
    }

    return results;
  }

  Future<void> _disposeActiveSource() async {
    _activeSource?.dispose();
    _activeSource = null;
  }

  /// Re-select Health Connect vs sensor fallback (e.g. after granting permissions).
  Future<bool> reinitializeMetricsSource() async {
    await _disposeActiveSource();
    _isInitialized = false;
    _loggedActiveSource = false;
    return initialize();
  }

  static String platformHealthLabel() {
    if (Platform.isIOS) return 'Apple Health';
    return 'Health Connect';
  }

  static String _permissionLabel(HealthDataType type) {
    switch (type) {
      case HealthDataType.STEPS:
        return 'Steps';
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return 'Active calories';
      case HealthDataType.TOTAL_CALORIES_BURNED:
        return 'Total calories';
      case HealthDataType.DISTANCE_WALKING_RUNNING:
        return 'Distance';
      case HealthDataType.WATER:
        return 'Water';
      default:
        return type.name;
    }
  }

  Future<HealthConnectSettingsInfo> getHealthConnectSettingsInfo() async {
    _health ??= Health();
    await _health!.configure();

    final platformLabel = platformHealthLabel();
    HealthConnectSdkStatus? sdkStatus;
    var isAvailable = Platform.isIOS;

    if (Platform.isAndroid) {
      sdkStatus = await _health!.getHealthConnectSdkStatus();
      isAvailable =
          await _health!.isHealthConnectAvailable() &&
          sdkStatus == HealthConnectSdkStatus.sdkAvailable;
    }

    final typePermissions = await _readTypePermissions();
    final permissionsGranted = _hasCorePermissions(typePermissions);

    // Keep the active metrics source aligned with Health Connect when possible.
    if (isAvailable && permissionsGranted) {
      if (_activeSource?.kind != MetricsSourceKind.healthConnect) {
        await reinitializeMetricsSource();
      } else {
        await _ensureReady();
      }
    } else {
      await _ensureReady();
    }

    return HealthConnectSettingsInfo(
      platformLabel: platformLabel,
      isAvailable: isAvailable,
      sdkStatus: sdkStatus,
      permissionsGranted: permissionsGranted,
      isActiveSource: _activeSource?.kind == MetricsSourceKind.healthConnect,
      activeSourceLabel: activeSourceLabel,
      typePermissions: typePermissions,
    );
  }

  Future<Map<String, bool>> _readTypePermissions() async {
    final typePermissions = <String, bool>{};
    for (final type in _healthDataTypes) {
      try {
        typePermissions[_permissionLabel(type)] =
            await _health!.hasPermissions([type]) == true;
      } catch (_) {
        typePermissions[_permissionLabel(type)] = false;
      }
    }
    return typePermissions;
  }

  bool _hasCorePermissions(Map<String, bool> typePermissions) {
    final steps = typePermissions['Steps'] ?? false;
    final calories = (typePermissions['Active calories'] ?? false) ||
        (typePermissions['Total calories'] ?? false);
    final distance = typePermissions['Distance'] ?? false;
    final water = typePermissions['Water'] ?? false;
    return steps && calories && distance && water;
  }

  /// Opens the Health Connect / Apple Health permission sheet immediately.
  /// Returns false when Health Connect must be installed first (Android only).
  Future<bool> requestHealthConnectPermissions() async {
    _health ??= Health();
    await _health!.configure();

    if (Platform.isAndroid) {
      final status = await _health!.getHealthConnectSdkStatus();
      if (kDebugMode) {
        debugPrint('[Metrics] Opening permission sheet — SDK status: $status');
      }
      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        return false;
      }
      if (!await _health!.isHealthConnectAvailable()) {
        return false;
      }
    }

    // Required for steps on Android before Health Connect can grant access.
    await Permission.activityRecognition.request();

    final readAccess = List<HealthDataAccess>.filled(
      _healthDataTypes.length,
      HealthDataAccess.READ,
    );

    if (kDebugMode) {
      debugPrint('[Metrics] Launching Health Connect permission sheet…');
    }

    final granted = await _health!.requestAuthorization(
      _healthDataTypes,
      permissions: readAccess,
    );

    if (kDebugMode) {
      debugPrint('[Metrics] Permission sheet result: $granted');
    }

    if (granted) return true;

    for (final type in _healthDataTypes) {
      if (await _health!.hasPermissions([type]) == true) {
        return true;
      }
    }
    return false;
  }

  /// Opens the Health Connect permission sheet (or Apple Health on iOS).
  Future<HealthConnectConnectResult> connectHealthConnect() async {
    try {
      final canRequest = await requestHealthConnectPermissions();
      if (!canRequest && Platform.isAndroid) {
        final status = await _health?.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable ||
            status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
            !await (_health?.isHealthConnectAvailable() ?? Future.value(false))) {
          await installHealthConnectApp();
          return HealthConnectConnectResult.needsInstall;
        }
      }

      await reinitializeMetricsSource();

      return canRequest
          ? HealthConnectConnectResult.connected
          : HealthConnectConnectResult.denied;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Metrics] connectHealthConnect error: $e');
      }
      return HealthConnectConnectResult.error;
    }
  }

  Future<void> installHealthConnectApp() async {
    if (!Platform.isAndroid) return;
    _health ??= Health();
    await _health!.configure();
    await _health!.installHealthConnect();
  }

  void dispose() {
    _disposeActiveSource();
    _isInitialized = false;
    _loggedActiveSource = false;
  }
}
