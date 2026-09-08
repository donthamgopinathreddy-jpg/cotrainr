import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the authenticated server-side account deletion endpoint.
///
/// The Edge Function derives the actor from the verified JWT and performs all
/// destructive cleanup with service-role privileges. The Flutter client never
/// supplies a user id.
class AccountDeletionService {
  AccountDeletionService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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

    // The server has already deleted auth.users at this point. Clear any
    // remaining local auth state without turning a local sign-out failure into
    // a false account-deletion failure.
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
