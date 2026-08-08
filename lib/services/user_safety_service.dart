import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_safety_models.dart';

class UserSafetyService {
  final SupabaseClient _supabase;

  UserSafetyService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<BlockState> getBlockState(String otherUserId) async {
    try {
      final raw = await _supabase.rpc(
        'get_block_state',
        params: {'p_other_user_id': otherUserId},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['error'] != null) return BlockState.none;
      return BlockState.fromJson(data);
    } catch (e) {
      debugPrint('UserSafetyService.getBlockState: $e');
      return BlockState.none;
    }
  }

  Future<void> blockUser(String otherUserId) async {
    final raw = await _supabase.rpc(
      'block_user_tx',
      params: {'p_blocked_user_id': otherUserId},
    );
    final data = Map<String, dynamic>.from(raw as Map);
    final err = data['error'] as String?;
    if (err != null) throw Exception(err);
  }

  Future<void> unblockUser(String otherUserId) async {
    final raw = await _supabase.rpc(
      'unblock_user_tx',
      params: {'p_blocked_user_id': otherUserId},
    );
    final data = Map<String, dynamic>.from(raw as Map);
    final err = data['error'] as String?;
    if (err != null) throw Exception(err);
  }

  Future<String> submitReport({
    required String reportedUserId,
    required String reasonId,
    String? details,
    String? conversationId,
  }) async {
    final raw = await _supabase.rpc(
      'submit_user_report',
      params: {
        'p_reported_user_id': reportedUserId,
        'p_reason': reasonId,
        'p_details': details,
        'p_conversation_id': conversationId,
      },
    );
    final data = Map<String, dynamic>.from(raw as Map);
    final err = data['error'] as String?;
    if (err != null) throw Exception(err);
    return data['report_id'] as String? ?? '';
  }
}
