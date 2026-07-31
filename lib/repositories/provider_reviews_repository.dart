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

  /// Current client's review for [providerId], if any.
  Future<ProviderReview?> getMyReviewForProvider(String providerId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return null;
    try {
      // Prefer canonical Retool/Flutter reviews table.
      final row = await _supabase
          .from('reviews')
          .select('id, rating, review_text, created_at, status')
          .eq('provider_id', providerId)
          .eq('client_id', me)
          .neq('status', 'deleted')
          .maybeSingle();
      if (row != null) {
        return ProviderReview(
          id: row['id'] as String,
          rating: (row['rating'] as num).toInt(),
          body: row['review_text'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          reviewerName: 'You',
        );
      }
    } catch (_) {
      // Fall back to compatibility view/table.
    }
    try {
      final row = await _supabase
          .from('provider_reviews')
          .select('id, rating, body, created_at')
          .eq('provider_id', providerId)
          .eq('client_id', me)
          .maybeSingle();
      if (row == null) return null;
      return ProviderReview(
        id: row['id'] as String,
        rating: (row['rating'] as num).toInt(),
        body: row['body'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        reviewerName: 'You',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> submitReview({
    required String providerId,
    required int rating,
    String? body,
  }) async {
    try {
      final result = await _supabase.rpc(
        'submit_provider_review',
        params: {
          'p_provider_id': providerId,
          'p_rating': rating,
          'p_body': body,
        },
      );
      if (result is Map && result['ok'] != true) {
        throw Exception(
          result['error']?.toString() ?? 'Failed to submit review',
        );
      }
    } catch (e) {
      final s = e.toString();
      if (s.contains('PGRST202') ||
          s.contains('Could not find the function') ||
          s.contains('submit_provider_review')) {
        throw Exception(
          'Review service is not set up on the server yet. '
          'Apply supabase/migrations/20260731_provider_reviews_and_public_profile_rpc.sql',
        );
      }
      rethrow;
    }
  }
}
