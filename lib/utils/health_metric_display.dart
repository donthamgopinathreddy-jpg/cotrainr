import '../models/daily_metrics_snapshot.dart';

/// Safe ring/bar progress for Home health metrics.
double safeMetricProgress(double current, double goal) {
  if (!current.isFinite || !goal.isFinite || goal <= 0) return 0;
  final ratio = current / goal;
  if (!ratio.isFinite) return 0;
  return ratio.clamp(0.0, 1.0).toDouble();
}

/// Prefer live Health Connect when the permission is granted.
/// If permission is off / source unavailable, keep last synced cache
/// instead of presenting a fake measured zero.
class ResolvedHomeMetric {
  final double value;
  final bool available;

  const ResolvedHomeMetric({required this.value, required this.available});

  static const unavailable = ResolvedHomeMetric(value: 0, available: false);

  String get displayInt {
    if (!available) return '—';
    final n = value.round();
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String get displayOneDecimal {
    if (!available) return '—';
    return value.toStringAsFixed(1);
  }
}

ResolvedHomeMetric resolveHomeMetric({
  required double cached,
  required DailyMetricsSnapshot? live,
  required bool Function(DailyMetricsSnapshot snapshot) permissionGranted,
  required double Function(DailyMetricsSnapshot snapshot) liveValue,
}) {
  final cachedSafe =
      cached.isFinite ? cached.clamp(0, double.infinity).toDouble() : 0.0;
  if (live == null) {
    return ResolvedHomeMetric(value: cachedSafe, available: true);
  }
  if (!permissionGranted(live)) {
    if (cachedSafe > 0) {
      return ResolvedHomeMetric(value: cachedSafe, available: true);
    }
    return ResolvedHomeMetric.unavailable;
  }
  final liveV = liveValue(live);
  final liveSafe =
      liveV.isFinite ? liveV.clamp(0, double.infinity).toDouble() : 0.0;
  final best = liveSafe >= cachedSafe ? liveSafe : cachedSafe;
  return ResolvedHomeMetric(value: best, available: true);
}

ResolvedHomeMetric resolveHomeSteps({
  required int cached,
  required DailyMetricsSnapshot? live,
}) {
  return resolveHomeMetric(
    cached: cached.toDouble(),
    live: live,
    permissionGranted: (s) => s.stepsPermissionGranted,
    liveValue: (s) => s.steps.toDouble(),
  );
}

ResolvedHomeMetric resolveHomeCalories({
  required double cached,
  required DailyMetricsSnapshot? live,
}) {
  return resolveHomeMetric(
    cached: cached,
    live: live,
    permissionGranted: (s) => s.caloriesPermissionGranted,
    liveValue: (s) => s.activeCalories,
  );
}

ResolvedHomeMetric resolveHomeDistance({
  required double cached,
  required DailyMetricsSnapshot? live,
}) {
  return resolveHomeMetric(
    cached: cached,
    live: live,
    permissionGranted: (s) =>
        s.distancePermissionGranted || s.stepsPermissionGranted,
    liveValue: (s) => s.distanceKm,
  );
}

List<double> weeklySeriesForLastSevenDays({
  required List<Map<String, dynamic>> rows,
  required String key,
  DateTime? now,
}) {
  final origin = now ?? DateTime.now();
  final dates = List.generate(7, (i) {
    final d = origin.subtract(Duration(days: 6 - i));
    return DateTime(d.year, d.month, d.day);
  });
  final map = <String, double>{};
  for (final row in rows) {
    final dateStr = row['date'] as String?;
    if (dateStr == null) continue;
    map[dateStr.split('T').first] = ((row[key] as num?) ?? 0).toDouble();
  }
  return dates
      .map((d) => map[d.toIso8601String().split('T')[0]] ?? 0.0)
      .toList();
}
