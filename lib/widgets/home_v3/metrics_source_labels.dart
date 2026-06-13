import '../../models/daily_metrics_snapshot.dart';
import '../../services/metrics/metrics_source.dart';

/// Home card source labels for calories and distance metrics.
class MetricsSourceLabels {
  static String? caloriesNote(DailyMetricsSnapshot? metrics) {
    if (metrics == null) return null;
    if (metrics.caloriesSource == CaloriesSource.permissionDenied) {
      return metrics.caloriesSource.homeLabel;
    }
    if (metrics.caloriesSource == CaloriesSource.unavailable &&
        metrics.metricsSourceKind == MetricsSourceKind.healthConnect) {
      return null;
    }
    final label = metrics.caloriesSource.homeLabel;
    return label.isEmpty ? null : label;
  }

  static String? distanceNote(DailyMetricsSnapshot? metrics) {
    if (metrics == null) return null;
    if (metrics.distanceSource == DistanceSource.permissionDenied &&
        metrics.steps <= 0) {
      return metrics.distanceSource.homeLabel;
    }
    final label = metrics.distanceSource.homeLabel;
    return label.isEmpty ? null : label;
  }
}
