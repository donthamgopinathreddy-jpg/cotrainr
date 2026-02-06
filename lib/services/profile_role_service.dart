import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRoleService {
  final SupabaseClient _supabase;

  ProfileRoleService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<String?> getCurrentUserRole() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

      return response as Map<String, dynamic>?;
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

      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

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
