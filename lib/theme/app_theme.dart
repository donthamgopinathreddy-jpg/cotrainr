import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'account_hub_theme.dart';
import 'design_tokens.dart';

/// App Theme Configuration
/// Inspired by Apple Fitness+ and Nike Training Club
/// Production-ready with full light/dark theme support
class AppTheme {
  // Theme Modes
  static ThemeMode themeMode = ThemeMode.system;

  // Light Theme - Clean, bright, modern
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF111111),
        brightness: Brightness.light,
        primary: DesignTokens.lightTextPrimary,
        secondary: DesignTokens.lightTextSecondary,
        surface: DesignTokens.lightSurface,
        background: DesignTokens.lightBackground,
        error: DesignTokens.accentRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DesignTokens.lightTextPrimary,
        onBackground: DesignTokens.lightTextPrimary,
        onError: Colors.white,
      ),

      // Typography - Use colorScheme for theme-aware colors
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: DesignTokens.fontSizeH1,
          fontWeight: DesignTokens.fontWeightBold,
          color: null,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: DesignTokens.fontWeightBold,
          color: null,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontSize: DesignTokens.fontSizeH3,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: null,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightRegular,
          color: null,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: DesignTokens.fontSizeBodySmall,
          fontWeight: DesignTokens.fontWeightRegular,
          color: null,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: DesignTokens.fontSizeMeta,
          fontWeight: DesignTokens.fontWeightRegular,
          color: null,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: null,
        ),
      ),

      scaffoldBackgroundColor: DesignTokens.lightBackground,

      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
        color: DesignTokens.lightSurface,
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing8,
        ),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.lightTextPrimary,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: DesignTokens.lightTextPrimary,
          letterSpacing: 0.4,
        ),
        iconTheme: IconThemeData(
          color: DesignTokens.lightTextPrimary,
          size: DesignTokens.iconSizeMedium,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing20,
          vertical: DesignTokens.spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: DesignTokens.borderColorLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(
            color: DesignTokens.accentOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(
            color: DesignTokens.accentRed,
            width: 1,
          ),
        ),
        hintStyle: TextStyle(
          color: DesignTokens.lightTextSecondary,
          fontSize: DesignTokens.fontSizeBody,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing32,
            vertical: DesignTokens.spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          ),
          backgroundColor: DesignTokens.lightTextPrimary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.fontWeightSemiBold,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing32,
            vertical: DesignTokens.spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          ),
          backgroundColor: DesignTokens.accentOrange,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.fontWeightSemiBold,
          ),
        ),
      ),

      iconTheme: IconThemeData(
        color: DesignTokens.lightTextPrimary,
        size: DesignTokens.iconSizeMedium,
      ),

      dividerTheme: DividerThemeData(
        color: DesignTokens.borderColorLight,
        thickness: 1,
        space: 1,
      ),

      switchTheme: AccountHubTheme.switchTheme(isDark: false),
    );
  }

  // Dark Theme - Deep, rich, modern
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // White/grey are intentionally the dark palette's primary/secondary
      // surfaces. Their corresponding foregrounds must therefore be dark;
      // using white here produced white-on-white/low-contrast Material states.
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.darkSurface,
        brightness: Brightness.dark,
        primary: DesignTokens.darkTextPrimary,
        secondary: DesignTokens.darkTextSecondary,
        surface: DesignTokens.darkSurface,
        background: DesignTokens.darkBackground,
        error: DesignTokens.accentRed,
        onPrimary: DesignTokens.darkBackground,
        onSecondary: DesignTokens.darkBackground,
        onSurface: DesignTokens.darkTextPrimary,
        onBackground: DesignTokens.darkTextPrimary,
        onError: Colors.white,
      ),

      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: DesignTokens.fontSizeH1,
          fontWeight: DesignTokens.fontWeightBold,
          color: null,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: DesignTokens.fontWeightBold,
          color: null,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontSize: DesignTokens.fontSizeH3,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: null,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightRegular,
          color: null,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: DesignTokens.fontSizeBodySmall,
          fontWeight: DesignTokens.fontWeightRegular,
          color: null,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: DesignTokens.fontSizeMeta,
          fontWeight: DesignTokens.fontWeightRegular,
          color: null,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: null,
        ),
      ),

      scaffoldBackgroundColor: DesignTokens.darkBackground,

      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
        color: DesignTokens.darkSurface,
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing8,
        ),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.darkTextPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: DesignTokens.fontWeightBold,
          color: DesignTokens.darkTextPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
          color: DesignTokens.darkTextPrimary,
          size: DesignTokens.iconSizeMedium,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing20,
          vertical: DesignTokens.spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(
            color: DesignTokens.accentOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(
            color: DesignTokens.accentRed,
            width: 1,
          ),
        ),
        hintStyle: TextStyle(
          color: DesignTokens.darkTextSecondary,
          fontSize: DesignTokens.fontSizeBody,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing32,
            vertical: DesignTokens.spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          ),
          backgroundColor: Colors.white,
          foregroundColor: DesignTokens.darkBackground,
          textStyle: GoogleFonts.poppins(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.fontWeightSemiBold,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing32,
            vertical: DesignTokens.spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          ),
          backgroundColor: Colors.white,
          foregroundColor: DesignTokens.darkBackground,
          textStyle: GoogleFonts.poppins(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.fontWeightSemiBold,
          ),
        ),
      ),

      iconTheme: IconThemeData(
        color: DesignTokens.darkTextPrimary,
        size: DesignTokens.iconSizeMedium,
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.12),
        thickness: 1,
        space: 1,
      ),

      switchTheme: AccountHubTheme.switchTheme(isDark: true),
    );
  }
}
