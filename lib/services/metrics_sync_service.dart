import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/health_tracking_service.dart';
import '../repositories/metrics_repository.dart';

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
    print('MetricsSyncService: Starting sync...');
    _syncTimer?.cancel(); // Cancel any existing timer
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncMetrics();
    });
    _syncMetrics(); // Run immediately on start
  }

  /// Stop periodic sync
  void stopSync() {
    print('MetricsSyncService: Stopping sync.');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Sync current health metrics to Supabase
  Future<void> _syncMetrics() async {
    if (_isSyncing) {
      print('MetricsSyncService: Sync already in progress, skipping...');
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('MetricsSyncService: User not authenticated, skipping sync.');
      return;
    }

    _isSyncing = true;
    try {
      print('MetricsSyncService: Syncing metrics to Supabase...');
      
      final healthService = HealthTrackingService();
      final metricsRepo = MetricsRepository();

      // Ensure health service is initialized
      final initialized = await healthService.initialize();
      if (!initialized) {
        print('MetricsSyncService: WARNING - Health service failed to initialize');
        // Check permissions
        final permissions = await healthService.checkPermissions();
        print('MetricsSyncService: Permissions status: $permissions');
      }

      // Test sensors periodically (every 10 syncs = ~5 minutes)
      _syncCount++;
      if (_syncCount % 10 == 1) {
        print('MetricsSyncService: Running sensor diagnostics...');
        final sensorTest = await healthService.testSensors();
        print('MetricsSyncService: Sensor test results: $sensorTest');
      }

      // Get current metrics from device sensors
      print('MetricsSyncService: Fetching steps from sensor...');
      final steps = await healthService.getTodaySteps();
      
      print('MetricsSyncService: Fetching calories from sensor...');
      final calories = await healthService.getTodayCalories();
      
      print('MetricsSyncService: Fetching distance from sensor...');
      final distance = await healthService.getTodayDistance();

      print('MetricsSyncService: Sensor data - Steps: $steps, Calories: $calories, Distance: $distance km');

      // Update Supabase metrics_daily table
      await metricsRepo.updateTodayMetrics(
        steps: steps,
        caloriesBurned: calories,
        distanceKm: distance,
      );

      print('MetricsSyncService: Metrics synced successfully to Supabase');
    } catch (e, stackTrace) {
      print('MetricsSyncService: Error syncing metrics: $e');
      print('MetricsSyncService: Stack trace: $stackTrace');
    } finally {
      _isSyncing = false;
    }
  }

  /// Manually trigger a sync (useful for pull-to-refresh)
  Future<void> syncNow() async {
    await _syncMetrics();
  }

  void dispose() {
    _syncTimer?.cancel();
    _authStateSubscription?.cancel();
  }
}
