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
  final String weekStart;
  final EntitlementLimits limits;
  final EntitlementUsed used;
  final EntitlementRemaining remaining;

  Entitlements({
    required this.plan,
    required this.status,
    required this.weekStart,
    required this.limits,
    required this.used,
    required this.remaining,
  });

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    return Entitlements(
      plan: json['plan'] as String,
      status: json['status'] as String,
      weekStart: json['week_start'] as String,
      limits: EntitlementLimits.fromJson(json['limits'] as Map<String, dynamic>),
      used: EntitlementUsed.fromJson(json['used'] as Map<String, dynamic>),
      remaining: EntitlementRemaining.fromJson(json['remaining'] as Map<String, dynamic>),
    );
  }
}

class EntitlementLimits {
  final int requests;
  final int nutritionistRequests;
  final bool nutritionistAllowed;

  EntitlementLimits({
    required this.requests,
    required this.nutritionistRequests,
    required this.nutritionistAllowed,
  });

  factory EntitlementLimits.fromJson(Map<String, dynamic> json) {
    return EntitlementLimits(
      requests: json['requests'] as int,
      nutritionistRequests: json['nutritionist_requests'] as int,
      nutritionistAllowed: json['nutritionist_allowed'] as bool,
    );
  }
}

class EntitlementUsed {
  final int requests;
  final int nutritionistRequests;

  EntitlementUsed({
    required this.requests,
    required this.nutritionistRequests,
  });

  factory EntitlementUsed.fromJson(Map<String, dynamic> json) {
    return EntitlementUsed(
      requests: json['requests'] as int,
      nutritionistRequests: json['nutritionist_requests'] as int,
    );
  }
}

class EntitlementRemaining {
  final int requests;
  final int nutritionistRequests;

  EntitlementRemaining({
    required this.requests,
    required this.nutritionistRequests,
  });

  factory EntitlementRemaining.fromJson(Map<String, dynamic> json) {
    return EntitlementRemaining(
      requests: json['requests'] as int,
      nutritionistRequests: json['nutritionist_requests'] as int,
    );
  }
}
