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

  Future<void> ensureProfileExists() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final role = user.userMetadata?['role']?.toString().toLowerCase();
      if (role == null) return;

      final list = (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
      final existing = list.isNotEmpty ? list.first : null;

      if (existing == null) {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'role': role,
          'full_name': user.userMetadata?['full_name'] ?? '',
        });
      }
    } catch (e) {
      // Silently fail - profile might already exist or will be created by trigger
    }
  }
}
