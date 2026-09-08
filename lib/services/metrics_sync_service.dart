import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/metrics_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/health_tracking_service.dart';

/// Provider for metrics sync service
final metricsSyncServiceProvider = Provider<MetricsSyncService>((ref) {
  return MetricsSyncService(ref);
});

/// Service that syncs health tracking data to Supabase metrics_daily table
class MetricsSyncService {
  Timer? _syncTimer;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isSyncing = false;
  int _syncCount = 0;
  DateTime? _lastWeeklyBackfillAt;

  MetricsSyncService(Ref ref) {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        startSync();
      } else if (event == AuthChangeEvent.signedOut) {
        stopSync();
      }
    });

    if (Supabase.instance.client.auth.currentUser != null) {
      startSync();
    }
  }

  /// Start periodic sync of health metrics to Supabase
  void startSync() {
    if (kDebugMode) debugPrint('MetricsSyncService: starting sync');
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncMetrics();
    });
    _syncMetrics();
  }

  /// Stop periodic sync
  void stopSync() {
    if (kDebugMode) debugPrint('MetricsSyncService: stopping sync');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Sync current health metrics to Supabase.
  ///
  /// Platform-health unavailability is fail-closed: no health-derived values are
  /// written. For individual denied/transiently-empty metrics, preserve an
  /// existing positive daily total rather than erasing it with zero.
  Future<void> _syncMetrics() async {
    if (_isSyncing) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _isSyncing = true;
    try {
      if (kDebugMode) debugPrint('MetricsSyncService: syncing');

      final healthService = HealthTrackingService();
      final initialized = await healthService.initialize();
      await _applyProfileHeight(healthService);
      if (!initialized) {
        if (kDebugMode) {
          debugPrint(
            'MetricsSyncService: health source unavailable; preserving stored metrics',
          );
        }
        return;
      }

      _syncCount++;
      if (kDebugMode) {
        debugPrint('[Metrics] Sync via ${healthService.activeSourceLabel}');
      }

      final snapshot = await healthService.getTodaySnapshot();
      final metricsRepo = MetricsRepository();
      final existing = await metricsRepo.getTodayMetrics();

      final existingSteps = (existing?['steps'] as num?)?.toInt() ?? 0;
      final existingCalories =
          (existing?['calories_burned'] as num?)?.toDouble() ?? 0.0;
      final existingDistance =
          (existing?['distance_km'] as num?)?.toDouble() ?? 0.0;
      final manualWater =
          (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;

      int? stepsToSave;
      if (snapshot.stepsPermissionGranted) {
        stepsToSave = snapshot.steps == 0 && existingSteps > 0
            ? existingSteps
            : snapshot.steps;
      }

      double? caloriesToSave;
      if (snapshot.caloriesPermissionGranted) {
        caloriesToSave = snapshot.activeCalories <= 0 && existingCalories > 0
            ? existingCalories
            : snapshot.activeCalories;
      }

      double? distanceToSave;
      if (snapshot.distancePermissionGranted || snapshot.steps > 0) {
        distanceToSave = snapshot.distanceKm <= 0 && existingDistance > 0
            ? existingDistance
            : snapshot.distanceKm;
      }

      final waterToSave = snapshot.waterLiters > manualWater
          ? snapshot.waterLiters
          : manualWater;

      await metricsRepo.updateTodayMetrics(
        steps: stepsToSave,
        caloriesBurned: caloriesToSave,
        distanceKm: distanceToSave,
        waterIntakeLiters: waterToSave,
      );

      if (kDebugMode) debugPrint('MetricsSyncService: sync complete');

      await _backfillPriorWeekDays(
        healthService: healthService,
        metricsRepo: metricsRepo,
        force: false,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('MetricsSyncService: sync failed');
        debugPrint('$stackTrace');
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull Health Connect history for the prior 6 days into metrics_daily.
  Future<void> _backfillPriorWeekDays({
    required HealthTrackingService healthService,
    required MetricsRepository metricsRepo,
    required bool force,
  }) async {
    if (!force &&
        _lastWeeklyBackfillAt != null &&
        DateTime.now().difference(_lastWeeklyBackfillAt!) <
            const Duration(hours: 1)) {
      return;
    }
    if (!force && _syncCount > 1 && _syncCount % 20 != 1) {
      return;
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var wrote = 0;

      for (var i = 1; i <= 6; i++) {
        final day = today.subtract(Duration(days: i));
        final snapshot = await healthService.getSnapshotForDay(day);
        final existing = await metricsRepo.getMetricsForDate(day);

        final existingSteps = (existing?['steps'] as num?)?.toInt() ?? 0;
        final existingCalories =
            (existing?['calories_burned'] as num?)?.toDouble() ?? 0.0;
        final existingDistance =
            (existing?['distance_km'] as num?)?.toDouble() ?? 0.0;
        final existingWater =
            (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;

        int? stepsToSave;
        if (snapshot.stepsPermissionGranted) {
          stepsToSave = snapshot.steps == 0 && existingSteps > 0
              ? existingSteps
              : snapshot.steps;
        }

        double? caloriesToSave;
        if (snapshot.caloriesPermissionGranted) {
          caloriesToSave = snapshot.activeCalories <= 0 && existingCalories > 0
              ? existingCalories
              : snapshot.activeCalories;
        }

        double? distanceToSave;
        if (snapshot.distancePermissionGranted || snapshot.steps > 0) {
          distanceToSave = snapshot.distanceKm <= 0 && existingDistance > 0
              ? existingDistance
              : snapshot.distanceKm;
        }

        final waterToSave = snapshot.waterLiters > existingWater
            ? snapshot.waterLiters
            : existingWater;

        final hasAnythingToWrite = stepsToSave != null ||
            caloriesToSave != null ||
            distanceToSave != null ||
            waterToSave > 0;
        if (!hasAnythingToWrite) continue;

        await metricsRepo.updateMetricsForDate(
          day,
          steps: stepsToSave,
          caloriesBurned: caloriesToSave,
          distanceKm: distanceToSave,
          waterIntakeLiters: waterToSave > 0 ? waterToSave : null,
        );
        wrote++;
      }

      _lastWeeklyBackfillAt = DateTime.now();
      if (kDebugMode) {
        debugPrint('MetricsSyncService: weekly backfill wrote $wrote days');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MetricsSyncService: weekly backfill failed: $e');
      }
    }
  }

  /// Load user height from profile for step-based distance estimation.
  Future<void> _applyProfileHeight(HealthTrackingService healthService) async {
    try {
      final profileRepo = ProfileRepository();
      final profile = await profileRepo.fetchMyProfile();
      final heightCm = (profile?['height_cm'] as num?)?.toDouble();
      healthService.setUserHeightCm(heightCm);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Metrics] Could not load profile height: $e');
      }
    }
  }

  /// Manually trigger a sync (useful for pull-to-refresh)
  Future<void> syncNow() async {
    await _syncMetrics();

    try {
      final healthService = HealthTrackingService();
      final initialized = await healthService.initialize();
      if (!initialized) return;
      await _applyProfileHeight(healthService);
      await _backfillPriorWeekDays(
        healthService: healthService,
        metricsRepo: MetricsRepository(),
        force: true,
      );
    } catch (_) {}
  }

  void dispose() {
    _syncTimer?.cancel();
    _authStateSubscription?.cancel();
  }
}
