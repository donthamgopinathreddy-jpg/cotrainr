import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_metrics_snapshot.dart';
import '../services/health_tracking_service.dart';

/// Provider for health tracking service (singleton - do not dispose, used by background tracker)
final healthTrackingServiceProvider = Provider<HealthTrackingService>((ref) {
  final service = HealthTrackingService();
  service.initialize();
  return service;
});

/// Unified daily metrics with source metadata — updates every 30 seconds.
class DailyMetricsNotifier extends StateNotifier<AsyncValue<DailyMetricsSnapshot>> {
  final HealthTrackingService _service;
  Timer? _updateTimer;

  DailyMetricsNotifier(this._service) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      await _update();
      _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _update();
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _update() async {
    try {
      final snapshot = await _service.getTodaySnapshot();
      state = AsyncValue.data(snapshot);
    } catch (e, st) {
      if (state.hasValue) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _update();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

final dailyMetricsProvider =
    StateNotifierProvider<DailyMetricsNotifier, AsyncValue<DailyMetricsSnapshot>>(
  (ref) {
    final service = ref.watch(healthTrackingServiceProvider);
    return DailyMetricsNotifier(service);
  },
);

/// Provider for today's step count (deprecated - use dailyMetricsProvider)
final stepsNotifierProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(dailyMetricsProvider).whenData((s) => s.steps);
});

/// @deprecated Use [dailyMetricsProvider]
final stepsProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(healthTrackingServiceProvider);
  await service.initialize();
  yield await service.getTodaySteps();
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield await service.getTodaySteps();
  }
});

/// @deprecated Use [dailyMetricsProvider]
final caloriesProvider = FutureProvider<double>((ref) async {
  final async = ref.watch(dailyMetricsProvider);
  return async.value?.activeCalories ?? 0.0;
});

/// @deprecated Use [dailyMetricsProvider]
final distanceProvider = FutureProvider<double>((ref) async {
  final async = ref.watch(dailyMetricsProvider);
  return async.value?.distanceKm ?? 0.0;
});
