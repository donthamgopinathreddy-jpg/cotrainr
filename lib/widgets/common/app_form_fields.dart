import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Shared Cotrainr form-field decoration: rounded rectangle (~16dp), not pill.
class AppFormFields {
  AppFormFields._();

  static const double radius = DesignTokens.radiusInput;

  static InputDecoration decoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    String? counterText,
    bool alignLabelWithHint = false,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cs = theme.colorScheme;
    final fill = isLight ? DesignTokens.lightSurface : DesignTokens.darkSurface;
    final enabledBorderColor = isLight
        ? DesignTokens.borderColorLight
        : Colors.white.withValues(alpha: 0.12);
    final hintColor = isLight
        ? DesignTokens.lightTextSecondary
        : DesignTokens.darkTextSecondary;

    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      counterText: counterText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(enabledBorderColor),
      enabledBorder: border(enabledBorderColor),
      focusedBorder: border(DesignTokens.accentOrange, width: 2),
      errorBorder: border(cs.error),
      focusedErrorBorder: border(cs.error, width: 2),
      hintStyle: TextStyle(
        color: hintColor,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: TextStyle(
        color: hintColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
