import 'package:supabase_flutter/supabase_flutter.dart';

class EntitlementService {
  final SupabaseClient _supabase;

  EntitlementService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<Entitlements> getEntitlements() async {
    try {
      final response = await _supabase.functions.invoke(
        'get-entitlements',
        body: {},
      );

      if (response.status != 200) {
        throw Exception('Failed to get entitlements: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      return Entitlements.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get entitlements: $e');
    }
  }
}

class Entitlements {
  final String plan;
  final String status;
  /// Calendar month start (yyyy-MM-dd). Legacy field name `weekStart` may mirror this.
  final String monthStart;
  final EntitlementLimits limits;
  final EntitlementUsed used;
  final EntitlementRemaining remaining;

  Entitlements({
    required this.plan,
    required this.status,
    required this.monthStart,
    required this.limits,
    required this.used,
    required this.remaining,
  });

  /// Backward-compatible alias.
  String get weekStart => monthStart;

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final month = (json['month_start'] ?? json['week_start']) as String? ?? '';
    return Entitlements(
      plan: json['plan'] as String,
      status: json['status'] as String,
      monthStart: month,
      limits: EntitlementLimits.fromJson(
        Map<String, dynamic>.from(json['limits'] as Map),
      ),
      used: EntitlementUsed.fromJson(
        Map<String, dynamic>.from(json['used'] as Map),
      ),
      remaining: EntitlementRemaining.fromJson(
        Map<String, dynamic>.from(json['remaining'] as Map),
      ),
    );
  }
}

class EntitlementLimits {
  /// Null when [requestsUnlimited] is true (Ultimate).
  final int? requests;
  final bool requestsUnlimited;
  final bool nutritionistAllowed;

  EntitlementLimits({
    required this.requests,
    required this.requestsUnlimited,
    required this.nutritionistAllowed,
  });

  factory EntitlementLimits.fromJson(Map<String, dynamic> json) {
    final unlimited = json['requests_unlimited'] == true;
    final raw = json['requests'];
    return EntitlementLimits(
      requests: unlimited ? null : (raw as num?)?.toInt(),
      requestsUnlimited: unlimited,
      nutritionistAllowed: json['nutritionist_allowed'] as bool? ?? false,
    );
  }
}

class EntitlementUsed {
  final int requests;

  EntitlementUsed({required this.requests});

  factory EntitlementUsed.fromJson(Map<String, dynamic> json) {
    return EntitlementUsed(
      requests: (json['requests'] as num?)?.toInt() ?? 0,
    );
  }
}

class EntitlementRemaining {
  /// Null when unlimited.
  final int? requests;
  final bool requestsUnlimited;

  EntitlementRemaining({
    required this.requests,
    required this.requestsUnlimited,
  });

  factory EntitlementRemaining.fromJson(Map<String, dynamic> json) {
    final unlimited = json['requests_unlimited'] == true;
    final raw = json['requests'];
    return EntitlementRemaining(
      requests: unlimited ? null : (raw as num?)?.toInt(),
      requestsUnlimited: unlimited,
    );
  }
}
