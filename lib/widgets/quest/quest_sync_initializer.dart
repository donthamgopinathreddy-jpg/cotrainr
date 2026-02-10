import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/quest_provider.dart';
import '../../services/background_health_tracker.dart';

/// Widget that initializes quest progress syncing when user is authenticated
class QuestSyncInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const QuestSyncInitializer({super.key, required this.child});

  @override
  ConsumerState<QuestSyncInitializer> createState() => _QuestSyncInitializerState();
}

class _QuestSyncInitializerState extends ConsumerState<QuestSyncInitializer> {
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAndInitialize();
    _setupAuthListener();
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
    final syncService = ref.read(questProgressSyncServiceProvider);
    syncService.startAutoSync();
    
    // Start background health tracking
    final backgroundTracker = ref.read(backgroundHealthTrackerProvider);
    backgroundTracker.startTracking();
    
    _isInitialized = true;
    print('QuestSyncInitializer: Started auto-sync for quest progress and background health tracking');
  }

  void _stopSync() {
    final syncService = ref.read(questProgressSyncServiceProvider);
    syncService.stopAutoSync();
    
    // Stop background health tracking
    final backgroundTracker = ref.read(backgroundHealthTrackerProvider);
    backgroundTracker.stopTracking();
    
    _isInitialized = false;
    print('QuestSyncInitializer: Stopped auto-sync for quest progress and background health tracking');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (_isInitialized) {
      _stopSync();
    }
    super.dispose();
  }
}
