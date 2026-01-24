import 'package:flutter/material.dart';

/// Meal Tracker specific design tokens (colors, gradients, radii).
///
/// Keeps the redesign isolated from the rest of the app theme while still
/// supporting light/dark mode.
class MealTrackerTokens {
  // Light mode
  static const Color lightBackground = Color(0xFFECFDF5); // light green wash
  static const Color lightCard = Color(0xFFFFFFFF);

  // Dark mode
  static const Color darkBackground = Color(0xFF0B0F0D); // deep black green
  static const Color darkCard = Color(0xFF121816);

  // Accent
  static const Color accent = Color(0xFF22C55E);
  static const Color accent2 = Color(0xFF16A34A);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  // Daily hero gradient (Green -> Mint)
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF22C55E),
      Color(0xFF86EFAC), // mint
    ],
  );

  // Macro colors (color-blind safer trio)
  static const Color macroProtein = Color(0xFF22C55E); // green
  static const Color macroCarbs = Color(0xFF14B8A6); // teal
  static const Color macroFats = Color(0xFFFBBF24); // amber/yellow

  // Radii
  static const double radiusHeader = 16;
  static const double radiusCard = 24;
  static const double radiusTile = 22;
  static const double radiusSheet = 32;

  static Color pageBgOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color cardBgOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;
  }

  static Color textPrimaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEFFFF5)
        : const Color(0xFF0B1B12);
  }

  static Color textSecondaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFBFE8D1).withValues(alpha: 0.75)
        : const Color(0xFF2E5A42).withValues(alpha: 0.75);
  }

  static List<BoxShadow> cardShadowOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      // subtle green glow
      return [
        BoxShadow(
          color: accent.withValues(alpha: 0.16),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];
    }
    return [
      BoxShadow(
        color: accent.withValues(alpha: 0.10),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ];
  }
}

