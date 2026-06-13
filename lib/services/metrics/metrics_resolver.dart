/// Pure helpers for resolving distance and stride from steps + height.
class MetricsResolver {
  static const defaultStrideMeters = 0.70;

  /// stride_length_m = height_cm * 0.415 / 100, or 0.70 m fallback.
  static double strideLengthMeters({double? heightCm}) {
    if (heightCm != null && heightCm > 0) {
      return heightCm * 0.415 / 100.0;
    }
    return defaultStrideMeters;
  }

  /// distance_km = steps * stride_length_m / 1000
  static double estimateDistanceKm(int steps, {double? heightCm}) {
    if (steps <= 0) return 0;
    final stride = strideLengthMeters(heightCm: heightCm);
    return steps * stride / 1000.0;
  }
}
