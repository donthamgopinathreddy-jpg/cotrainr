import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

/// Text Styles Helper
/// Ensures all text uses Poppins font consistently
class AppTextStyles {
  // Headings
  static TextStyle h1(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeH1,
      fontWeight: FontWeight.w800,
      color: DesignTokens.textPrimaryOf(context),
      letterSpacing: -0.5,
    );
  }

  static TextStyle h2(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeH2,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimaryOf(context),
      letterSpacing: -0.3,
    );
  }

  static TextStyle h3(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeH3,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimaryOf(context),
      letterSpacing: 0,
    );
  }

  // Body Text
  static TextStyle body(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBody,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textPrimaryOf(context),
    );
  }

  static TextStyle bodyBold(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBody,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimaryOf(context),
    );
  }

  static TextStyle bodySmall(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBodySmall,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textPrimaryOf(context),
    );
  }

  static TextStyle bodySmallBold(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBodySmall,
      fontWeight: FontWeight.w600,
      color: DesignTokens.textPrimaryOf(context),
    );
  }

  // Secondary Text
  static TextStyle secondary(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBodySmall,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textSecondaryOf(context),
    );
  }

  // Meta/Caption Text
  static TextStyle meta(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeMeta,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textSecondaryOf(context),
    );
  }

  static TextStyle caption(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeCaption,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textSecondaryOf(context),
    );
  }

  // Button Text
  static TextStyle button(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBody,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    );
  }

  // Label Text
  static TextStyle label(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: DesignTokens.fontSizeBodySmall,
      fontWeight: FontWeight.w600,
      color: DesignTokens.textPrimaryOf(context),
    );
  }
}
