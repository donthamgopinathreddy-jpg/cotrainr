import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `public.subscriptions` for the current user (one row per user_id).
/// There is no per-provider subscription column in the current schema.
class SubscriptionsRepository {
  final SupabaseClient _supabase;

  SubscriptionsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  /// Paid plan: not `free`. (Plan may arrive as enum string from PostgREST.)
  Future<SubscriptionRow?> fetchMine() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _supabase
          .from('subscriptions')
          .select('plan, status, expires_at')
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return SubscriptionRow.fromMap(row);
    } catch (e) {
      print('SubscriptionsRepository.fetchMine: $e');
      return null;
    }
  }

  /// Messaging: client must have a non-free plan and active (or trialing) status,
  /// and must not be past [expires_at] when that column is set.
  Future<bool> hasActiveMessagingSubscription() async {
    final row = await fetchMine();
    if (row == null) return false;
    return row.isMessagingActive;
  }
}

class SubscriptionRow {
  final String plan;
  final String status;
  final DateTime? expiresAt;

  SubscriptionRow({
    required this.plan,
    required this.status,
    this.expiresAt,
  });

  factory SubscriptionRow.fromMap(Map<String, dynamic> json) {
    final planRaw = json['plan'];
    final plan = planRaw == null ? 'free' : planRaw.toString().toLowerCase();
    final statusRaw = json['status'];
    final status = statusRaw == null ? 'inactive' : statusRaw.toString().toLowerCase();
    DateTime? exp;
    final expVal = json['expires_at'];
    if (expVal is String) {
      exp = DateTime.tryParse(expVal);
    }
    return SubscriptionRow(plan: plan, status: status, expiresAt: exp);
  }

  bool get _notExpired {
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }

  bool get isMessagingActive {
    if (!_notExpired) return false;
    if (plan == 'free') return false;
    const ok = {'active', 'trialing'};
    return ok.contains(status);
  }

  /// Expired or cancelled etc. — history may still be shown but sending should stop for clients.
  bool get isExpiredOrInactiveForClient {
    if (!_notExpired) return true;
    if (plan == 'free') return true;
    const bad = {'expired', 'cancelled', 'canceled', 'inactive', 'past_due'};
    return bad.contains(status);
  }
}
