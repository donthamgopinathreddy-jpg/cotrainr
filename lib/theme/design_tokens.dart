import 'package:flutter/material.dart';

/// Design Tokens for Cotrainr App
/// Inspired by Apple Fitness+ and Nike Training Club
/// Modern, clean, soft-gradients, rounded cards
/// Production-ready design system with full light/dark theme support
class DesignTokens {
  // ========== DARK THEME COLORS ==========
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF121A2B);
  static const Color darkSurfaceElevated = Color(0xFF1A2335);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xB3FFFFFF); // 70% opacity
  static const Color darkTextTertiary = Color(0x80FFFFFF); // 50% opacity

  // ========== LIGHT THEME COLORS ==========
  static const Color lightBackground = Color(0xFFF5F5F5); // Very light grey for better visual hierarchy
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0x99000000); // 60% opacity
  static const Color lightTextTertiary = Color(0x66000000); // 40% opacity

  // ========== ACCENT COLORS (Theme-agnostic) ==========
  // Orange gradient (primary) - Apple Fitness+ inspired
  static const Color accentOrange = Color(0xFFFF8A00);
  static const Color accentOrangeLight = Color(0xFFFFA64D);
  static const Color accentAmber = Color(0xFFFFC247);

  // Blue gradient (secondary) - Nike Training Club inspired
  static const Color accentBlue = Color(0xFF4DA3FF);
  static const Color accentBlueLight = Color(0xFF6BB5FF);
  static const Color accentPurple = Color(0xFF8B5CF6);

  // Status colors
  static const Color accentGreen = Color(0xFF3ED598);
  static const Color accentRed = Color(0xFFFF5A5A);
  static const Color accentYellow = Color(0xFFFFD93D);

  // ========== STATIC PROPERTIES (Backward Compatibility) ==========
  // These use dark theme as default for backward compatibility
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = darkTextTertiary;
  static Color get borderColor => Colors.white.withValues(alpha: 0.10);

  // Static border colors for theme-agnostic use
  static Color get borderColorDark => Colors.white.withValues(alpha: 0.10);
  static Color get borderColorLight => Colors.black.withValues(alpha: 0.08);

  // Static shadow for backward compatibility
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: accentOrange.withValues(alpha: 0.4),
      blurRadius: 20,
      offset: const Offset(0, 0),
    ),
  ];

  // ========== THEME-AWARE GETTERS ==========
  static Color backgroundOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color surfaceOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color surfaceElevatedOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurfaceElevated
        : lightSurfaceElevated;
  }

  static Color textPrimaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color textSecondaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  static Color textTertiaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextTertiary
        : lightTextTertiary;
  }

  static Color borderColorOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
  }

  static List<BoxShadow> cardShadowOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.black.withValues(alpha: 0.25),
        blurRadius: 4,
        offset: const Offset(0, 4),
        spreadRadius: 1,
      ),
      if (!isDark)
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.5),
          blurRadius: 3,
          offset: const Offset(0, -1),
          spreadRadius: 0,
        ),
    ];
  }

  static List<BoxShadow> glowShadowOf(BuildContext context) {
    return [
      BoxShadow(
        color: accentOrange.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, 0),
        spreadRadius: 2,
      ),
    ];
  }

  static Color glassCardColorOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.8);
  }

  // ========== SOFT GRADIENTS (Apple Fitness+ Style) ==========
  // Primary gradient - Orange to Amber (warm, energetic)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentOrange, accentAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );

  // Secondary gradient - Blue to Purple (cool, calm)
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [accentBlue, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );

  // Success gradient - Green
  static const LinearGradient successGradient = LinearGradient(
    colors: [accentGreen, Color(0xFF2BC88A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft gradient for cards (subtle, elegant)
  static LinearGradient softGradient(BuildContext context) {
    return LinearGradient(
      colors: Theme.of(context).brightness == Brightness.dark
          ? [darkSurface, darkSurfaceElevated]
          : [lightSurface, lightSurface.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ========== RADII (Rounded Cards - Nike Training Club Style) ==========
  static const double radiusCard = 24.0; // Main cards
  static const double radiusTile = 20.0; // Smaller tiles
  static const double radiusSearch = 20.0; // Search bar
  static const double radiusChipSmall = 18.0; // Compact chips
  static const double radiusChip = 999.0; // Pill shape (fully rounded)
  static const double radiusButton = 999.0; // Buttons (fully rounded)
  static const double radiusSecondary = 16.0; // Secondary elements
  static const double radiusSmall = 12.0; // Small elements

  // ========== SHADOWS (Soft, Layered - Apple Style) ==========
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 15,
      offset: const Offset(0, 5),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> subtleShadowOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.05),
        blurRadius: 15,
        offset: const Offset(0, 5),
        spreadRadius: 0,
      ),
    ];
  }

  // ========== SPACING (8pt Grid System) ==========
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // ========== TYPOGRAPHY (Poppins - Clean, Modern) ==========
  static const double fontSizeH1 = 32.0; // Large titles
  static const double fontSizeH2 = 24.0; // Section headers
  static const double fontSizeH3 = 20.0; // Card titles
  static const double fontSizeSection = 18.0; // Section titles (Quick Actions, etc.)
  static const double fontSizeBody = 16.0; // Body text
  static const double fontSizeBodySmall = 14.0; // Small body
  static const double fontSizeMeta = 12.0; // Metadata
  static const double fontSizeCaption = 11.0; // Captions

  // Font weights
  static const FontWeight fontWeightBold = FontWeight.w700;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightRegular = FontWeight.w400;

  // ========== ICON SIZES ==========
  static const double iconSizeLarge = 32.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeSmall = 20.0;
  static const double iconSizeTiny = 16.0;

  // Backward compatibility aliases
  static const double iconSizeNavBar = iconSizeMedium;
  static const double iconSizeTile = iconSizeSmall;
  static const double iconSizeList = iconSizeTiny;

  // ========== GLASS MORPHISM (Apple Style) ==========
  static Color get glassCardColor => Colors.white.withValues(alpha: 0.06);
  static const double glassBlur = 12.0;

  // ========== ANIMATIONS (Smooth, Natural) ==========
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  static const Curve animationCurve = Curves.easeOutCubic;
  static const Curve animationCurveSpring = Curves.easeOutBack;

  // ========== TOUCH / INTERACTION ==========
  /// Scale on press for cards and buttons (0.97–0.99).
  static const double interactionPressScale = 0.97;
  /// Duration for press/release scale and micro-interactions.
  static const Duration interactionDuration = Duration(milliseconds: 120);
  static const Curve interactionCurve = Curves.easeOut;

  // ========== OPACITY ==========
  static const double opacityInactive = 0.50;
  static const double opacitySecondary = 0.70;
  static const double opacityTertiary = 0.40;

  // ========== ELEVATION ==========
  static const double elevationCard = 2.0;
  static const double elevationButton = 4.0;
  static const double elevationModal = 8.0;
}
