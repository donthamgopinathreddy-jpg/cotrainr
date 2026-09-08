import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';

/// Subtle fade + upward slide for list / section entrance.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? duration;
  final double slideOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration,
    this.slideOffset = 12,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final delayMs = (80 + (index.clamp(0, 12) * 40));
    final total = reduceMotion
        ? Duration.zero
        : (duration ?? Duration(milliseconds: 280 + delayMs.clamp(0, 200)));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: reduceMotion ? Curves.linear : Curves.easeOutCubic,
      builder: (context, t, child) {
        if (reduceMotion) return child ?? const SizedBox.shrink();
        final opacity = Curves.easeOut.transform(t.clamp(0.0, 1.0));
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Cross-fades between loading and content without layout jump.
class ContentFade extends StatelessWidget {
  final bool loading;
  final Widget loadingChild;
  final Widget child;

  const ContentFade({
    super.key,
    required this.loading,
    required this.loadingChild,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : Motion.fadeDuration,
      switchInCurve: reduceMotion ? Curves.linear : Curves.easeOut,
      switchOutCurve: reduceMotion ? Curves.linear : Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(loading),
        child: loading ? loadingChild : child,
      ),
    );
  }
}
