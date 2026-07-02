import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/coaching_insight.dart';
import '../../theme/design_tokens.dart';

/// Swipable reminder strip — auto-slides left, sits below the hero cover.
class CoachingInsightCarousel extends StatefulWidget {
  final List<CoachingInsight> insights;

  const CoachingInsightCarousel({
    super.key,
    required this.insights,
  });

  @override
  State<CoachingInsightCarousel> createState() =>
      _CoachingInsightCarouselState();
}

class _CoachingInsightCarouselState extends State<CoachingInsightCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  static const _autoPlayMs = 5500;
  static const _slideMs = 480;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant CoachingInsightCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights != widget.insights) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.insights.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: _autoPlayMs), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % widget.insights.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: _slideMs),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) return const SizedBox.shrink();

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 58,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.insights.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return _ReminderSlide(
                insight: widget.insights[index],
                isLight: isLight,
              );
            },
          ),
        ),
        if (widget.insights.length > 1) ...[
          const SizedBox(height: 8),
          _PageDots(
            count: widget.insights.length,
            index: _currentPage,
            isLight: isLight,
          ),
        ],
      ],
    );
  }
}

class _ReminderSlide extends StatelessWidget {
  final CoachingInsight insight;
  final bool isLight;

  const _ReminderSlide({
    required this.insight,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isLight
        ? DesignTokens.lightMutedCardBackground
        : DesignTokens.darkSurface;
    final border = DesignTokens.borderColorOf(context);
    final textColor = DesignTokens.textPrimaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: insight.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              insight.emoji,
              style: const TextStyle(fontSize: 20, height: 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                insight.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: 0.05,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int index;
  final bool isLight;

  const _PageDots({
    required this.count,
    required this.index,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active
                ? DesignTokens.textPrimaryOf(context)
                : DesignTokens.textSecondaryOf(context)
                    .withValues(alpha: isLight ? 0.35 : 0.45),
          ),
        );
      }),
    );
  }
}
