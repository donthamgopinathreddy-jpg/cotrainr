import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Semantic visual tokens for Login + Signup + Onboarding.
///
/// One Cotrainr language for light (warm athletic) and dark (premium black).
abstract final class AuthTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // —— Page / surfaces ——
  static const Color _lightBg = Color(0xFFF6F1EA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightElevated = Color(0xFFFFFCF8);
  static const Color _lightField = Color(0xFFF3EEE8);
  static const Color _lightMuted = Color(0xFFEDE6DC);
  static const Color _lightBorder = Color(0xFFD9D0C4);
  static const Color _lightPrimary = Color(0xFF16120E);
  static const Color _lightSecondary = Color(0xFF6B645C);
  static const Color _lightMutedText = Color(0xFF8A8278);
  static const Color _lightSelection = Color(0xFFFFF1E0);
  static const Color _lightSelectionBorder = Color(0xFFFFB45A);

  static const Color _darkBg = Color(0xFF050505);
  static const Color _darkSurface = Color(0xFF111111);
  static const Color _darkElevated = Color(0xFF161616);
  static const Color _darkField = Color(0xFF1C1C1C);
  static const Color _darkMuted = Color(0xFF1A1A1A);
  static const Color _darkBorder = Color(0x33FFFFFF);
  static const Color _darkPrimary = Color(0xFFFFFFFF);
  static const Color _darkSecondary = Color(0xFFB4B0AA);
  static const Color _darkMutedText = Color(0xFF8E8A84);
  static const Color _darkSelection = Color(0xFF1A120C);
  static const Color _darkSelectionBorder = Color(0xFFFF9F1A);

  static Color background(BuildContext context) =>
      isDark(context) ? _darkBg : _lightBg;

  static Color surface(BuildContext context) =>
      isDark(context) ? _darkSurface : _lightSurface;

  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? _darkElevated : _lightElevated;

  static Color fieldSurface(BuildContext context) =>
      isDark(context) ? _darkField : _lightField;

  static Color mutedSurface(BuildContext context) =>
      isDark(context) ? _darkMuted : _lightMuted;

  static Color fieldBorder(BuildContext context) =>
      isDark(context) ? _darkBorder : _lightBorder;

  static Color focusedBorder(BuildContext context) => CotrainrGradients.focus;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? _darkPrimary : _lightPrimary;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? _darkSecondary : _lightSecondary;

  static Color mutedText(BuildContext context) =>
      isDark(context) ? _darkMutedText : _lightMutedText;

  static Color icon(BuildContext context) => secondaryText(context);

  static Color selectionSurface(BuildContext context) =>
      isDark(context) ? _darkSelection : _lightSelection;

  static Color selectionBorder(BuildContext context) =>
      isDark(context) ? _darkSelectionBorder : _lightSelectionBorder;

  static Color selectionText(BuildContext context) =>
      isDark(context) ? CotrainrGradients.focus : _lightPrimary;

  static Color progressInactive(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFD8D0C6);

  static Color success(BuildContext context) => isDark(context)
      ? const Color(0xFF4ADE80)
      : const Color(0xFF16A34A);

  static Color error(BuildContext context) => isDark(context)
      ? const Color(0xFFF87171)
      : const Color(0xFFDC2626);

  static Color onPrimaryAction(BuildContext context) =>
      DesignTokens.darkTextPrimary;

  static Color backSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1A1A) : _lightMuted;

  static Color backBorder(BuildContext context) =>
      isDark(context) ? const Color(0x28FFFFFF) : _lightBorder;

  static Color socialSurface(BuildContext context) =>
      isDark(context) ? _darkElevated : _lightSurface;

  static Color socialBorder(BuildContext context) => fieldBorder(context);

  static Color link(BuildContext context) => CotrainrGradients.focus;

  static Color valueControlSurface(BuildContext context) =>
      isDark(context) ? _darkField : _lightSurface;

  static LinearGradient get primaryGradient => CotrainrGradients.primary;

  static Color get accent => CotrainrGradients.focus;

  static TextStyle title(BuildContext context) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
        color: primaryText(context),
      );

  static TextStyle subtitle(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondaryText(context),
      );

  static TextStyle field(BuildContext context, {bool large = false}) =>
      TextStyle(
        fontSize: large ? 18 : 16,
        fontWeight: FontWeight.w500,
        color: primaryText(context),
      );

  static List<BoxShadow> cardShadow(BuildContext context) {
    if (isDark(context)) return const [];
    return [
      BoxShadow(
        color: const Color(0x14000000),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static SystemUiOverlayStyle overlay(BuildContext context) {
    final dark = isDark(context);
    final bg = background(context);
    return (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
  }
}
