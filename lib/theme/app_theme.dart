import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        seedColor: DesignTokens.accentOrange,
        brightness: Brightness.light,
        primary: DesignTokens.accentOrange,
        secondary: DesignTokens.accentAmber,
        surface: DesignTokens.lightSurface,
        background: DesignTokens.lightBackground,
        error: DesignTokens.accentRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DesignTokens.lightTextPrimary,
        onBackground: DesignTokens.lightTextPrimary,
        onError: Colors.white,
      ),
      
      // Typography
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: DesignTokens.fontSizeH1,
          fontWeight: DesignTokens.fontWeightBold,
          color: DesignTokens.lightTextPrimary,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: DesignTokens.fontWeightBold,
          color: DesignTokens.lightTextPrimary,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontSize: DesignTokens.fontSizeH3,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: DesignTokens.lightTextPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightRegular,
          color: DesignTokens.lightTextPrimary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: DesignTokens.fontSizeBodySmall,
          fontWeight: DesignTokens.fontWeightRegular,
          color: DesignTokens.lightTextPrimary,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: DesignTokens.fontSizeMeta,
          fontWeight: DesignTokens.fontWeightRegular,
          color: DesignTokens.lightTextSecondary,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: DesignTokens.lightTextPrimary,
        ),
      ),
      
      // Scaffold
      scaffoldBackgroundColor: DesignTokens.lightBackground,
      
      // Cards - Rounded, soft shadows
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
      
      // App Bar - Clean, minimal
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.lightTextPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: DesignTokens.fontWeightBold,
          color: DesignTokens.lightTextPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
          color: DesignTokens.lightTextPrimary,
          size: DesignTokens.iconSizeMedium,
        ),
      ),
      
      // Input Fields - Rounded, soft
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing20,
          vertical: DesignTokens.spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: BorderSide(
            color: DesignTokens.borderColorLight.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: const BorderSide(
            color: DesignTokens.accentOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
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
      
      // Buttons - Rounded, gradient-ready
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
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: DesignTokens.lightTextPrimary,
        size: DesignTokens.iconSizeMedium,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: DesignTokens.borderColorLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Dark Theme - Deep, rich, modern
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.accentOrange,
        brightness: Brightness.dark,
        primary: DesignTokens.accentOrange,
        secondary: DesignTokens.accentAmber,
        surface: DesignTokens.darkSurface,
        background: DesignTokens.darkBackground,
        error: DesignTokens.accentRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DesignTokens.darkTextPrimary,
        onBackground: DesignTokens.darkTextPrimary,
        onError: Colors.white,
      ),
      
      // Typography
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: DesignTokens.fontSizeH1,
          fontWeight: DesignTokens.fontWeightBold,
          color: DesignTokens.darkTextPrimary,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: DesignTokens.fontWeightBold,
          color: DesignTokens.darkTextPrimary,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontSize: DesignTokens.fontSizeH3,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: DesignTokens.darkTextPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightRegular,
          color: DesignTokens.darkTextPrimary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: DesignTokens.fontSizeBodySmall,
          fontWeight: DesignTokens.fontWeightRegular,
          color: DesignTokens.darkTextPrimary,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: DesignTokens.fontSizeMeta,
          fontWeight: DesignTokens.fontWeightRegular,
          color: DesignTokens.darkTextSecondary,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: DesignTokens.fontSizeBody,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: DesignTokens.darkTextPrimary,
        ),
      ),
      
      // Scaffold
      scaffoldBackgroundColor: DesignTokens.darkBackground,
      
      // Cards - Rounded, soft shadows
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
      
      // App Bar - Clean, minimal
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
      
      // Input Fields - Rounded, soft
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing20,
          vertical: DesignTokens.spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: BorderSide(
            color: DesignTokens.borderColorLight.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: const BorderSide(
            color: DesignTokens.accentOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
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
      
      // Buttons - Rounded, gradient-ready
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
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: DesignTokens.darkTextPrimary,
        size: DesignTokens.iconSizeMedium,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: DesignTokens.borderColorLight,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
