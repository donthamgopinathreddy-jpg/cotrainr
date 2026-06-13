import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/coaching_insight.dart';

/// Single coaching line with fade-only [AnimatedSwitcher] rotation.
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
  Timer? _timer;
  int _index = 0;

  static const _fadeMs = 300;
  static const _rotateMs = 9000;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant CoachingInsightCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights != widget.insights) {
      _index = 0;
      _restartTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.insights.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: _rotateMs), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.insights.length;
      });
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) return const SizedBox.shrink();

    final insight = widget.insights[_index.clamp(0, widget.insights.length - 1)];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: _fadeMs),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) => currentChild!,
      child: Text(
        insight.displayText,
        key: ValueKey<String>(insight.id),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.35,
          letterSpacing: 0.1,
          color: insight.accentColor.withValues(alpha: 0.95),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
