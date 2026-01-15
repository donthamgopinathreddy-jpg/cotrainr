import 'package:flutter/material.dart';

class AppColors {
  // Base
  static const Color bg = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121A2B);
  static const Color surfaceSoft = Color(0xFF1A2335);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x80FFFFFF);
  static const Color border = Color(0x1AFFFFFF);

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

  static const LinearGradient bmiGradient = LinearGradient(
    colors: [Color(0xFF2BC88A), Color(0xFFB6F7D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
