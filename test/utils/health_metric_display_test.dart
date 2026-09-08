import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/models/daily_metrics_snapshot.dart';
import 'package:cotrainr/services/metrics/metrics_source.dart';
import 'package:cotrainr/utils/health_metric_display.dart';

DailyMetricsSnapshot snapshot({
  int steps = 0,
  double calories = 0,
  double distance = 0,
  bool stepsGranted = true,
  bool caloriesGranted = true,
  bool distanceGranted = true,
}) {
  return DailyMetricsSnapshot(
    steps: steps,
    activeCalories: calories,
    distanceKm: distance,
    waterLiters: 0,
    distanceSource: distanceGranted
        ? DistanceSource.healthConnect
        : DistanceSource.permissionDenied,
    caloriesSource: caloriesGranted
        ? CaloriesSource.healthConnectActive
        : CaloriesSource.permissionDenied,
    metricsSourceKind: MetricsSourceKind.healthConnect,
    stepsPermissionGranted: stepsGranted,
    caloriesPermissionGranted: caloriesGranted,
    distancePermissionGranted: distanceGranted,
  );
}

void main() {
  group('health metric display fallbacks', () {
    test('permission denied with no cache renders unavailable', () {
      final result = resolveHomeSteps(
        cached: 0,
        live: snapshot(stepsGranted: false),
      );

      expect(result.available, isFalse);
      expect(result.displayInt, '—');
    });

    test('permission denied preserves last synced cache', () {
      final result = resolveHomeSteps(
        cached: 4321,
        live: snapshot(stepsGranted: false),
      );

      expect(result.available, isTrue);
      expect(result.value, 4321);
    });

    test('live value never replaces a higher same-day cached total', () {
      final result = resolveHomeCalories(
        cached: 425,
        live: snapshot(calories: 0, caloriesGranted: true),
      );

      expect(result.available, isTrue);
      expect(result.value, 425);
    });

    test('valid live value supersedes lower cache', () {
      final result = resolveHomeDistance(
        cached: 2.4,
        live: snapshot(distance: 4.1),
      );

      expect(result.available, isTrue);
      expect(result.value, 4.1);
    });

    test('no live snapshot may still use persisted cache', () {
      final result = resolveHomeSteps(cached: 2100, live: null);

      expect(result.available, isTrue);
      expect(result.value, 2100);
    });
  });
}
