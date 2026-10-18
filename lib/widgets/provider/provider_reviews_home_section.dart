import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/provider_reviews_repository.dart';
import '../home_v3/home_premium_theme.dart';

class ProviderReviewsHomeSection extends StatefulWidget {
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
  State<ProviderReviewsHomeSection> createState() =>
      _ProviderReviewsHomeSectionState();
}

class _ProviderReviewsHomeSectionState
    extends State<ProviderReviewsHomeSection> {
  ProviderReviewSummary? _summary;
  bool _summaryFailed = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final ProviderReviewsRepository repository;
    final String? providerId;
    try {
      // Construct only when Supabase is available (widget tests may omit it).
      repository = ProviderReviewsRepository();
      providerId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return;
    }
    if (providerId == null) return;
    try {
      final summary = await repository.getSummary(providerId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _summaryFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _summaryFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primary = HomePremiumTheme.primaryText(isLight);
    final secondary = HomePremiumTheme.secondaryText(isLight);
    final fallbackAverage = widget.reviews.isEmpty
        ? 0.0
        : widget.reviews.fold<int>(0, (sum, review) => sum + review.rating) /
              widget.reviews.length;
    final average = _summary?.rating ?? fallbackAverage;
    final totalReviews = _summary?.totalReviews ?? widget.reviews.length;

    const starYellow = Color(0xFFFFB020);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 22, color: starYellow),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: starYellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reviews & Ratings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
            if (!widget.loading && totalReviews > 0)
              Semantics(
                label:
                    '${average.toStringAsFixed(1)} out of 5, $totalReviews reviews',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 20, color: starYellow),
                    const SizedBox(width: 4),
                    Text(
                      '${average.toStringAsFixed(1)} ($totalReviews)',
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
        if (_summaryFailed) ...[
          const SizedBox(height: 6),
          Text(
            'Rating summary could not refresh. Recent reviews are shown below.',
            style: TextStyle(color: secondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        if (widget.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          )
        else if (widget.reviews.isEmpty)
          Text(
            'No reviews yet. Reviews from your clients will appear here.',
            style: TextStyle(color: secondary, height: 1.35),
          )
        else
          _ReviewsCarousel(reviews: widget.reviews),
      ],
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
        color: HomePremiumTheme.providerReviewCardSurface(isLight),
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

/// Horizontal review carousel with safe cyclic paging (no duplicated child trees).
class _ReviewsCarousel extends StatefulWidget {
  const _ReviewsCarousel({required this.reviews});

  final List<ProviderReview> reviews;

  @override
  State<_ReviewsCarousel> createState() => _ReviewsCarouselState();
}

class _ReviewsCarouselState extends State<_ReviewsCarousel> {
  static const _autoplayInterval = Duration(milliseconds: 4500);
  static const _pageAnim = Duration(milliseconds: 380);
  static const _loopBlock = 1000;

  PageController? _controller;
  Timer? _timer;
  int _page = 0;
  bool _userDragging = false;

  bool get _canLoop => widget.reviews.length >= 2;

  int get _initialPage =>
      _canLoop ? widget.reviews.length * (_loopBlock ~/ 2) : 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: _canLoop ? 0.92 : 1,
      initialPage: _initialPage,
    );
    _page = _initialPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restartAutoplay();
    });
  }

  @override
  void didUpdateWidget(covariant _ReviewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.reviews.map((r) => r.id).join('|');
    final newIds = widget.reviews.map((r) => r.id).join('|');
    if (oldIds == newIds && oldWidget.reviews.length == widget.reviews.length) {
      return;
    }
    _timer?.cancel();
    _controller?.dispose();
    _controller = PageController(
      viewportFraction: _canLoop ? 0.92 : 1,
      initialPage: _initialPage,
    );
    _page = _initialPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restartAutoplay();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  bool get _animationsDisabled {
    final mq = MediaQuery.maybeOf(context);
    return mq?.disableAnimations ?? false;
  }

  void _restartAutoplay() {
    _timer?.cancel();
    if (!_canLoop || _animationsDisabled) return;
    _timer = Timer.periodic(_autoplayInterval, (_) {
      if (!mounted || _userDragging) return;
      final controller = _controller;
      if (controller == null || !controller.hasClients) return;
      controller.nextPage(duration: _pageAnim, curve: Curves.easeInOut);
    });
  }

  int _logicalIndex(int page) {
    final count = widget.reviews.length;
    if (count == 0) return 0;
    return page % count;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    final count = widget.reviews.length;
    final logical = _logicalIndex(_page);

    return Column(
      children: [
        SizedBox(
          height: 118,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _userDragging = true;
                _timer?.cancel();
              } else if (notification is ScrollEndNotification) {
                _userDragging = false;
                _restartAutoplay();
              }
              return false;
            },
            child: PageView.builder(
              controller: controller,
              itemCount: _canLoop ? null : count,
              onPageChanged: (page) {
                if (!mounted) return;
                setState(() => _page = page);
              },
              itemBuilder: (context, index) {
                final review = widget.reviews[_logicalIndex(index)];
                return Padding(
                  padding: EdgeInsets.only(right: _canLoop ? 8 : 0),
                  child: _ReviewCard(review: review),
                );
              },
            ),
          ),
        ),
        if (_canLoop) ...[
          const SizedBox(height: 10),
          Semantics(
            label: 'Review ${logical + 1} of $count',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) {
                final active = i == logical;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: active
                        ? HomePremiumTheme.clientsManagementAccent(
                            Theme.of(context).brightness == Brightness.light,
                          )
                        : HomePremiumTheme.providerCardBorder(
                            Theme.of(context).brightness == Brightness.light,
                          ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primary = HomePremiumTheme.primaryText(isLight);
    final secondary = HomePremiumTheme.secondaryText(isLight);
    final body = review.body?.trim() ?? '';

    return Semantics(
      label:
          '${review.reviewerName}, ${review.rating} out of 5 stars${body.isEmpty ? '' : ', $body'}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: HomePremiumTheme.providerReviewCardSurface(isLight),
          borderRadius: BorderRadius.circular(14),
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
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
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
              const SizedBox(height: 6),
              Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: secondary, height: 1.3, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
