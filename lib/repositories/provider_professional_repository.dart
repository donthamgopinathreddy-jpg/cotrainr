import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/provider_professional_profile.dart';
import '../models/provider_specialty_taxonomy.dart';

class ProviderProfessionalRepository {
  ProviderProfessionalRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<ProviderProfessionalProfile?> fetchByUserId(String userId) async {
    try {
      final prov = await _supabase
          .from('providers')
          .select('''
            user_id,
            provider_type,
            professional_headline,
            specialization,
            experience_years,
            hourly_rate,
            session_modes,
            languages,
            accepting_new_clients,
            verified,
            discoverable,
            rating,
            total_reviews
          ''')
          .eq('user_id', userId)
          .maybeSingle();
      if (prov == null) return null;

      String? bio;
      String? fullName;
      String? avatarUrl;
      try {
        final list = (await _supabase.rpc(
          'get_public_profile',
          params: {'p_user_id': userId},
        ) as List)
            .cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          bio = list.first['bio'] as String?;
          fullName = list.first['full_name'] as String?;
          avatarUrl = list.first['avatar_url'] as String?;
        }
      } catch (_) {
        final profile = await _supabase
            .from('profiles')
            .select('bio, full_name, avatar_url')
            .eq('id', userId)
            .maybeSingle();
        bio = profile?['bio'] as String?;
        fullName = profile?['full_name'] as String?;
        avatarUrl = profile?['avatar_url'] as String?;
      }

      String? locationLabel;
      double? coverageKm;
      try {
        final loc = await _supabase
            .from('provider_locations')
            .select('display_name, radius_km, is_primary, is_active')
            .eq('provider_id', userId)
            .eq('is_active', true)
            .order('is_primary', ascending: false)
            .limit(1)
            .maybeSingle();
        locationLabel = (loc?['display_name'] as String?)?.trim();
        coverageKm = (loc?['radius_km'] as num?)?.toDouble();
      } catch (_) {}

      final specs = (prov['specialization'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final modes = (prov['session_modes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final langs = (prov['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      final exp = (prov['experience_years'] as num?)?.toInt();
      return ProviderProfessionalProfile(
        userId: userId,
        providerType: prov['provider_type']?.toString() ?? 'trainer',
        professionalHeadline: prov['professional_headline'] as String?,
        bio: bio,
        // Keep 0 as a real value for forms; public UI uses [hasExperience].
        experienceYears: exp,
        specializationIds: ProviderSpecialtyTaxonomy.normalizeList(specs),
        sessionModes: modes,
        languages: langs,
        hourlyRate: (prov['hourly_rate'] as num?)?.toDouble(),
        acceptingNewClients: prov['accepting_new_clients'] as bool? ?? true,
        verified: prov['verified'] as bool? ?? false,
        discoverable: prov['discoverable'] as bool? ?? true,
        rating: (prov['rating'] as num?)?.toDouble() ?? 0,
        totalReviews: (prov['total_reviews'] as num?)?.toInt() ?? 0,
        fullName: fullName,
        avatarUrl: avatarUrl,
        primaryLocationLabel:
            (locationLabel != null && locationLabel.isNotEmpty)
                ? locationLabel
                : null,
        coverageKm: coverageKm,
      );
    } catch (e, st) {
      debugPrint('ProviderProfessionalRepository.fetchByUserId: $e\n$st');
      rethrow;
    }
  }

  Future<ProviderProfessionalProfile?> fetchMine() async {
    final uid = _uid;
    if (uid == null) return null;
    return fetchByUserId(uid);
  }

  Future<void> saveProfessional({
    required String providerType,
    String? professionalHeadline,
    String? bio,
    int? experienceYears,
    required List<String> specializationIds,
    required List<String> sessionModes,
    required List<String> languages,
    double? hourlyRate,
    required bool acceptingNewClients,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final exp = experienceYears?.clamp(0, 60);
    final specs =
        ProviderSpecialtyTaxonomy.normalizeList(specializationIds);

    await _supabase.from('providers').upsert({
      'user_id': uid,
      'provider_type': providerType,
      'professional_headline': professionalHeadline?.trim(),
      'experience_years': exp ?? 0,
      'specialization': specs,
      'session_modes': sessionModes,
      'languages': languages.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'hourly_rate': hourlyRate,
      'accepting_new_clients': acceptingNewClients,
    });

    // Canonical bio lives on profiles; table SELECT/UPDATE is revoked for
    // authenticated — must use SECURITY DEFINER RPC (same as ProfileRepository).
    await _supabase.rpc(
      'update_my_profile',
      params: {
        'p_updates': {'bio': bio?.trim()},
      },
    );
  }

  Future<List<ProviderCertification>> listCertifications(
    String providerId, {
    bool publicOnly = false,
  }) async {
    var query = _supabase
        .from('provider_certifications')
        .select(
          'id, provider_id, name, issuing_organization, issue_year, expiry_year, verification_status, is_public',
        )
        .eq('provider_id', providerId);
    // credential_id intentionally omitted from client public reads.
    if (publicOnly) {
      query = query.eq('is_public', true);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ProviderCertification.fromJson)
        .toList();
  }

  Future<ProviderCertification> addCertification({
    required String name,
    String? issuingOrganization,
    int? issueYear,
    int? expiryYear,
    String? credentialId,
    bool isPublic = true,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final row = await _supabase
        .from('provider_certifications')
        .insert(
          ProviderCertification(
            id: '',
            providerId: uid,
            name: name,
            issuingOrganization: issuingOrganization,
            issueYear: issueYear,
            expiryYear: expiryYear,
            credentialId: credentialId,
            isPublic: isPublic,
          ).toInsertJson(),
        )
        .select(
          'id, provider_id, name, issuing_organization, issue_year, expiry_year, verification_status, is_public',
        )
        .single();
    return ProviderCertification.fromJson(row);
  }

  Future<void> updateCertification(ProviderCertification cert) async {
    await _supabase
        .from('provider_certifications')
        .update(cert.toUpdateJson())
        .eq('id', cert.id)
        .eq('provider_id', cert.providerId);
  }

  Future<void> deleteCertification(String id) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _supabase
        .from('provider_certifications')
        .delete()
        .eq('id', id)
        .eq('provider_id', uid);
  }
}
