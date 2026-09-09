import 'package:flutter/material.dart';

import '../../repositories/provider_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../home_v3/home_premium_theme.dart';

class ProviderReviewsHomeSection extends StatelessWidget {
  const ProviderReviewsHomeSection({
    super.key,
    required this.reviews,
    required this.loading,
    required this.onRetry,
  });

  final List<ProviderReview> reviews;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primary = HomePremiumTheme.primaryText(isLight);
    final secondary = HomePremiumTheme.secondaryText(isLight);
    final visible = reviews.take(3).toList();
    final average = reviews.isEmpty
        ? 0.0
        : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
            reviews.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight
            ? HomePremiumTheme.lightCreamCard
            : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reviews & Ratings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ),
              if (!loading && reviews.isNotEmpty)
                Semantics(
                  label:
                      '${average.toStringAsFixed(1)} out of 5, ${reviews.length} reviews',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 20, color: Color(0xFFFFB020)),
                      const SizedBox(width: 4),
                      Text(
                        '${average.toStringAsFixed(1)} (${reviews.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else if (reviews.isEmpty)
            Text(
              'No reviews yet. Reviews from your clients will appear here.',
              style: TextStyle(color: secondary, height: 1.35),
            )
          else
            ...visible.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewPreview(review: review),
              ),
            ),
        ],
      ),
    );
  }
}

class ProviderReviewsHomeError extends StatelessWidget {
  const ProviderReviewsHomeError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight
            ? HomePremiumTheme.lightCreamCard
            : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.rate_review_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load your reviews.',
              style: TextStyle(color: HomePremiumTheme.primaryText(isLight)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ReviewPreview extends StatelessWidget {
  const _ReviewPreview({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primary = HomePremiumTheme.primaryText(isLight);
    final secondary = HomePremiumTheme.secondaryText(isLight);
    final body = review.body?.trim() ?? '';
    return Semantics(
      label: '${review.reviewerName}, ${review.rating} out of 5 stars${body.isEmpty ? '' : ', $body'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 16,
                    color: const Color(0xFFFFB020),
                  ),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondary, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
