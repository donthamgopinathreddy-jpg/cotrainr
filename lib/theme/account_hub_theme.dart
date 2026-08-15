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

  /// Shared Switch treatment: orange ON, grey OFF, muted disabled.
  static SwitchThemeData switchTheme({required bool isDark}) {
    final offTrack =
        isDark ? const Color(0xFF5C5C5C) : const Color(0xFFB0B0B0);
    final thumb = isDark ? const Color(0xFFF5F5F5) : Colors.white;
    final thumbBorder =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return thumb.withValues(alpha: 0.7);
        }
        return thumb;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        final disabled = states.contains(WidgetState.disabled);
        final base = selected ? DesignTokens.accentOrange : offTrack;
        return disabled ? base.withValues(alpha: 0.4) : base;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return thumbBorder.withValues(alpha: 0.5);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return DesignTokens.accentOrange.withValues(alpha: 0.12);
        }
        return null;
      }),
    );
  }
}
