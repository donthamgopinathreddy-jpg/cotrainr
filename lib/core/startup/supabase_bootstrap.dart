import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Guards [Supabase.initialize] so Flutter UI can still render on failure.
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _initialized = false;
  static Object? lastError;

  static bool get isInitialized => _initialized;

  /// Idempotent. Returns true when the Supabase client is ready.
  static Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _initialized = true;
      lastError = null;
      return true;
    } catch (e) {
      lastError = e;
      _initialized = false;
      return false;
    }
  }

  /// Test-only: reset static flags between widget/unit tests.
  static void debugReset() {
    _initialized = false;
    lastError = null;
  }

  /// Test-only: mark as initialized without calling the SDK.
  static void debugMarkInitialized() {
    _initialized = true;
    lastError = null;
  }
}
