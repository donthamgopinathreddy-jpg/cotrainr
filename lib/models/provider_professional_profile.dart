import 'provider_specialty_taxonomy.dart';

class ProviderProfessionalProfile {
  final String userId;
  final String providerType;
  final String? professionalHeadline;
  final String? bio;
  final int? experienceYears;
  final List<String> specializationIds;
  final List<String> sessionModes;
  final List<String> languages;
  final double? hourlyRate;
  final bool acceptingNewClients;
  final bool verified;
  final bool discoverable;
  final double rating;
  final int totalReviews;
  final String? fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? primaryLocationLabel;
  final double? coverageKm;

  const ProviderProfessionalProfile({
    required this.userId,
    required this.providerType,
    this.professionalHeadline,
    this.bio,
    this.experienceYears,
    this.specializationIds = const [],
    this.sessionModes = const [],
    this.languages = const [],
    this.hourlyRate,
    this.acceptingNewClients = true,
    this.verified = false,
    this.discoverable = true,
    this.rating = 0,
    this.totalReviews = 0,
    this.fullName,
    this.avatarUrl,
    this.coverUrl,
    this.primaryLocationLabel,
    this.coverageKm,
  });

  List<String> get specialtyLabels =>
      ProviderSpecialtyTaxonomy.labelsFor(specializationIds);

  String get roleLabel =>
      providerType == 'nutritionist' ? 'Nutritionist' : 'Trainer';

  bool get hasExperience =>
      experienceYears != null && experienceYears! > 0;

  String? get experienceLabel {
    if (!hasExperience) return null;
    final y = experienceYears!;
    return y == 1 ? '1 year experience' : '$y years experience';
  }

  double get completionRatio {
    var score = 0;
    const total = 6;
    if ((professionalHeadline ?? '').trim().isNotEmpty) score++;
    if ((bio ?? '').trim().isNotEmpty) score++;
    if (specializationIds.isNotEmpty) score++;
    if (hasExperience) score++;
    if (sessionModes.isNotEmpty) score++;
    if (sessionModes.contains(ProviderSessionModes.online) ||
        (primaryLocationLabel != null && primaryLocationLabel!.isNotEmpty)) {
      score++;
    }
    return score / total;
  }

  ProviderProfessionalProfile copyWith({
    String? professionalHeadline,
    String? bio,
    int? experienceYears,
    List<String>? specializationIds,
    List<String>? sessionModes,
    List<String>? languages,
    double? hourlyRate,
    bool? acceptingNewClients,
    String? primaryLocationLabel,
    double? coverageKm,
  }) {
    return ProviderProfessionalProfile(
      userId: userId,
      providerType: providerType,
      professionalHeadline: professionalHeadline ?? this.professionalHeadline,
      bio: bio ?? this.bio,
      experienceYears: experienceYears ?? this.experienceYears,
      specializationIds: specializationIds ?? this.specializationIds,
      sessionModes: sessionModes ?? this.sessionModes,
      languages: languages ?? this.languages,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      acceptingNewClients: acceptingNewClients ?? this.acceptingNewClients,
      verified: verified,
      discoverable: discoverable,
      rating: rating,
      totalReviews: totalReviews,
      fullName: fullName,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      primaryLocationLabel: primaryLocationLabel ?? this.primaryLocationLabel,
      coverageKm: coverageKm ?? this.coverageKm,
    );
  }
}

class ProviderCertification {
  final String id;
  final String providerId;
  final String name;
  final String? issuingOrganization;
  final int? issueYear;
  final int? expiryYear;
  final String? credentialId;
  final String verificationStatus;
  final bool isPublic;

  const ProviderCertification({
    required this.id,
    required this.providerId,
    required this.name,
    this.issuingOrganization,
    this.issueYear,
    this.expiryYear,
    this.credentialId,
    this.verificationStatus = 'unverified',
    this.isPublic = true,
  });

  factory ProviderCertification.fromJson(Map<String, dynamic> json) {
    return ProviderCertification(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      name: json['name'] as String? ?? '',
      issuingOrganization: json['issuing_organization'] as String?,
      issueYear: (json['issue_year'] as num?)?.toInt(),
      expiryYear: (json['expiry_year'] as num?)?.toInt(),
      credentialId: json['credential_id'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'unverified',
      isPublic: json['is_public'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'provider_id': providerId,
        'name': name.trim(),
        'issuing_organization': issuingOrganization?.trim(),
        'issue_year': issueYear,
        'expiry_year': expiryYear,
        'credential_id': credentialId?.trim(),
        'verification_status': 'unverified',
        'is_public': isPublic,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name.trim(),
        'issuing_organization': issuingOrganization?.trim(),
        'issue_year': issueYear,
        'expiry_year': expiryYear,
        'credential_id': credentialId?.trim(),
        'is_public': isPublic,
      };
}
