import '../../models/daily_metrics_snapshot.dart';
import 'metrics_source.dart';

/// Deprecated stub — Cotrainr no longer uses phone sensors for metrics.
/// Kept so older snapshot kinds deserialize safely; never activated.
class SensorMetricsSource implements MetricsSource {
  @override
  MetricsSourceKind get kind => MetricsSourceKind.deviceSensors;

  @override
  String get debugLabel => 'Device Sensors (disabled)';

  @override
  Future<void> initialize() async {}

  @override
  void setUserHeightCm(double? heightCm) {}

  @override
  Future<DailyMetricsSnapshot> getTodaySnapshot() async {
    return DailyMetricsSnapshot.empty(kind: MetricsSourceKind.deviceSensors);
  }

  @override
  Future<int> getTodaySteps() async => 0;

  @override
  Future<double> getTodayCalories() async => 0.0;

  @override
  Future<double> getTodayDistance() async => 0.0;

  @override
  Future<double> getTodayWater() async => 0.0;

  @override
  void dispose() {}
}
