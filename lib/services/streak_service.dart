import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const String _lastLoginDateKey = 'last_login_date';
  static const String _currentStreakKey = 'current_streak';

  /// Get the current streak count
  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentStreakKey) ?? 0;
  }

  /// Update streak when user logs in
  /// Returns the updated streak count
  static Future<int> updateStreakOnLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final lastLoginDateString = prefs.getString(_lastLoginDateKey);
    final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;

    if (lastLoginDateString == null) {
      // First time login
      await prefs.setString(_lastLoginDateKey, today.toIso8601String());
      await prefs.setInt(_currentStreakKey, 1);
      return 1;
    }

    final lastLoginDate = DateTime.parse(lastLoginDateString);
    final lastLogin = DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);
    
    final daysDifference = today.difference(lastLogin).inDays;

    if (daysDifference == 0) {
      // Already logged in today, don't increment
      return currentStreak;
    } else if (daysDifference == 1) {
      // Consecutive day, increment streak
      final newStreak = currentStreak + 1;
      await prefs.setString(_lastLoginDateKey, today.toIso8601String());
      await prefs.setInt(_currentStreakKey, newStreak);
      return newStreak;
    } else {
      // Gap in login, reset streak to 1
      await prefs.setString(_lastLoginDateKey, today.toIso8601String());
      await prefs.setInt(_currentStreakKey, 1);
      return 1;
    }
  }

  /// Reset streak (for testing or manual reset)
  static Future<void> resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastLoginDateKey);
    await prefs.remove(_currentStreakKey);
  }
}
