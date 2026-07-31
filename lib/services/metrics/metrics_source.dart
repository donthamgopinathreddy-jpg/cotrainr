import 'package:flutter/foundation.dart';

import '../../models/daily_metrics_snapshot.dart';

/// Which backend supplies movement metrics.
///
/// [deviceSensors] is retained only for empty/legacy snapshots — the app never
/// activates phone sensors as a live metrics source.
enum MetricsSourceKind {
  healthConnect,
  deviceSensors,
}

/// Unified read API for steps, calories, distance, and water.
abstract class MetricsSource {
  MetricsSourceKind get kind;
  String get debugLabel;

  Future<void> initialize();

  /// Optional user height (cm) for step-based distance estimation.
  void setUserHeightCm(double? heightCm) {}

  Future<DailyMetricsSnapshot> getTodaySnapshot();

  Future<int> getTodaySteps();
  Future<double> getTodayCalories();
  Future<double> getTodayDistance();
  Future<double> getTodayWater();
  void dispose();
}

void logActiveMetricsSource(MetricsSource source) {
  if (!kDebugMode) return;
  switch (source.kind) {
    case MetricsSourceKind.healthConnect:
      debugPrint('[Metrics] Using Health Connect / Apple Health');
    case MetricsSourceKind.deviceSensors:
      debugPrint(
        '[Metrics] WARNING: device sensors source should not be active',
      );
  }
}
