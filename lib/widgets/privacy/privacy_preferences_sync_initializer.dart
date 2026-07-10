import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/privacy_preferences_service.dart';

/// Syncs sharing preferences from Supabase into local cache once per auth session.
class PrivacyPreferencesSyncInitializer extends StatefulWidget {
  final Widget child;

  const PrivacyPreferencesSyncInitializer({super.key, required this.child});

  @override
  State<PrivacyPreferencesSyncInitializer> createState() =>
      _PrivacyPreferencesSyncInitializerState();
}

class _PrivacyPreferencesSyncInitializerState
    extends State<PrivacyPreferencesSyncInitializer> {
  final PrivacyPreferencesService _service = PrivacyPreferencesService();
  StreamSubscription<AuthState>? _authSubscription;
  String? _syncedUserId;
  bool _syncInFlight = false;

  @override
  void initState() {
    super.initState();
    _syncForCurrentSessionIfNeeded();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthStateChange);
  }

  void _onAuthStateChange(AuthState authState) {
    final userId = authState.session?.user.id;
    if (userId == null) {
      _syncedUserId = null;
      return;
    }
    if (userId == _syncedUserId) return;
    _syncForUser(userId);
  }

  void _syncForCurrentSessionIfNeeded() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (kDebugMode) {
        debugPrint(
          '[PrivacyPreferences] Startup sync skipped: no authenticated user',
        );
      }
      return;
    }
    if (userId == _syncedUserId) return;
    _syncForUser(userId);
  }

  Future<void> _syncForUser(String userId) async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      await _service.load();
      _syncedUserId = userId;
      if (kDebugMode) {
        debugPrint(
          '[PrivacyPreferences] Synced sharing preferences from Supabase',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PrivacyPreferences] Startup sync failed: $e');
      }
    } finally {
      _syncInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
