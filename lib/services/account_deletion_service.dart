import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'water_reminder_service.dart';

/// Calls the authenticated server-side account deletion endpoint.
///
/// The Edge Function derives the actor from the verified JWT and performs all
/// destructive cleanup with service-role privileges. The Flutter client never
/// supplies a user id.
class AccountDeletionService {
  AccountDeletionService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Lazily resolved so constructing the service (e.g. Settings open) does not
  /// require Supabase to already be initialized in widget tests.
  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  Future<void> deleteCurrentAccount() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('You must be signed in to delete your account.');
    }

    final response = await _client.functions.invoke('delete-account');
    final data = response.data;
    final ok = data is Map && data['ok'] == true;
    if (!ok) {
      throw StateError('Account deletion failed. Please try again.');
    }

    // The server has permanently deleted the account at this point. Local
    // user-specific state must not survive and leak into a future account on
    // the same device. Cleanup is best-effort so a local plugin failure cannot
    // turn a completed server deletion into a misleading failure.
    try {
      await WaterReminderService.instance.cancelAll();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // The server has already deleted auth.users. Clear any remaining local
    // Supabase auth state without reporting a false account-deletion failure.
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
