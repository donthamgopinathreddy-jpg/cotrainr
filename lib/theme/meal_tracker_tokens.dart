import 'package:flutter/material.dart';

/// Meal Tracker specific design tokens (colors, gradients, radii).
///
/// Keeps the redesign isolated from the rest of the app theme while still
/// supporting light/dark mode.
class MealTrackerTokens {
  // Light mode
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightMutedSurface = Color(0xFFF8F9FB);

  // Dark mode — neutral pure-black page shell.
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF0A0A0A);

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

  static const Color accentMint = Color(0xFF86EFAC);

  /// Soft green wash — matches home [UnifiedMetricsTileV3] metric cards.
  static LinearGradient intakeTileGradient(bool isLight) {
    if (isLight) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(lightMutedSurface, accent, 0.52)!,
          Color.lerp(lightMutedSurface, accentMint, 0.38)!,
          Color.lerp(lightMutedSurface, accentMint, 0.18)!,
        ],
        stops: const [0.0, 0.40, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(darkCard, accent, 0.36)!,
        Color.lerp(darkCard, accent2, 0.24)!,
        Color.lerp(darkCard, accent2, 0.10)!,
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  /// Muted macro bar fills on the intake hero (same green family).
  static Color macroBarFill(int index) {
    switch (index) {
      case 0:
        return accent.withValues(alpha: 0.72);
      case 1:
        return accent.withValues(alpha: 0.58);
      default:
        return accent2.withValues(alpha: 0.65);
    }
  }

  // Macro colors (meal tiles / pills)
  static const Color macroProtein = Color(0xFF22C55E);
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
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);
  }

  static Color textSecondaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFA1A1AA)
        : const Color(0xFF6B7280);
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

