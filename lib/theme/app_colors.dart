import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppColors {
  // Base (dark-theme defaults; use *Of(context) for theme-aware)
  static const Color bg = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121A2B);
  static const Color surfaceSoft = Color(0xFF1A2335);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x80FFFFFF);
  static const Color border = Color(0x1AFFFFFF);

  /// Theme-aware; use for background to avoid black-on-black in light mode.
  static Color bgOf(BuildContext context) => DesignTokens.backgroundOf(context);
  static Color surfaceOf(BuildContext context) => DesignTokens.surfaceOf(context);
  static Color surfaceSoftOf(BuildContext context) =>
      DesignTokens.surfaceElevatedOf(context);
  static Color textPrimaryOf(BuildContext context) =>
      DesignTokens.textPrimaryOf(context);
  static Color textSecondaryOf(BuildContext context) =>
      DesignTokens.textSecondaryOf(context);
  static List<BoxShadow> cardShadowOf(BuildContext context) =>
      DesignTokens.cardShadowOf(context);

  // Accents
  static const Color orange = Color(0xFFFF8A00);
  static const Color orangeLight = Color(0xFFFFB347);
  static const Color pink = Color(0xFFFF3D6E);
  static const Color purple = Color(0xFF7A5CFF);
  static const Color red = Color(0xFFFF5A5A);
  static const Color green = Color(0xFF3ED598);
  static const Color blue = Color(0xFF4DA3FF);
  static const Color cyan = Color(0xFF2BD9FF);
  static const Color yellow = Color(0xFFFFD93D);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [orange, pink, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient stepsGradient = LinearGradient(
    colors: [orange, yellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient caloriesGradient = LinearGradient(
    colors: [Color(0xFFFF5A5A), Color(0xFFFF8A7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient waterGradient = LinearGradient(
    colors: [blue, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient distanceGradient = LinearGradient(
    colors: [purple, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Become a Trainer tile, page, and profile button (orange → pink)
  static const LinearGradient becomeTrainerGradient = LinearGradient(
    colors: [orange, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Video Session Role Gradients
  static const LinearGradient clientVideoGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFFFC300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient trainerVideoGradient = LinearGradient(
    colors: [Color(0xFFFF5A2A), Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient nutritionistVideoGradient = LinearGradient(
    colors: [Color(0xFFFF8A00), Color(0xFFFFD54A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bmiGradient = LinearGradient(
    colors: [Color(0xFF2BC88A), Color(0xFFB6F7D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Smooth blend overlay: dark at top, transparent mid, fades to [bgColor]
  /// at bottom. Use on cover/hero above the main content for a seamless
  /// transition. Same curve on home and profile.
  static LinearGradient coverBlendGradient(Color bgColor) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.18),
        Colors.black.withValues(alpha: 0.04),
        Colors.transparent,
        bgColor.withValues(alpha: 0.06),
        bgColor.withValues(alpha: 0.26),
        bgColor.withValues(alpha: 0.58),
        bgColor.withValues(alpha: 0.84),
        bgColor,
      ],
      stops: const [0.0, 0.18, 0.38, 0.50, 0.62, 0.76, 0.90, 1.0],
    );
  }

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
