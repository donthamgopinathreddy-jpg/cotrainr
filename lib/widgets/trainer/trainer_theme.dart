import 'package:flutter/material.dart';

/// Shared trainer / provider accent (matches My Clients tab).
abstract final class TrainerTheme {
  static const accent = Color(0xFF3ED598);
  static const accentSoft = Color(0xFF4DA8D4);

  static const gradient = LinearGradient(
    colors: [accent, accentSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
