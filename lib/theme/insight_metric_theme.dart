import 'package:flutter/material.dart';

import '../models/metric_insight_types.dart';
import '../widgets/home_v3/home_premium_theme.dart';
import 'design_tokens.dart';

/// Premium muted palette for metric insight screens (matches Home dashboard).
class InsightMetricTheme {
  static const graphCardBg = Color(0xFF171B26);
  static const surfaceCard = Color(0xFF1C1F26);
  static const pageBg = HomePremiumTheme.darkCharcoal;

  static Color pageBgOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? pageBg
        : DesignTokens.lightPageBackground;
  }

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color surfaceCardOf(BuildContext context) {
    return isLight(context)
        ? DesignTokens.lightMutedCardBackground
        : surfaceCard;
  }

  static Color graphCardBgOf(BuildContext context) {
    return isLight(context)
        ? DesignTokens.lightCardBackground
        : graphCardBg;
  }

  static List<BoxShadow> cardShadowOf(BuildContext context) {
    if (isLight(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return cardShadow();
  }

  static Color borderColorOf(BuildContext context) {
    return isLight(context)
        ? DesignTokens.lightBorder
        : Colors.white.withValues(alpha: 0.06);
  }

  /// Hero card gradient — soft tint in light mode, rich gradient in dark.
  LinearGradient heroGradientOf(BuildContext context) {
    if (isLight(context)) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.18),
          DesignTokens.lightCardBackground,
        ],
      );
    }
    return cardGradient;
  }

  static Color heroTitleColor(BuildContext context) =>
      DesignTokens.textPrimaryOf(context);

  static Color heroSubtitleColor(BuildContext context) =>
      DesignTokens.textSecondaryOf(context);

  final MetricType type;
  final String title;
  final String unit;
  final LinearGradient cardGradient;
  final Color accent;
  final LinearGradient ringGradient;
  final String heroTag;

  const InsightMetricTheme({
    required this.type,
    required this.title,
    required this.unit,
    required this.cardGradient,
    required this.accent,
    required this.ringGradient,
    required this.heroTag,
  });

  factory InsightMetricTheme.from(MetricType type) {
    switch (type) {
      case MetricType.water:
        return const InsightMetricTheme(
          type: MetricType.water,
          title: 'Water Insights',
          unit: 'L',
          cardGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF163B5A), Color(0xFF1E4A72)],
          ),
          accent: Color(0xFF2FC8FF),
          ringGradient: LinearGradient(
            colors: [Color(0xFF2FC8FF), Color(0xFF5DD4FF)],
          ),
          heroTag: 'tile_water',
        );
      case MetricType.distance:
        return const InsightMetricTheme(
          type: MetricType.distance,
          title: 'Distance Insights',
          unit: 'km',
          cardGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF312B56), Color(0xFF3F3970)],
          ),
          accent: Color(0xFF8A5DFF),
          ringGradient: LinearGradient(
            colors: [Color(0xFF8A5DFF), Color(0xFFA88AFF)],
          ),
          heroTag: 'tile_distance',
        );
      case MetricType.calories:
        return const InsightMetricTheme(
          type: MetricType.calories,
          title: 'Active Calories Insights',
          unit: 'kcal',
          cardGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4D3127), Color(0xFF654034)],
          ),
          accent: Color(0xFFFF7A45),
          ringGradient: LinearGradient(
            colors: [Color(0xFFFF7A45), Color(0xFFFF9A6E)],
          ),
          heroTag: 'tile_calories',
        );
      case MetricType.steps:
        return const InsightMetricTheme(
          type: MetricType.steps,
          title: 'Steps Insights',
          unit: 'steps',
          cardGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4E4020), Color(0xFF63522B)],
          ),
          accent: Color(0xFFF7A928),
          ringGradient: LinearGradient(
            colors: [Color(0xFFF7A928), Color(0xFFFFC857)],
          ),
          heroTag: 'tile_steps',
        );
    }
  }

  static List<BoxShadow> cardShadow() => HomePremiumTheme.softCardShadow(false);
}
