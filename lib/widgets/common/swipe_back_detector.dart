import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Detects swipe-back gesture (iOS style) and navigates back
/// Wrap page content with this to enable swipe-back navigation
class SwipeBackDetector extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double swipeThreshold;

  const SwipeBackDetector({
    super.key,
    required this.child,
    this.enabled = true,
    this.swipeThreshold = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Swipe right (from left edge) to go back
        if (details.primaryVelocity != null && details.primaryVelocity! < -swipeThreshold) {
          if (context.canPop()) {
            HapticFeedback.lightImpact();
            context.pop();
          }
        }
      },
      child: child,
    );
  }
}
