import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

/// Listenable bridge so GoRouter re-evaluates redirects on auth/startup changes.
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh();

  StreamSubscription<AuthState>? _authSub;
  bool _bound = false;

  void bindAuthIfReady() {
    if (_bound || !SupabaseBootstrap.isInitialized) return;
    _bound = true;
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  void notifyStartupChanged() => notifyListeners();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final goRouterAuthRefresh = GoRouterAuthRefresh();
