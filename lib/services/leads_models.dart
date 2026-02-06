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
  final int remaining;
  final int limit;

  CreateLeadResult({
    required this.leadId,
    required this.status,
    required this.remaining,
    required this.limit,
  });

  factory CreateLeadResult.fromJson(Map<String, dynamic> json) {
    return CreateLeadResult(
      leadId: json['lead_id'] as String,
      status: json['status'] as String,
      remaining: json['remaining'] as int,
      limit: json['limit'] as int,
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
