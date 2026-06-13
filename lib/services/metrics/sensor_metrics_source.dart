import '../../models/daily_metrics_snapshot.dart';
import 'metrics_source.dart';

/// Fallback when Health Connect is unavailable on device.
/// Does not use GPS, pedometer, or accelerometer — avoids duplicate counting.
class SensorMetricsSource implements MetricsSource {
  @override
  MetricsSourceKind get kind => MetricsSourceKind.deviceSensors;

  @override
  String get debugLabel => 'Device Sensors (Fallback)';

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
