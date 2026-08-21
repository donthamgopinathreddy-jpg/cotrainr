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
    // Listen to auth state changes
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        startSync();
      } else if (event == AuthChangeEvent.signedOut) {
        stopSync();
      }
    });

    // Start sync if already signed in
    if (Supabase.instance.client.auth.currentUser != null) {
      startSync();
    }
  }

  /// Start periodic sync of health metrics to Supabase
  void startSync() {
    if (kDebugMode) debugPrint('MetricsSyncService: starting sync');
    _syncTimer?.cancel(); // Cancel any existing timer
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncMetrics();
    });
    _syncMetrics(); // Run immediately on start
  }

  /// Stop periodic sync
  void stopSync() {
    if (kDebugMode) debugPrint('MetricsSyncService: stopping sync');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Sync current health metrics to Supabase
  Future<void> _syncMetrics() async {
    if (_isSyncing) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    _isSyncing = true;
    try {
      if (kDebugMode) debugPrint('MetricsSyncService: syncing');
      
      // Ensure health service is initialized and height is set for distance estimation.
      final healthService = HealthTrackingService();
      final initialized = await healthService.initialize();
      await _applyProfileHeight(healthService);
      if (!initialized && kDebugMode) {
        debugPrint('MetricsSyncService: health source not ready');
      }

      _syncCount++;
      if (kDebugMode) {
        debugPrint(
          '[Metrics] Sync via ${healthService.activeSourceLabel}',
        );
      }

      final snapshot = await healthService.getTodaySnapshot();
      final steps = snapshot.steps;
      final calories = snapshot.activeCalories;
      final distance = snapshot.distanceKm;
      final waterFromHealth = snapshot.waterLiters;

      // Merge water: use max(health, manual) to avoid overwriting manual logs with 0 from health
      final metricsRepo = MetricsRepository();
      final existing = await metricsRepo.getTodayMetrics();
      final manualWater = (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
      final waterToSave = waterFromHealth > manualWater ? waterFromHealth : manualWater;

      // Update Supabase metrics_daily table
      await metricsRepo.updateTodayMetrics(
        steps: steps,
        caloriesBurned: calories,
        distanceKm: distance,
        waterIntakeLiters: waterToSave,
      );

      if (kDebugMode) debugPrint('MetricsSyncService: sync complete');

      // Backfill last 6 prior days from Health Connect so weekly charts
      // are not empty when only today was ever written.
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
  /// Skipped when the active source cannot provide history (sensors).
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
    // Throttle periodic syncs: every ~10 min (20 × 30s) unless forced.
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
        if (snapshot.steps == 0 &&
            snapshot.activeCalories == 0 &&
            snapshot.distanceKm == 0 &&
            snapshot.waterLiters == 0) {
          continue;
        }

        final existing = await metricsRepo.getMetricsForDate(day);
        final existingWater =
            (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
        final waterToSave = snapshot.waterLiters > existingWater
            ? snapshot.waterLiters
            : existingWater;

        await metricsRepo.updateMetricsForDate(
          day,
          steps: snapshot.steps,
          caloriesBurned: snapshot.activeCalories,
          distanceKm: snapshot.distanceKm,
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
    // Force weekly backfill on explicit refresh so Home/Insights update ASAP.
    try {
      final healthService = HealthTrackingService();
      await healthService.initialize();
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
