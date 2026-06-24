import 'package:flutter/material.dart';

import 'home_premium_theme.dart';
import 'metric_progress_ring.dart';

/// Circular progress ring with centered icon (Samsung Health style).
class MetricCenterWidget extends StatelessWidget {
  final int metricIndex;
  final IconData icon;
  final double progressPercent;
  final bool selected;

  const MetricCenterWidget({
    super.key,
    required this.metricIndex,
    required this.icon,
    required this.progressPercent,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = HomePremiumTheme.metricPalette(metricIndex, isLight);

    final ringSize = selected ? 92.0 : 72.0;
    final stroke = selected ? 12.0 : 10.0;

    final trackColor = isLight
        ? HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.10);

    return MetricProgressRing(
      progressPercent: progressPercent,
      color: palette.accent,
      gradient: palette.ringGradient,
      icon: icon,
      size: ringSize,
      strokeWidth: stroke,
      trackColor: trackColor,
    );
  }
}
