import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

/// Premium home dashboard colors — dark charcoal glass & warm light surfaces.
class HomePremiumTheme {
  HomePremiumTheme._();

  // —— Base surfaces ——
  static const Color darkCharcoal = Color(0xFF14161C);
  static const Color darkCard = Color(0xFF1C1F26);
  static const Color lightWarmBg = Color(0xFFF6F4EF);
  static const Color lightCreamCard = Color(0xFFFAF8F4);
  static const Color lightCharcoalText = Color(0xFF2A2D33);

  /// 0 steps, 1 calories, 2 water, 3 distance
  static MetricPalette metricPalette(int index, bool isLight) {
    switch (index % 4) {
      case 0:
        return MetricPalette(
          accent: isLight ? const Color(0xFFE8952E) : DesignTokens.accentOrange,
          accentSoft: isLight ? const Color(0xFFFFB347) : DesignTokens.accentAmber,
          ringGradient: isLight
              ? const LinearGradient(
                  colors: [Color(0xFFE8952E), Color(0xFFFFC247)],
                )
              : AppColors.stepsGradient,
        );
      case 1:
        return MetricPalette(
          accent: isLight ? const Color(0xFFE86B52) : const Color(0xFFFF6B4A),
          accentSoft: isLight ? const Color(0xFFFF8A70) : const Color(0xFFFF8A65),
          ringGradient: isLight
              ? const LinearGradient(
                  colors: [Color(0xFFE86B52), Color(0xFFFF9B7A)],
                )
              : AppColors.caloriesGradient,
        );
      case 2:
        return MetricPalette(
          accent: isLight ? const Color(0xFF3BA8D4) : AppColors.cyan,
          accentSoft: isLight ? const Color(0xFF6BC5E8) : DesignTokens.accentBlue,
          ringGradient: isLight
              ? const LinearGradient(
                  colors: [Color(0xFF4DA8D4), Color(0xFF7DD3FC)],
                )
              : AppColors.waterGradient,
        );
      default:
        return MetricPalette(
          accent: isLight ? const Color(0xFF7C6AE6) : DesignTokens.accentPurple,
          accentSoft: isLight ? const Color(0xFF9B8CF0) : const Color(0xFF9B8CFF),
          ringGradient: isLight
              ? const LinearGradient(
                  colors: [Color(0xFF7C6AE6), Color(0xFFB4A7FF)],
                )
              : AppColors.distanceGradient,
        );
    }
  }

  static LinearGradient metricsTileGradient(
    int focusIndex,
    double phase,
    List<Color> metricAccents,
    bool isLight,
  ) {
    final i0 = phase.floor() % 4;
    final i1 = (i0 + 1) % 4;
    final t = Curves.easeInOut.transform((phase - phase.floor()).clamp(0.0, 1.0));
    final top = Color.lerp(metricAccents[i0], metricAccents[i1], t)!;
    final bot = Color.lerp(
      metricPalette(i0, isLight).accentSoft,
      metricPalette(i1, isLight).accentSoft,
      t,
    )!;

    if (isLight) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(lightCreamCard, top, 0.28)!,
          Color.lerp(lightCreamCard, bot, 0.16)!,
          lightCreamCard,
        ],
        stops: const [0.0, 0.42, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(darkCard, top, 0.22)!,
        Color.lerp(darkCard, bot, 0.14)!,
        darkCard.withValues(alpha: 0.92),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  static LinearGradient bmiTileGradient(bool isLight, Color accent) {
    final warm = isLight ? const Color(0xFFE8A060) : DesignTokens.accentOrange;
    if (isLight) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(lightCreamCard, warm, 0.22)!,
          Color.lerp(lightCreamCard, accent, 0.12)!,
          lightCreamCard,
        ],
        stops: const [0.0, 0.45, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(darkCard, warm, 0.18)!,
        Color.lerp(darkCard, accent, 0.10)!,
        darkCard,
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  static Color weeklyTrackColor(bool isLight) =>
      isLight ? const Color(0xFF2A2D33).withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.10);

  static List<BoxShadow> softCardShadow(bool isLight) {
    if (isLight) {
      return [
        BoxShadow(
          color: const Color(0xFF2A2D33).withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static Color primaryText(bool isLight) =>
      isLight ? lightCharcoalText : const Color(0xFFF2F2F4);

  static Color secondaryText(bool isLight) =>
      isLight ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
}

class MetricPalette {
  final Color accent;
  final Color accentSoft;
  final LinearGradient ringGradient;

  const MetricPalette({
    required this.accent,
    required this.accentSoft,
    required this.ringGradient,
  });
}
