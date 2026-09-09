import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/provider_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/home_v3/home_premium_theme.dart';

class ProviderReviewsPage extends StatefulWidget {
  const ProviderReviewsPage({super.key});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  final _repository = ProviderReviewsRepository();
  bool _loading = true;
  bool _failed = false;
  List<ProviderReview> _reviews = const [];
  ProviderReviewSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final providerId = Supabase.instance.client.auth.currentUser?.id;
    if (providerId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await Future.wait<dynamic>([
        _repository.listForProvider(providerId, limit: 50),
        _repository.getSummary(providerId),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = result[0] as List<ProviderReview>;
        _summary = result[1] as ProviderReviewSummary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;
    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Reviews & Ratings',
        backgroundColor: bg,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _ErrorState(onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _SummaryCard(summary: _summary),
                      const SizedBox(height: 12),
                      if (_reviews.isEmpty)
                        const _EmptyState()
                      else
                        ..._reviews.map((review) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReviewCard(review: review),
                            )),
                      if ((_summary?.totalReviews ?? 0) > _reviews.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Showing the latest ${_reviews.length} reviews.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: HomePremiumTheme.secondaryText(isLight),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final ProviderReviewSummary? summary;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final value = summary ?? const ProviderReviewSummary(rating: 0, totalReviews: 0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 30, color: Color(0xFFFFB020)),
          const SizedBox(width: 10),
          Text(
            value.rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.totalReviews == 1 ? '1 review' : '${value.totalReviews} reviews',
              style: TextStyle(color: HomePremiumTheme.secondaryText(isLight)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final body = review.body?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: HomePremiumTheme.primaryText(isLight),
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 17,
                    color: const Color(0xFFFFB020),
                  ),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                height: 1.35,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            MaterialLocalizations.of(context).formatMediumDate(review.createdAt.toLocal()),
            style: TextStyle(
              fontSize: 12,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Text(
        'No reviews yet. Reviews from your clients will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: HomePremiumTheme.secondaryText(isLight)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('Could not load reviews.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
