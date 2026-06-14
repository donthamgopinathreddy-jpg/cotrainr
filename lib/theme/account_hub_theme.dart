import 'package:flutter/material.dart';

import '../widgets/home_v3/home_premium_theme.dart';
import 'design_tokens.dart';

/// Shared visual tokens for Profile / Settings account hub pages.
abstract final class AccountHubTheme {
  static const goalsGreen = Color(0xFF22C55E);
  static const subscriptionAmber = Color(0xFFF59E0B);
  static const messagesBlue = Color(0xFF3B82F6);
  static const dangerRed = Color(0xFFEF4444);

  static const cardRadius = 22.0;
  static const sectionRadius = 24.0;
  static const rowHeight = 52.0;
  static const horizontalMargin = 16.0;
  static const iconSize = 22.0;

  static Color pageBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? HomePremiumTheme.darkCharcoal : DesignTokens.lightPageBackground;
  }

  static Color cardBg(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return HomePremiumTheme.softCardShadow(!isDark);
  }

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
      );

  static TextStyle rowTitle(BuildContext context) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle rowSubtitle(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
      );
}
