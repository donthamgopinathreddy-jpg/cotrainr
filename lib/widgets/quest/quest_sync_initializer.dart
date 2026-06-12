import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/feature_flags.dart';
import '../../providers/quest_provider.dart';
import '../../services/background_health_tracker.dart';

/// Widget that initializes quest progress syncing when user is authenticated
class QuestSyncInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const QuestSyncInitializer({super.key, required this.child});

  @override
  ConsumerState<QuestSyncInitializer> createState() => _QuestSyncInitializerState();
}

class _QuestSyncInitializerState extends ConsumerState<QuestSyncInitializer>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndInitialize();
    _setupAuthListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Sync metrics when app resumes from background (sensors may have new data)
    if (state == AppLifecycleState.resumed && _isInitialized) {
      _syncOnResume();
    }
  }

  Future<void> _syncOnResume() async {
    try {
      final backgroundTracker = ref.read(backgroundHealthTrackerProvider);
      await backgroundTracker.trackNow();
      print('QuestSyncInitializer: Synced metrics on app resume');
    } catch (e) {
      print('QuestSyncInitializer: Error syncing on resume: $e');
    }
  }

  void _checkAndInitialize() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !_isInitialized) {
      _initializeSync();
    }
  }

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      if (authState.session?.user != null && !_isInitialized) {
        _initializeSync();
      } else if (authState.session?.user == null && _isInitialized) {
        _stopSync();
      }
    });
  }

  void _initializeSync() {
    if (FeatureFlags.enableQuest) {
      ref.read(questProgressSyncServiceProvider).startAutoSync();
    } else {
      FeatureFlags.logBlockedOnce(
        'quest_auto_sync',
        'Quest disabled: skipping quest auto sync',
      );
    }

    ref.read(backgroundHealthTrackerProvider).startTracking();

    _isInitialized = true;
    print(
      'QuestSyncInitializer: Started background health tracking'
      '${FeatureFlags.enableQuest ? ' + quest auto-sync' : ' (quest disabled)'}',
    );
  }

  void _stopSync() {
    if (FeatureFlags.enableQuest) {
      ref.read(questProgressSyncServiceProvider).stopAutoSync();
    }

    ref.read(backgroundHealthTrackerProvider).stopTracking();

    _isInitialized = false;
    print('QuestSyncInitializer: Stopped background sync services');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    if (_isInitialized) {
      _stopSync();
    }
    super.dispose();
  }
}
