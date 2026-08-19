import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Video Sessions-only visuals. Does not change global orange form theming.
abstract final class VideoSessionUi {
  static const radius = 14.0;
  static const avatarSize = 44.0;
  static const duration = Duration(milliseconds: 200);

  static Color pageBg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF0A0A0A) : DesignTokens.lightPageBackground;
  }

  static Color cardBg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF161616) : Colors.white;
  }

  static Color border(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E8EA);
  }

  static Color secondaryText(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
  }

  static BoxDecoration cardBox(BuildContext context, {bool selected = false}) {
    return BoxDecoration(
      color: selected
          ? DesignTokens.videoSessionsAccent.withValues(alpha: 0.10)
          : cardBg(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected
            ? DesignTokens.videoSessionsAccent.withValues(alpha: 0.55)
            : border(context),
      ),
    );
  }

  static TextStyle sectionLabel(BuildContext context) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
    );
  }

  static InputDecoration fieldDecoration(
    BuildContext context, {
    String? hintText,
    int? maxLines,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: cardBg(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(
          color: DesignTokens.videoSessionsAccent,
          width: 1.6,
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }

  static ThemeData pickerTheme(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: DesignTokens.videoSessionsAccent,
        onPrimary: Colors.white,
        surface: dark ? const Color(0xFF1A1A1A) : Colors.white,
        onSurface: dark ? Colors.white : DesignTokens.lightTextPrimary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
        headerForegroundColor: dark ? Colors.white : DesignTokens.lightTextPrimary,
        todayForegroundColor:
            const WidgetStatePropertyAll(DesignTokens.videoSessionsAccent),
        todayBackgroundColor: WidgetStatePropertyAll(
          DesignTokens.videoSessionsAccent.withValues(alpha: 0.14),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
        hourMinuteColor: DesignTokens.videoSessionsAccent.withValues(alpha: 0.16),
        hourMinuteTextColor: DesignTokens.videoSessionsAccent,
        dialHandColor: DesignTokens.videoSessionsAccent,
        dayPeriodColor: DesignTokens.videoSessionsAccent.withValues(alpha: 0.16),
      ),
    );
  }

  static Duration motion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
  }
}
