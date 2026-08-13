import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/verification_repository.dart';

/// Authoritative post-auth destination for Login / OAuth / cold start / signup.
class PostAuthDestination {
  const PostAuthDestination(this.route, {this.reason});

  final String route;
  final String? reason;

  static const networkTimeout = Duration(seconds: 15);

  /// Resolves where an authenticated user must go next.
  static Future<String> resolve({
    SupabaseClient? client,
    VerificationRepository? verificationRepo,
  }) async {
    final supabase = client ?? Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) return '/welcome';

    try {
      final profile = await _fetchMyProfile(supabase)
          .timeout(networkTimeout);

      if (profile == null || !_hasUsername(profile)) {
        return '/auth/complete-profile';
      }

      final role = (profile['role'] as String?)?.toLowerCase() ?? '';
      if (role == 'trainer' || role == 'nutritionist') {
        final status = await (verificationRepo ?? VerificationRepository())
            .getProviderVerificationStatus()
            .timeout(networkTimeout);
        if (status != ProviderVerificationStatus.verified) {
          return '/verification';
        }
      }

      return '/home';
    } on TimeoutException {
      // Fail closed to complete-profile only when we cannot prove completeness;
      // prefer verification-safe home shell error over wrong Home for providers.
      return '/auth/continue';
    } catch (_) {
      return '/auth/continue';
    }
  }

  static bool _hasUsername(Map<String, dynamic> profile) {
    final u = profile['username']?.toString().trim() ?? '';
    return u.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> _fetchMyProfile(
    SupabaseClient supabase,
  ) async {
    try {
      final raw = await supabase.rpc('get_my_profile');
      if (raw is List && raw.isNotEmpty) {
        return Map<String, dynamic>.from(raw.first as Map);
      }
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  /// Whether profile is incomplete (authenticated social stub).
  static Future<bool> isProfileIncomplete({SupabaseClient? client}) async {
    final supabase = client ?? Supabase.instance.client;
    if (supabase.auth.currentSession == null) return false;
    final profile = await _fetchMyProfile(supabase);
    return profile == null || !_hasUsername(profile);
  }
}
