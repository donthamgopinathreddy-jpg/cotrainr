import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../models/daily_metrics_snapshot.dart';
import 'metrics_resolver.dart';
import 'metrics_source.dart';

/// Reads steps, calories, distance, and water from Health Connect / Apple Health.
/// Does not use GPS or phone sensors.
class HealthConnectMetricsSource implements MetricsSource {
  final Health _health;
  double? _heightCm;

  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.WATER,
  ];

  HealthConnectMetricsSource(this._health);

  @override
  MetricsSourceKind get kind => MetricsSourceKind.healthConnect;

  @override
  String get debugLabel => 'Health Connect';

  @override
  void setUserHeightCm(double? heightCm) => _heightCm = heightCm;

  @override
  Future<void> initialize() async {}

  DateTime _startOfDay([DateTime? day]) {
    final now = day ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<bool> _hasPermission(HealthDataType type) async {
    try {
      return await _health.hasPermissions([type]) == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<HealthDataPoint>> _read(
    HealthDataType type, {
    DateTime? day,
  }) async {
    if (!await _hasPermission(type)) return [];
    try {
      final start = _startOfDay(day);
      final end = day == null
          ? DateTime.now()
          : DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
      return await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Metrics] Health Connect read failed for ${type.name}: $e');
      }
      return [];
    }
  }

  double _sumNumeric(List<HealthDataPoint> points) {
    var total = 0.0;
    for (final data in points) {
      if (data.value is NumericHealthValue) {
        total += (data.value as NumericHealthValue).numericValue;
      }
    }
    return total;
  }

  Future<DailyMetricsSnapshot> _buildSnapshot({DateTime? day}) async {
    final stepsGranted = await _hasPermission(HealthDataType.STEPS);
    final activeCalGranted =
        await _hasPermission(HealthDataType.ACTIVE_ENERGY_BURNED);
    final totalCalGranted =
        await _hasPermission(HealthDataType.TOTAL_CALORIES_BURNED);
    final distanceGranted =
        await _hasPermission(HealthDataType.DISTANCE_WALKING_RUNNING);

    final steps = stepsGranted
        ? _sumNumeric(await _read(HealthDataType.STEPS, day: day)).round()
        : 0;

    var calories = 0.0;
    var caloriesSource = CaloriesSource.unavailable;
    if (activeCalGranted) {
      calories = _sumNumeric(
        await _read(HealthDataType.ACTIVE_ENERGY_BURNED, day: day),
      );
      if (calories > 0) {
        caloriesSource = CaloriesSource.healthConnectActive;
      }
    }
    if (calories <= 0 && totalCalGranted) {
      final total = _sumNumeric(
        await _read(HealthDataType.TOTAL_CALORIES_BURNED, day: day),
      );
      if (total > 0) {
        calories = total;
        caloriesSource = CaloriesSource.healthConnectTotal;
      }
    }
    if (calories <= 0) {
      caloriesSource = (!activeCalGranted && !totalCalGranted)
          ? CaloriesSource.permissionDenied
          : CaloriesSource.unavailable;
    }

    var distanceKm = 0.0;
    var distanceSource = DistanceSource.unavailable;
    if (distanceGranted) {
      final meters = _sumNumeric(
        await _read(HealthDataType.DISTANCE_WALKING_RUNNING, day: day),
      );
      if (meters > 0) {
        distanceKm = meters / 1000.0;
        distanceSource = DistanceSource.healthConnect;
      }
    }

    if (distanceKm <= 0 && steps > 0) {
      distanceKm = MetricsResolver.estimateDistanceKm(
        steps,
        heightCm: _heightCm,
      );
      if (distanceKm > 0) {
        distanceSource = DistanceSource.estimatedFromSteps;
      }
    } else if (distanceKm <= 0 && !distanceGranted && steps <= 0) {
      distanceSource = DistanceSource.permissionDenied;
    }

    final water = _sumNumeric(await _read(HealthDataType.WATER, day: day));

    return DailyMetricsSnapshot(
      steps: steps,
      activeCalories: calories,
      distanceKm: distanceKm,
      waterLiters: water,
      distanceSource: distanceSource,
      caloriesSource: caloriesSource,
      metricsSourceKind: MetricsSourceKind.healthConnect,
      stepsPermissionGranted: stepsGranted,
      caloriesPermissionGranted: activeCalGranted || totalCalGranted,
      distancePermissionGranted: distanceGranted,
    );
  }

  @override
  Future<DailyMetricsSnapshot> getTodaySnapshot() => _buildSnapshot();

  /// Snapshot for a specific calendar day (used for weekly backfill reads).
  Future<DailyMetricsSnapshot> getSnapshotForDay(DateTime day) =>
      _buildSnapshot(day: day);

  @override
  Future<int> getTodaySteps() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.steps;
  }

  @override
  Future<double> getTodayCalories() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.activeCalories;
  }

  @override
  Future<double> getTodayDistance() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.distanceKm;
  }

  @override
  Future<double> getTodayWater() async {
    final snapshot = await getTodaySnapshot();
    return snapshot.waterLiters;
  }

  @override
  void dispose() {}

  Future<Map<String, bool>> permissionSnapshot() async {
    final map = <String, bool>{};
    for (final type in _readTypes) {
      map[type.name] = await _hasPermission(type);
    }
    return map;
  }
}
