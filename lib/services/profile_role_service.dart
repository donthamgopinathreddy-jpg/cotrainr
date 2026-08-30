import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRoleService {
  final SupabaseClient _supabase;

  ProfileRoleService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<String?> getCurrentUserRole() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final list = (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first['role'] as String? : null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final list = (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Reports whether a profile row exists for the signed-in user.
  ///
  /// Deliberately does NOT create one from client-writable auth metadata:
  /// `profiles.role` is authoritative and is owned by the server (the
  /// `handle_new_user` trigger for signups and `complete_cotrainr_profile` for
  /// social onboarding). A client-side insert would let user metadata become an
  /// uncontrolled role authority.
  Future<bool> profileExists() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final list = (await _supabase.rpc('get_my_profile') as List)
          .cast<Map<String, dynamic>>();
      return list.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfileRoleService: profileExists check failed: $e');
      }
      return false;
    }
  }
}
