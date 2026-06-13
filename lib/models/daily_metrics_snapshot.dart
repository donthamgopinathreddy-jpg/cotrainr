import '../services/metrics/metrics_source.dart';

/// Where today's distance value came from.
enum DistanceSource {
  healthConnect,
  estimatedFromSteps,
  unavailable,
  permissionDenied,
}

/// Where today's calorie value came from.
enum CaloriesSource {
  healthConnectActive,
  healthConnectTotal,
  unavailable,
  permissionDenied,
}

extension DistanceSourceLabel on DistanceSource {
  /// Short label for home metric cards.
  String get homeLabel => switch (this) {
        DistanceSource.healthConnect => 'Health Connect',
        DistanceSource.estimatedFromSteps => 'Estimated',
        DistanceSource.permissionDenied =>
          'Allow Health Connect permission to show this metric.',
        DistanceSource.unavailable => '',
      };

  /// Longer note for weekly insights.
  String get insightsNote => switch (this) {
        DistanceSource.healthConnect => 'Distance from Health Connect.',
        DistanceSource.estimatedFromSteps =>
          'Distance estimated from steps using your height.',
        DistanceSource.permissionDenied =>
          'Allow Health Connect permission to show this metric.',
        DistanceSource.unavailable => '',
      };
}

extension CaloriesSourceLabel on CaloriesSource {
  String get homeLabel => switch (this) {
        CaloriesSource.healthConnectActive => 'Active calories',
        CaloriesSource.healthConnectTotal => 'Total calories',
        CaloriesSource.permissionDenied =>
          'Allow Health Connect permission to show this metric.',
        CaloriesSource.unavailable => '',
      };

  String get insightsNote => switch (this) {
        CaloriesSource.healthConnectActive => 'Active calories from Health Connect.',
        CaloriesSource.healthConnectTotal =>
          'Total calories from Health Connect (active calories unavailable).',
        CaloriesSource.permissionDenied =>
          'Allow Health Connect permission to show this metric.',
        CaloriesSource.unavailable => '',
      };
}

/// Unified daily movement metrics with source metadata.
class DailyMetricsSnapshot {
  final int steps;
  final double activeCalories;
  final double distanceKm;
  final double waterLiters;
  final DistanceSource distanceSource;
  final CaloriesSource caloriesSource;
  final MetricsSourceKind metricsSourceKind;
  final bool stepsPermissionGranted;
  final bool caloriesPermissionGranted;
  final bool distancePermissionGranted;

  const DailyMetricsSnapshot({
    required this.steps,
    required this.activeCalories,
    required this.distanceKm,
    required this.waterLiters,
    required this.distanceSource,
    required this.caloriesSource,
    required this.metricsSourceKind,
    this.stepsPermissionGranted = true,
    this.caloriesPermissionGranted = true,
    this.distancePermissionGranted = true,
  });

  factory DailyMetricsSnapshot.empty({
    MetricsSourceKind kind = MetricsSourceKind.deviceSensors,
  }) {
    return DailyMetricsSnapshot(
      steps: 0,
      activeCalories: 0,
      distanceKm: 0,
      waterLiters: 0,
      distanceSource: DistanceSource.unavailable,
      caloriesSource: CaloriesSource.unavailable,
      metricsSourceKind: kind,
      stepsPermissionGranted: false,
      caloriesPermissionGranted: false,
      distancePermissionGranted: false,
    );
  }

  /// Backward-compatible alias — home calorie metric is active (or total fallback).
  double get calories => activeCalories;
}
