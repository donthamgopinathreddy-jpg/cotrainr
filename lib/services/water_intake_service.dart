import 'package:flutter/foundation.dart';

import '../repositories/metrics_repository.dart';

/// Adds water intake and notifies listeners (home, insights).
class WaterIntakeService {
  WaterIntakeService._();

  static final WaterIntakeService instance = WaterIntakeService._();

  /// Bumped after water is added from UI or notification actions.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  final MetricsRepository _metricsRepo = MetricsRepository();

  Future<double?> addWater(double liters) async {
    if (liters <= 0) return null;

    try {
      await _metricsRepo.incrementWater(liters);
      final updated = await _metricsRepo.getTodayMetrics();
      final newWater =
          (updated?['water_intake_liters'] as num?)?.toDouble() ?? liters;
      revision.value++;
      if (kDebugMode) {
        debugPrint('WaterIntakeService: added ${liters}L, total $newWater L');
      }
      return newWater;
    } catch (e, stack) {
      debugPrint('WaterIntakeService: failed to add water: $e\n$stack');
      return null;
    }
  }
}
