import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderReview {
  final String id;
  final int rating;
  final String? body;
  final DateTime createdAt;
  final String reviewerName;

  ProviderReview({
    required this.id,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.reviewerName,
  });

  factory ProviderReview.fromJson(Map<String, dynamic> json) {
    return ProviderReview(
      id: json['id'] as String,
      rating: (json['rating'] as num).toInt(),
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewerName: json['reviewer_name'] as String? ?? 'Client',
    );
  }
}

class ProviderReviewsRepository {
  final SupabaseClient _supabase;

  ProviderReviewsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<ProviderReview>> listForProvider(String providerId) async {
    final response = await _supabase.rpc(
      'list_provider_reviews',
      params: {'p_provider_id': providerId, 'p_limit': 20},
    );
    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(ProviderReview.fromJson)
        .toList();
  }

  Future<void> submitReview({
    required String providerId,
    required int rating,
    String? body,
  }) async {
    final result = await _supabase.rpc(
      'submit_provider_review',
      params: {
        'p_provider_id': providerId,
        'p_rating': rating,
        'p_body': body,
      },
    );
    if (result is Map && result['ok'] != true) {
      throw Exception(result['error']?.toString() ?? 'Failed to submit review');
    }
  }
}
