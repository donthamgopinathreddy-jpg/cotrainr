import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_tracking_service.dart';

/// Provider for health tracking service
final healthTrackingServiceProvider = Provider<HealthTrackingService>((ref) {
  final service = HealthTrackingService();
  // Initialize service when provider is first accessed
  service.initialize();
  // Dispose service when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Provider for today's step count (deprecated - use stepsNotifierProvider instead)
/// Updates every 30 seconds to track steps in background
final stepsProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(healthTrackingServiceProvider);
  
  // Initialize service if not already initialized
  await service.initialize();
  
  // Emit initial value
  int currentSteps = await service.getTodaySteps();
  yield currentSteps;
  
  // Keep stream alive and update every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      final steps = await service.getTodaySteps();
      if (steps != currentSteps) {
        currentSteps = steps;
        yield steps;
      }
    } catch (e) {
      print('Error updating steps: $e');
    }
  }
});

/// StateNotifier for step count with periodic updates
class StepsNotifier extends StateNotifier<AsyncValue<int>> {
  final HealthTrackingService _service;
  Timer? _updateTimer;
  int? _lastSteps;

  StepsNotifier(this._service) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      await _updateSteps();
      // Start periodic updates every 30 seconds for background tracking
      _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _updateSteps();
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> _updateSteps() async {
    try {
      final steps = await _service.getTodaySteps();
      // Always update state if value changed or if it's the first load
      if (_lastSteps != steps || state.isLoading) {
        _lastSteps = steps;
        state = AsyncValue.data(steps);
      }
    } catch (e) {
      // On error, keep last known value if available
      if (state.hasValue) {
        // Keep current value
        return;
      }
      state = AsyncValue.error(e, StackTrace.current);
      print('Error updating steps: $e');
    }
  }

  /// Manually refresh steps
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _updateSteps();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Provider for step count with periodic background updates
final stepsNotifierProvider = StateNotifierProvider<StepsNotifier, AsyncValue<int>>((ref) {
  final service = ref.watch(healthTrackingServiceProvider);
  return StepsNotifier(service);
});

/// Provider for today's calories
final caloriesProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(healthTrackingServiceProvider);
  await service.initialize();
  return await service.getTodayCalories();
});

/// Provider for today's distance
final distanceProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(healthTrackingServiceProvider);
  await service.initialize();
  return await service.getTodayDistance();
});
