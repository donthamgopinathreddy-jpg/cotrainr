import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Listenable bridge so GoRouter re-evaluates redirects on auth/startup changes.
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh();

  StreamSubscription<AuthState>? _authSub;
  bool _bound = false;

  bool get isBound => _bound;

  /// Safe to call repeatedly (e.g. from the router redirect): binds once
  /// Supabase is initialized and stays a no-op afterwards.
  void bindAuthIfReady() {
    if (_bound) return;
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        notifyListeners();
      });
      _bound = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoRouterAuthRefresh: auth not ready yet ($e)');
      }
    }
  }

  void notifyStartupChanged() => notifyListeners();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final goRouterAuthRefresh = GoRouterAuthRefresh();
