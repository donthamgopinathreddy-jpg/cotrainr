import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/verification_repository.dart';
import 'account_status.dart';
import 'onboarding_state_service.dart';
import 'user_role.dart';

/// Authoritative post-auth destination for Login / OAuth / cold start / signup.
class PostAuthDestination {
  const PostAuthDestination(this.route, {this.reason});

  final String route;
  final String? reason;

  static const networkTimeout = Duration(seconds: 15);

  /// Route for suspended / banned accounts.
  static const accountRestrictedRoute = '/account-restricted';

  /// Resolves where an authenticated user must go next.
  static Future<String> resolve({
    SupabaseClient? client,
    VerificationRepository? verificationRepo,
  }) async {
    final supabase = client ?? Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) return '/welcome';

    try {
      final onboarding = await OnboardingStateService.fetch(client: supabase)
          .timeout(networkTimeout);

      if (!onboarding.isComplete) {
        return '/auth/complete-profile';
      }

      final profile = await _fetchMyProfile(supabase).timeout(networkTimeout);
      // Unreadable profile must not fall through to /home: the moderation and
      // provider gates below depend on it.
      if (profile == null) return '/auth/continue';

      // Moderation gate before any protected destination.
      if (AccountStatusParser.fromProfile(profile).isRestricted) {
        return accountRestrictedRoute;
      }

      // Fail-closed role parsing: unknown roles are not treated as providers,
      // and are never mapped to client/trainer.
      if (UserRoleParser.isProviderRole(profile['role'])) {
        final status = await (verificationRepo ?? VerificationRepository())
            .getProviderVerificationStatus()
            .timeout(networkTimeout);
        if (status != ProviderVerificationStatus.verified) {
          return '/verification';
        }
      }

      return '/home';
    } on TimeoutException {
      return '/auth/continue';
    } catch (_) {
      return '/auth/continue';
    }
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

  static Future<bool> isProfileIncomplete({SupabaseClient? client}) async {
    final supabase = client ?? Supabase.instance.client;
    if (supabase.auth.currentSession == null) return false;
    final state = await OnboardingStateService.fetch(client: supabase);
    return !state.isComplete;
  }
}
