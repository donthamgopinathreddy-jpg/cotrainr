import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/user_role.dart';
import '../services/storage_service.dart';

/// Server-authoritative provider verification state.
///
/// There is deliberately no `unknown` member: a failed lookup throws so callers
/// must render a retry/error state instead of silently showing "not verified".
enum ProviderVerificationStatus {
  verified,
  pending,
  rejected,
  notSubmitted,
}

/// Thrown when the provider role cannot be resolved from the server.
class VerificationRoleUnresolved implements Exception {
  const VerificationRoleUnresolved(this.reason);

  final String reason;

  @override
  String toString() => 'VerificationRoleUnresolved($reason)';
}

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

  /// Server-authoritative provider role (`nutritionist` | `trainer`).
  ///
  /// Fails closed: throws [VerificationRoleUnresolved] when the role cannot be
  /// resolved. Never defaults to `trainer` — a nutritionist must not be able to
  /// submit or display as a trainer because a lookup failed.
  Future<String> getProviderRole() async {
    if (_currentUserId == null) {
      throw VerificationRoleUnresolved('not_authenticated');
    }

    final profile = await _supabase.rpc('get_my_profile');
    if (profile is List && profile.isNotEmpty) {
      final row = Map<String, dynamic>.from(profile.first as Map);
      final role = UserRoleParser.parse(row['role']);
      if (role != null && role.isProvider) return role.dbValue;
      if (role != null) throw VerificationRoleUnresolved('not_a_provider');
    }

    final prov = await _supabase
        .from('providers')
        .select('provider_type')
        .eq('user_id', _currentUserId!)
        .maybeSingle();
    final providerType = UserRoleParser.parse(prov?['provider_type']);
    if (providerType != null && providerType.isProvider) {
      return providerType.dbValue;
    }

    throw VerificationRoleUnresolved('role_unresolved');
  }

  /// Fetch current user's latest verification submission.
  ///
  /// Throws on infrastructure failure — a network error must not be reported to
  /// the UI as "nothing submitted".
  Future<Map<String, dynamic>?> getMyLatestSubmission() async {
    if (_currentUserId == null) return null;
    return await _supabase
        .from('verification_submissions')
        .select()
        .eq('user_id', _currentUserId!)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Check if user has a pending submission (blocks new submit)
  Future<bool> hasPendingSubmission() async {
    final latest = await getMyLatestSubmission();
    return latest?['status'] == 'pending';
  }

  /// Resolved provider verification for profile UI.
  ///
  /// Throws when the server cannot be reached or read. Callers must show a
  /// retry/error state rather than assuming the provider is unverified.
  Future<ProviderVerificationStatus> getProviderVerificationStatus() async {
    if (_currentUserId == null) return ProviderVerificationStatus.notSubmitted;

    final prov = await _supabase
        .from('providers')
        .select('verified')
        .eq('user_id', _currentUserId!)
        .maybeSingle();
    if (prov?['verified'] == true) {
      return ProviderVerificationStatus.verified;
    }

    final latest = await getMyLatestSubmission();
    switch (latest?['status']?.toString().trim().toLowerCase()) {
      case 'approved':
        return ProviderVerificationStatus.verified;
      case 'pending':
        return ProviderVerificationStatus.pending;
      case 'rejected':
        return ProviderVerificationStatus.rejected;
      default:
        return ProviderVerificationStatus.notSubmitted;
    }
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
