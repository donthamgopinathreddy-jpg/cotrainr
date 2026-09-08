import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModePreferenceKey = 'appearance_theme_mode';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

ThemeMode _themeModeFromStoredValue(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String _storedValueForThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return _themeModeFromStoredValue(
      preferences.getString(_themeModePreferenceKey),
    );
  } catch (_) {
    // Appearance is non-critical. Fail safely to the platform preference.
    return ThemeMode.system;
  }
}

Future<void> saveThemeMode(ThemeMode mode) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _themeModePreferenceKey,
      _storedValueForThemeMode(mode),
    );
  } catch (_) {
    // Keep the in-memory selection working even if local persistence fails.
  }
}
