import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cotrainr_pass_id.dart';

class CotrainrPassException implements Exception {
  final String message;
  CotrainrPassException(this.message);
  @override
  String toString() => message;
}

class CotrainrPassInfo {
  final String passId;
  final DateTime? passCreatedAt;
  final DateTime? memberSince;
  final String? fullName;
  final String? avatarUrl;
  final String planLabel;

  const CotrainrPassInfo({
    required this.passId,
    this.passCreatedAt,
    this.memberSince,
    this.fullName,
    this.avatarUrl,
    this.planLabel = 'Free',
  });
}

/// Server-side Pass ID assignment via `get_or_create_cotrainr_pass`.
class CotrainrPassRepository {
  final SupabaseClient _supabase;

  CotrainrPassRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Idempotent: returns existing Pass ID or generates one server-side.
  Future<String> getOrCreatePassId() async {
    try {
      final res = await _supabase.rpc('get_or_create_cotrainr_pass');
      final id = normalizeCotrainrPassId(res?.toString());
      if (id == null) {
        throw CotrainrPassException('Invalid Cotrainr Pass ID from server');
      }
      return id;
    } catch (e) {
      if (e is CotrainrPassException) rethrow;
      throw CotrainrPassException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<CotrainrPassInfo> loadPassInfo({required String planLabel}) async {
    final passId = await getOrCreatePassId();
    DateTime? memberSince;
    DateTime? passCreatedAt;
    String? fullName;
    String? avatarUrl;

    try {
      final rows = await _supabase.rpc('get_my_profile');
      if (rows is List && rows.isNotEmpty) {
        final p = Map<String, dynamic>.from(rows.first as Map);
        fullName = p['full_name'] as String?;
        avatarUrl = p['avatar_url'] as String?;
        passCreatedAt = _parseTs(p['cotrainr_pass_created_at']);
        memberSince = _parseTs(p['created_at']) ?? passCreatedAt;
      }
    } catch (_) {
      // Profile extras are optional for displaying the Pass ID.
    }

    return CotrainrPassInfo(
      passId: passId,
      passCreatedAt: passCreatedAt,
      memberSince: memberSince,
      fullName: fullName,
      avatarUrl: avatarUrl,
      planLabel: planLabel,
    );
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
