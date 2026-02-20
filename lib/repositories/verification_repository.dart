import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';

/// Repository for verification submissions
class VerificationRepository {
  final SupabaseClient _supabase;
  final StorageService _storage;

  VerificationRepository({
    SupabaseClient? supabase,
    StorageService? storage,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get user role from profile or providers (nutritionist | trainer)
  Future<String> getProviderRole() async {
    if (_currentUserId == null) throw Exception('User not authenticated');
    try {
      final profile = await _supabase.rpc('get_my_profile');
      final list = (profile as List).cast<Map<String, dynamic>>();
      if (list.isNotEmpty) {
        final role = list.first['role']?.toString().toLowerCase();
        if (role == 'nutritionist') return 'nutritionist';
        if (role == 'trainer') return 'trainer';
      }
    } catch (_) {}
    try {
      final prov = await _supabase
          .from('providers')
          .select('provider_type')
          .eq('user_id', _currentUserId!)
          .maybeSingle();
      final pt = prov?['provider_type']?.toString().toLowerCase();
      if (pt == 'nutritionist') return 'nutritionist';
      if (pt == 'trainer') return 'trainer';
    } catch (_) {}
    return 'trainer';
  }

  /// Fetch current user's latest verification submission
  Future<Map<String, dynamic>?> getMyLatestSubmission() async {
    if (_currentUserId == null) return null;
    try {
      final res = await _supabase
          .from('verification_submissions')
          .select()
          .eq('user_id', _currentUserId!)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Check if user has a pending submission (blocks new submit)
  Future<bool> hasPendingSubmission() async {
    final latest = await getMyLatestSubmission();
    return latest?['status'] == 'pending';
  }

  /// Upload files and insert verification submission
  Future<void> submitVerification({
    required String providerType,
    required String govIdType,
    required File certificateFile,
    required File govIdFile,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final pending = await hasPendingSubmission();
    if (pending) throw Exception('You already have a pending submission. Please wait for review.');

    final certPath = await _storage.uploadVerificationCredential(certificateFile);
    final govIdPath = await _storage.uploadVerificationGovId(govIdFile);

    try {
      await _supabase.from('verification_submissions').insert({
        'user_id': _currentUserId,
        'provider_type': providerType,
        'status': 'pending',
        'certificate_path': certPath,
        'gov_id_path': govIdPath,
        'gov_id_type': govIdType.trim(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('You already have a pending submission. Please wait for review.');
      }
      rethrow;
    }
  }
}
