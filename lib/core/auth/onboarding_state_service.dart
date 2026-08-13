import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding_completeness.dart';

/// Single client entry for server-authoritative onboarding completeness.
abstract final class OnboardingStateService {
  static const networkTimeout = Duration(seconds: 15);

  static Future<OnboardingState> fetch({SupabaseClient? client}) async {
    final supabase = client ?? Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      return const OnboardingState(
        isComplete: false,
        missing: ['unauthenticated'],
      );
    }
    final raw = await supabase
        .rpc('get_onboarding_state')
        .timeout(networkTimeout);
    return parse(raw);
  }

  static OnboardingState parse(dynamic raw) {
    Map<String, dynamic>? row;
    if (raw is List && raw.isNotEmpty) {
      row = Map<String, dynamic>.from(raw.first as Map);
    } else if (raw is Map) {
      row = Map<String, dynamic>.from(raw);
    }
    if (row == null) {
      return const OnboardingState(isComplete: false, missing: ['unknown']);
    }
    final missingRaw = row['missing'];
    final missing = <String>[];
    if (missingRaw is List) {
      for (final item in missingRaw) {
        final code = item?.toString().trim() ?? '';
        if (code.isNotEmpty) missing.add(code);
      }
    }
    final complete = row['is_complete'] == true && missing.isEmpty;
    return OnboardingState(isComplete: complete, missing: missing);
  }
}
