import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'health_tracking_service.dart';
import 'metrics_sync_service.dart';
import '../providers/quest_provider.dart';

/// Provider for background health tracker
final backgroundHealthTrackerProvider = Provider<BackgroundHealthTracker>((ref) {
  return BackgroundHealthTracker(ref);
});

/// Service that continuously tracks health data in the background
/// and syncs to Supabase and quests
class BackgroundHealthTracker {
  final Ref _ref;
  Timer? _trackingTimer;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isTracking = false;

  BackgroundHealthTracker(this._ref) {
    // Listen to auth state changes
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        startTracking();
      } else if (event == AuthChangeEvent.signedOut) {
        stopTracking();
      }
    });

    // Start tracking if already signed in
    if (Supabase.instance.client.auth.currentUser != null) {
      startTracking();
    }
  }

  /// Start continuous background tracking
  void startTracking() {
    if (_isTracking) {
      print('BackgroundHealthTracker: Already tracking');
      return;
    }

    print('BackgroundHealthTracker: Starting background health tracking...');
    _isTracking = true;

    // Track immediately
    _trackAndSync();

    // Then track every 30 seconds
    _trackingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _trackAndSync();
    });
  }

  /// Stop background tracking
  void stopTracking() {
    print('BackgroundHealthTracker: Stopping background health tracking');
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _isTracking = false;
  }

  /// Track health data and sync to Supabase and quests
  Future<void> _trackAndSync() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('BackgroundHealthTracker: User not authenticated, skipping track');
      return;
    }

    try {
      print('BackgroundHealthTracker: Starting track cycle...');

      // 1. Get health data from sensors
      final healthService = HealthTrackingService();
      
      // Ensure initialized
      final initialized = await healthService.initialize();
      if (!initialized) {
        print('BackgroundHealthTracker: Health service not initialized, skipping');
        return;
      }

      // Read from sensors
      print('BackgroundHealthTracker: Reading from sensors...');
      final steps = await healthService.getTodaySteps();
      final calories = await healthService.getTodayCalories();
      final distance = await healthService.getTodayDistance();

      print('BackgroundHealthTracker: Sensor data - Steps: $steps, Calories: $calories, Distance: $distance km');

      // 2. Sync to Supabase metrics_daily
      final metricsSyncService = _ref.read(metricsSyncServiceProvider);
      await metricsSyncService.syncNow();

      // 3. Sync metrics to quest progress
      final questSyncService = _ref.read(questProgressSyncServiceProvider);
      await questSyncService.syncMetricsToQuests();

      print('BackgroundHealthTracker: Track cycle complete');
    } catch (e, stackTrace) {
      print('BackgroundHealthTracker: Error in track cycle: $e');
      print('BackgroundHealthTracker: Stack trace: $stackTrace');
    }
  }

  /// Manually trigger a track cycle
  Future<void> trackNow() async {
    await _trackAndSync();
  }

  void dispose() {
    stopTracking();
    _authStateSubscription?.cancel();
  }
}
