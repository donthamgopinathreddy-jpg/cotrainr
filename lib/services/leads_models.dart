class Lead {
  final String id;
  final String clientId;
  final String providerId;
  final String providerType;
  final String status;
  final String? message;
  final DateTime createdAt;
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? provider;

  Lead({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.providerType,
    required this.status,
    this.message,
    required this.createdAt,
    this.client,
    this.provider,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      providerId: json['provider_id'] as String,
      providerType: json['provider_type'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      client: json['client'] as Map<String, dynamic>?,
      provider: json['provider'] as Map<String, dynamic>?,
    );
  }
}

class CreateLeadResult {
  final String leadId;
  final String status;
  /// Null when plan has unlimited connection requests (Ultimate / premium).
  final int? remaining;
  /// Null when unlimited.
  final int? limit;
  final bool unlimited;

  CreateLeadResult({
    required this.leadId,
    required this.status,
    required this.remaining,
    required this.limit,
    this.unlimited = false,
  });

  factory CreateLeadResult.fromJson(Map<String, dynamic> json) {
    final unlimited = json['unlimited'] == true;
    return CreateLeadResult(
      leadId: json['lead_id'] as String,
      status: (json['status'] as String?) ?? 'requested',
      remaining: unlimited ? null : (json['remaining'] as num?)?.toInt(),
      limit: unlimited ? null : (json['limit'] as num?)?.toInt(),
      unlimited: unlimited,
    );
  }
}

class UpdateLeadResult {
  final String leadId;
  final String status;
  final String? conversationId;

  UpdateLeadResult({
    required this.leadId,
    required this.status,
    this.conversationId,
  });

  factory UpdateLeadResult.fromJson(Map<String, dynamic> json) {
    return UpdateLeadResult(
      leadId: json['lead_id'] as String,
      status: json['status'] as String,
      conversationId: json['conversation_id'] as String?,
    );
  }
}

/// Result of `end_connection_tx`. Fields are optional because the live JSON
/// contract is not checked into this repo; only parse keys when present.
class EndConnectionResult {
  final bool ok;
  final String? leadId;
  final String? status;
  final DateTime? endedAt;
  final String? endedBy;
  final String? message;
  final String? errorCode;
  final bool? idempotent;
  /// Present only when the RPC includes it; never computed client-side.
  final bool? allowanceRestored;
  /// Alternate restoration flag name if the RPC uses it.
  final bool? restorationGranted;

  const EndConnectionResult({
    required this.ok,
    this.leadId,
    this.status,
    this.endedAt,
    this.endedBy,
    this.message,
    this.errorCode,
    this.idempotent,
    this.allowanceRestored,
    this.restorationGranted,
  });

  factory EndConnectionResult.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    bool? parseBool(dynamic v) {
      if (v is bool) return v;
      return null;
    }

    return EndConnectionResult(
      ok: json['ok'] == true,
      leadId: json['lead_id'] as String?,
      status: json['status'] as String?,
      endedAt: parseTs(json['ended_at']),
      endedBy: json['ended_by'] as String?,
      message: json['message'] as String?,
      errorCode: json['error_code'] as String?,
      idempotent: parseBool(json['idempotent']),
      allowanceRestored: parseBool(json['allowance_restored']),
      restorationGranted: parseBool(json['restoration_granted']),
    );
  }
}

/// Accepted provider linked to the signed-in client via `leads.status = accepted`.
class AcceptedProvider {
  final String leadId;
  final String providerId;
  final String providerType;
  final String fullName;
  final String? avatarUrl;
  final String? specializationLabel;
  final int experienceYears;
  final double rating;
  final int reviewCount;
  final bool verified;
  final String relationshipStatus;
  final String? locationLabel;
  final DateTime connectedAt;

  const AcceptedProvider({
    required this.leadId,
    required this.providerId,
    required this.providerType,
    required this.fullName,
    this.avatarUrl,
    this.specializationLabel,
    this.experienceYears = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.verified = false,
    this.relationshipStatus = 'accepted',
    this.locationLabel,
    required this.connectedAt,
  });

  bool get isActive => relationshipStatus == 'accepted';

  String get roleLabel =>
      providerType == 'nutritionist' ? 'Nutritionist' : 'Trainer';

  /// Back-compat for trainer-specific call sites.
  String get trainerId => providerId;
}

/// Alias kept for existing imports/tests.
typedef AcceptedTrainer = AcceptedProvider;
