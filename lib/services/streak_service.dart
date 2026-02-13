import 'package:supabase_flutter/supabase_flutter.dart';

/// Streak service: per-user login streak stored in Supabase user_streaks table.
/// Each user has their own streak; new users start at 1.
class StreakService {
  /// Get the current streak count for the logged-in user from Supabase
  static Future<int> getCurrentStreak() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final row = await supabase
          .from('user_streaks')
          .select('current_streak')
          .eq('user_id', userId)
          .maybeSingle();
      return (row?['current_streak'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Update streak when user logs in. Uses Supabase user_streaks table (per-user).
  /// Returns the updated streak count. New users get streak = 1.
  static Future<int> updateStreakOnLogin() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String().split('T')[0];

    try {
      final existing = await supabase
          .from('user_streaks')
          .select('current_streak, last_login_date')
          .eq('user_id', userId)
          .maybeSingle();

      int newStreak;
      if (existing == null) {
        // New user: first login = streak 1
        newStreak = 1;
      } else {
        final lastLoginStr = existing['last_login_date'] as String?;
        final currentStreak = (existing['current_streak'] as num?)?.toInt() ?? 0;
        if (lastLoginStr == null) {
          newStreak = 1;
        } else {
          final lastLogin = DateTime.parse(lastLoginStr);
          final lastLoginDate = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
          final daysDifference = today.difference(lastLoginDate).inDays;

          if (daysDifference == 0) {
            // Already logged in today, don't increment
            return currentStreak;
          } else if (daysDifference == 1) {
            // Consecutive day, increment streak
            newStreak = currentStreak + 1;
          } else {
            // Gap in login, reset streak to 1
            newStreak = 1;
          }
        }
      }

      await supabase.from('user_streaks').upsert(
        {
          'user_id': userId,
          'current_streak': newStreak,
          'last_login_date': todayStr,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      return newStreak;
    } catch (e) {
      print('StreakService error: $e');
      return 0;
    }
  }

  /// Reset streak for the current user (for testing or manual reset)
  static Future<void> resetStreak() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final today = DateTime.now();
      final todayStr = DateTime(today.year, today.month, today.day).toIso8601String().split('T')[0];
      await supabase.from('user_streaks').upsert(
        {
          'user_id': userId,
          'current_streak': 0,
          'last_login_date': todayStr,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
    } catch (_) {}
  }
}
