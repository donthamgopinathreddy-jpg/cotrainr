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

  /// Shared switch treatment used app-wide through [AppTheme].
  ///
  /// The previous OFF state was a low-contrast grey pill with a plain thumb,
  /// which made it difficult to tell whether the control was interactive or
  /// which state it represented, especially in dark mode. Keep the standard
  /// switch geometry, but make state explicit with stronger track contrast,
  /// a visible outline and a small state glyph in the thumb.
  static SwitchThemeData switchTheme({required bool isDark}) {
    final offTrack =
        isDark ? const Color(0xFF3F4650) : const Color(0xFFD1D5DB);
    final offOutline =
        isDark ? const Color(0xFF7A8491) : const Color(0xFF9CA3AF);
    final thumb = isDark ? const Color(0xFFF8FAFC) : Colors.white;
    final disabledTrack =
        isDark ? const Color(0xFF2B3037) : const Color(0xFFE5E7EB);
    final disabledThumb =
        isDark ? const Color(0xFF8B949E) : const Color(0xFFB7BDC6);

    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledThumb;
        return thumb;
      }),
      thumbIcon: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        final selected = states.contains(WidgetState.selected);
        return Icon(
          selected ? Icons.check_rounded : Icons.close_rounded,
          size: 13,
          color: selected
              ? DesignTokens.accentOrange
              : (isDark ? const Color(0xFF59616C) : const Color(0xFF6B7280)),
        );
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledTrack;
        return states.contains(WidgetState.selected)
            ? DesignTokens.accentOrange
            : offTrack;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return offOutline.withValues(alpha: 0.35);
        }
        if (states.contains(WidgetState.selected)) {
          return DesignTokens.accentOrange.withValues(alpha: 0.9);
        }
        return offOutline;
      }),
      trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? 1.2 : 1.4;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return DesignTokens.accentOrange.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return DesignTokens.accentOrange.withValues(alpha: 0.10);
        }
        return null;
      }),
    );
  }
}
