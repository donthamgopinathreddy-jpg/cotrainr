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
      // Prefer SECURITY DEFINER RPC — works even when direct providers SELECT
      // is blocked or professional columns are partially applied.
      try {
        final rpc = await _supabase.rpc(
          'get_public_provider_profile',
          params: {'p_user_id': userId},
        );
        if (rpc is Map<String, dynamic>) {
          return _fromPublicRpc(rpc, userId);
        }
        if (rpc is Map) {
          return _fromPublicRpc(Map<String, dynamic>.from(rpc), userId);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'ProviderProfessionalRepository: get_public_provider_profile fallback — $e',
          );
        }
      }

      return await _fetchByUserIdDirect(userId);
    } catch (e, st) {
      debugPrint('ProviderProfessionalRepository.fetchByUserId: $e\n$st');
      // Last resort: public profile + minimal provider fields from signup.
      return _fetchMinimalFallback(userId);
    }
  }

  ProviderProfessionalProfile _fromPublicRpc(
    Map<String, dynamic> row,
    String userId,
  ) {
    final specs = _asStringList(row['specialization']);
    final modes = _asStringList(row['session_modes']);
    final langs = _asStringList(row['languages']);
    final exp = (row['experience_years'] as num?)?.toInt();
    return ProviderProfessionalProfile(
      userId: (row['user_id'] as String?) ?? userId,
      providerType: row['provider_type']?.toString() ?? 'trainer',
      professionalHeadline: row['professional_headline'] as String?,
      bio: row['bio'] as String?,
      experienceYears: exp,
      specializationIds: ProviderSpecialtyTaxonomy.normalizeList(specs),
      sessionModes: modes,
      languages: langs,
      hourlyRate: (row['hourly_rate'] as num?)?.toDouble(),
      acceptingNewClients: row['accepting_new_clients'] as bool? ?? true,
      verified: row['verified'] as bool? ?? false,
      discoverable: row['discoverable'] as bool? ?? true,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (row['total_reviews'] as num?)?.toInt() ?? 0,
      fullName: row['full_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      primaryLocationLabel: row['primary_location_label'] as String?,
      coverageKm: (row['coverage_km'] as num?)?.toDouble(),
    );
  }

  Future<ProviderProfessionalProfile?> _fetchByUserIdDirect(
    String userId,
  ) async {
    Map<String, dynamic>? prov;
    try {
      prov = await _supabase
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
    } catch (e) {
      // Older schema without professional columns.
      if (kDebugMode) {
        debugPrint(
          'ProviderProfessionalRepository: full select failed, minimal — $e',
        );
      }
      prov = await _supabase
          .from('providers')
          .select('''
            user_id,
            provider_type,
            specialization,
            experience_years,
            hourly_rate,
            verified,
            discoverable,
            rating,
            total_reviews
          ''')
          .eq('user_id', userId)
          .maybeSingle();
    }
    if (prov == null) return _fetchMinimalFallback(userId);

    final identity = await _loadPublicIdentity(userId);
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

    final specs = _asStringList(prov['specialization']);
    final modes = _asStringList(prov['session_modes']);
    final langs = _asStringList(prov['languages']);
    final exp = (prov['experience_years'] as num?)?.toInt();

    return ProviderProfessionalProfile(
      userId: userId,
      providerType: prov['provider_type']?.toString() ?? 'trainer',
      professionalHeadline: prov['professional_headline'] as String?,
      bio: identity.bio,
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
      fullName: identity.fullName,
      avatarUrl: identity.avatarUrl,
      coverUrl: identity.coverUrl,
      primaryLocationLabel:
          (locationLabel != null && locationLabel.isNotEmpty)
              ? locationLabel
              : null,
      coverageKm: coverageKm,
    );
  }

  /// Build a profile from public identity + basic providers row (signup data).
  Future<ProviderProfessionalProfile?> _fetchMinimalFallback(
    String userId,
  ) async {
    try {
      final identity = await _loadPublicIdentity(userId);
      Map<String, dynamic>? prov;
      try {
        prov = await _supabase
            .from('providers')
            .select('user_id, provider_type, specialization, experience_years, verified, rating, total_reviews')
            .eq('user_id', userId)
            .maybeSingle();
      } catch (_) {}

      if (prov == null &&
          identity.fullName == null &&
          identity.avatarUrl == null &&
          identity.bio == null) {
        return null;
      }

      final specs = _asStringList(prov?['specialization']);
      return ProviderProfessionalProfile(
        userId: userId,
        providerType: prov?['provider_type']?.toString() ?? 'trainer',
        bio: identity.bio,
        experienceYears: (prov?['experience_years'] as num?)?.toInt(),
        specializationIds: ProviderSpecialtyTaxonomy.normalizeList(specs),
        verified: prov?['verified'] as bool? ?? false,
        rating: (prov?['rating'] as num?)?.toDouble() ?? 0,
        totalReviews: (prov?['total_reviews'] as num?)?.toInt() ?? 0,
        fullName: identity.fullName,
        avatarUrl: identity.avatarUrl,
        coverUrl: identity.coverUrl,
      );
    } catch (e) {
      debugPrint('ProviderProfessionalRepository._fetchMinimalFallback: $e');
      return null;
    }
  }

  Future<
      ({
        String? fullName,
        String? avatarUrl,
        String? coverUrl,
        String? bio,
        String? username,
      })> _loadPublicIdentity(String userId) async {
    try {
      final list = (await _supabase.rpc(
        'get_public_profile',
        params: {'p_user_id': userId},
      ) as List)
          .cast<Map<String, dynamic>>();
      if (list.isNotEmpty) {
        final row = list.first;
        return (
          fullName: row['full_name'] as String?,
          avatarUrl: row['avatar_url'] as String?,
          coverUrl: row['cover_url'] as String?,
          bio: row['bio'] as String?,
          username: row['username'] as String?,
        );
      }
    } catch (_) {}
    return (
      fullName: null,
      avatarUrl: null,
      coverUrl: null,
      bio: null,
      username: null,
    );
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
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
    if (publicOnly) {
      query = query.eq('is_public', true);
    }
    try {
      final rows = await query.order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(ProviderCertification.fromJson)
          .toList();
    } catch (e) {
      debugPrint('ProviderProfessionalRepository.listCertifications: $e');
      return const [];
    }
  }

  Future<void> addCertification({
    required String name,
    String? issuingOrganization,
    int? issueYear,
    int? expiryYear,
    String? credentialId,
    bool isPublic = true,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final cert = ProviderCertification(
      id: '',
      providerId: uid,
      name: name,
      issuingOrganization: issuingOrganization,
      issueYear: issueYear,
      expiryYear: expiryYear,
      credentialId: credentialId,
      isPublic: isPublic,
    );
    await _supabase.from('provider_certifications').insert(cert.toInsertJson());
  }

  Future<void> updateCertification(ProviderCertification cert) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    if (cert.providerId != uid) {
      throw Exception('Cannot update another provider\'s certification');
    }
    await _supabase
        .from('provider_certifications')
        .update(cert.toUpdateJson())
        .eq('id', cert.id)
        .eq('provider_id', uid);
  }

  Future<void> deleteCertification(String certificationId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _supabase
        .from('provider_certifications')
        .delete()
        .eq('id', certificationId)
        .eq('provider_id', uid);
  }
}
