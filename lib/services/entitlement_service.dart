import 'package:flutter/foundation.dart';
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
        if (kDebugMode) {
          debugPrint('getEntitlements non-200: status=${response.status}');
        }
        throw Exception('Failed to get entitlements');
      }

      final raw = response.data;
      if (raw is! Map) {
        if (kDebugMode) {
          debugPrint('getEntitlements unexpected payload type: ${raw.runtimeType}');
        }
        throw Exception('Failed to get entitlements');
      }

      return Entitlements.fromJson(Map<String, dynamic>.from(raw));
    } on Exception {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getEntitlements failed: $e');
      }
      throw Exception('Failed to get entitlements');
    }
  }
}

class Entitlements {
  final String plan;
  final String planDisplayName;
  final String subscriptionStatus;
  final String periodKey;
  final String periodKind;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int? limit;
  final bool unlimited;
  final int used;
  final int? remaining;
  final bool nutritionistAllowed;

  Entitlements({
    required this.plan,
    required this.planDisplayName,
    required this.subscriptionStatus,
    required this.periodKey,
    required this.periodKind,
    required this.periodStart,
    required this.periodEnd,
    required this.limit,
    required this.unlimited,
    required this.used,
    required this.remaining,
    required this.nutritionistAllowed,
  });

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw Exception('Failed to get entitlements');
    }

    return Entitlements(
      plan: json['plan'] as String? ?? '',
      planDisplayName: json['plan_display_name'] as String? ?? '',
      subscriptionStatus: json['subscription_status'] as String? ?? '',
      periodKey: json['period_key'] as String? ?? '',
      periodKind: json['period_kind'] as String? ?? '',
      periodStart: _parseDateTime(json['period_start']),
      periodEnd: _parseDateTime(json['period_end']),
      limit: (json['limit'] as num?)?.toInt(),
      unlimited: json['unlimited'] == true,
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt(),
      nutritionistAllowed: json['nutritionist_allowed'] == true,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
