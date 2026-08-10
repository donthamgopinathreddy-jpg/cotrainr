import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerCentersException implements Exception {
  final String message;
  PartnerCentersException(this.message);
  @override
  String toString() => message;
}

class PartnerCenterApplication {
  final String id;
  final String applicationCode;
  final String businessName;
  final String businessType;
  final String city;
  final String status;
  final DateTime createdAt;
  final String? centerId;

  const PartnerCenterApplication({
    required this.id,
    required this.applicationCode,
    required this.businessName,
    required this.businessType,
    required this.city,
    required this.status,
    required this.createdAt,
    this.centerId,
  });

  bool get isOpen =>
      status == 'pending' ||
      status == 'under_review' ||
      status == 'needs_information';

  String get statusLabel => switch (status) {
        'pending' || 'under_review' => 'Pending Review',
        'needs_information' => 'More Information Required',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'withdrawn' => 'Withdrawn',
        _ => status,
      };

  factory PartnerCenterApplication.fromJson(Map<String, dynamic> json) {
    return PartnerCenterApplication(
      id: json['id'] as String,
      applicationCode: json['application_code'] as String,
      businessName: json['business_name'] as String,
      businessType: json['business_type'] as String? ?? '',
      city: json['city'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      centerId: json['center_id'] as String?,
    );
  }
}

class PartnerCenterDiscoverItem {
  final String id;
  final String name;
  final String businessType;
  final String city;
  final String country;
  final String addressLine1;
  final String? googlePlaceId;
  final double? latitude;
  final double? longitude;
  final List<String> facilities;
  final String? description;
  final String? logoUrl;
  final String? offerTitle;
  final String? offerDescription;

  const PartnerCenterDiscoverItem({
    required this.id,
    required this.name,
    required this.businessType,
    required this.city,
    required this.country,
    required this.addressLine1,
    this.googlePlaceId,
    this.latitude,
    this.longitude,
    this.facilities = const [],
    this.description,
    this.logoUrl,
    this.offerTitle,
    this.offerDescription,
  });

  String get locationLabel {
    final parts = [addressLine1, city, country]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  factory PartnerCenterDiscoverItem.fromJson(Map<String, dynamic> json) {
    final facilitiesRaw = json['facilities'];
    final facilities = <String>[];
    if (facilitiesRaw is List) {
      for (final f in facilitiesRaw) {
        if (f != null) facilities.add(f.toString());
      }
    }
    return PartnerCenterDiscoverItem(
      id: json['id'] as String,
      name: json['name'] as String,
      businessType: json['business_type'] as String? ?? 'Centre',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      addressLine1: json['address_line_1'] as String? ?? '',
      googlePlaceId: json['google_place_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      facilities: facilities,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      offerTitle: json['offer_title'] as String?,
      offerDescription: json['offer_description'] as String?,
    );
  }
}

class PartnerApplicationSubmitResult {
  final bool ok;
  final String? applicationCode;
  final String? error;
  final String? detail;

  const PartnerApplicationSubmitResult({
    required this.ok,
    this.applicationCode,
    this.error,
    this.detail,
  });
}

class PartnerCentersRepository {
  final SupabaseClient _supabase;

  PartnerCentersRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<PartnerCenterDiscoverItem>> listForDiscover() async {
    try {
      final res = await _supabase.rpc('list_partner_centers_for_discover');
      final list = (res as List?) ?? const [];
      // Dedupe by google_place_id so Discover never shows two cards for one place.
      final byPlace = <String, PartnerCenterDiscoverItem>{};
      final noPlace = <PartnerCenterDiscoverItem>[];
      for (final row in list) {
        final item = PartnerCenterDiscoverItem.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        final placeId = item.googlePlaceId?.trim();
        if (placeId != null && placeId.isNotEmpty) {
          byPlace.putIfAbsent(placeId, () => item);
        } else {
          noPlace.add(item);
        }
      }
      return [...byPlace.values, ...noPlace]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      throw PartnerCentersException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<PartnerCenterApplication?> latestOpenOrRecentApplication() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _supabase
          .from('partner_center_applications')
          .select(
            'id, application_code, business_name, business_type, city, status, created_at, center_id',
          )
          .eq('submitted_by', uid)
          .order('created_at', ascending: false)
          .limit(1);
      final list = (res as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      return PartnerCenterApplication.fromJson(list.first);
    } catch (_) {
      return null;
    }
  }

  Future<PartnerApplicationSubmitResult> submitApplication(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _supabase.rpc(
        'submit_partner_center_application',
        params: {'p_payload': payload},
      );
      final map = Map<String, dynamic>.from(res as Map);
      final ok = map['ok'] == true;
      return PartnerApplicationSubmitResult(
        ok: ok,
        applicationCode: map['application_code'] as String?,
        error: map['error'] as String?,
        detail: map['detail'] as String?,
      );
    } catch (e) {
      return PartnerApplicationSubmitResult(
        ok: false,
        error: 'submit_failed',
        detail: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
