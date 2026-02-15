import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for referral-related operations.
/// All reward creation happens via RPC - no client inserts.
/// apply_referral_code creates referral row; grant_referral_rewards grants rewards when milestone met.
class ReferralRepository {
  ReferralRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Ensures current user has a referral code; creates if missing.
  /// Returns the code string.
  Future<String> generateReferralCode() async {
    final res = await _client.rpc('generate_referral_code');
    return res as String;
  }

  /// Applies a referral code for the current user (the referred).
  /// Creates referral row with rewarded=false. Rewards granted when user reaches 500 XP.
  /// Returns {status: success|invalid_code|already_used|self_referral, message, referrer_id?, referral_id?}.
  Future<Map<String, dynamic>> applyReferralCode(String code) async {
    final res = await _client.rpc('apply_referral_code', params: {'p_code': code});
    return Map<String, dynamic>.from(res as Map);
  }

  /// Fetches the current user's referral code (creates if missing).
  Future<String> getOrCreateReferralCode() async {
    return generateReferralCode();
  }

  /// Count of referrals where current user is the referrer.
  Future<int> getReferralsCount() async {
    final res = await _client
        .from('referrals')
        .select('id')
        .eq('referrer_id', _client.auth.currentUser!.id);
    return (res as List).length;
  }

  /// Total XP earned from referral rewards (where reward_type = 'xp').
  Future<int> getReferralRewardsXp() async {
    final res = await _client
        .from('referral_rewards')
        .select('reward_value')
        .eq('user_id', _client.auth.currentUser!.id)
        .eq('reward_type', 'xp');
    int total = 0;
    for (final row in res as List) {
      total += ((row as Map)['reward_value'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  /// Option B: Call when referred user reaches milestone (500 XP).
  /// Normally handled by Postgres trigger; use this if XP comes from non-triggered source.
  Future<Map<String, dynamic>> grantReferralRewards() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return {'ok': false, 'status': 'error', 'message': 'Not authenticated'};
    }
    final res = await _client.rpc('grant_referral_rewards', params: {'p_referred_id': userId});
    return Map<String, dynamic>.from(res as Map);
  }
}
