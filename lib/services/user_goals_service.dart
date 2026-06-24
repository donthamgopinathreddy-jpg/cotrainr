import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage user goals (steps, water, calories, distance).
class UserGoalsService {
  static final UserGoalsService _instance = UserGoalsService._internal();
  factory UserGoalsService() => _instance;
  UserGoalsService._internal();

  /// Bumped after any goal is saved — home/insights can listen and refresh.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  SupabaseClient get _supabase => Supabase.instance.client;
  static const String _prefsKeySteps = 'user_goal_steps';
  static const String _prefsKeyWater = 'user_goal_water';
  static const String _prefsKeyCalories = 'user_goal_calories';
  static const String _prefsKeyDistance = 'user_goal_distance';

  void _notifyChanged() {
    revision.value++;
  }

  /// Calculate water goal based on weight (in liters)
  static double calculateWaterGoal(double weightKg) {
    final calculated = weightKg * 0.033;
    return (calculated * 4).round() / 4.0;
  }

  Future<int> getStepsGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKeySteps)) {
        return prefs.getInt(_prefsKeySteps)!;
      }

      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_steps'];
        if (goal != null) {
          return (goal as num).toInt();
        }
      }
      return 10000;
    } catch (e) {
      debugPrint('Error getting steps goal: $e');
      return 10000;
    }
  }

  Future<double> getWaterGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKeyWater)) {
        return prefs.getDouble(_prefsKeyWater)!;
      }

      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_water'];
        if (goal != null) {
          return (goal as num).toDouble();
        }
      }
      return 2.5;
    } catch (e) {
      debugPrint('Error getting water goal: $e');
      return 2.5;
    }
  }

  Future<int> getCaloriesGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKeyCalories)) {
        return prefs.getInt(_prefsKeyCalories)!;
      }

      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_calories'];
        if (goal != null) {
          return (goal as num).toInt();
        }
      }
      return 2000;
    } catch (e) {
      debugPrint('Error getting calories goal: $e');
      return 2000;
    }
  }

  Future<double> getDistanceGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKeyDistance)) {
        return prefs.getDouble(_prefsKeyDistance)!;
      }

      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_distance'];
        if (goal != null) {
          return (goal as num).toDouble();
        }
      }
      return 5.0;
    } catch (e) {
      debugPrint('Error getting distance goal: $e');
      return 5.0;
    }
  }

  Future<bool> setStepsGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeySteps, goal);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...user.userMetadata ?? {},
              'goal_steps': goal,
            },
          ),
        );
      }
      _notifyChanged();
      return true;
    } catch (e) {
      debugPrint('Error setting steps goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsKeySteps, goal);
        _notifyChanged();
        return true;
      } catch (e2) {
        debugPrint('Error saving steps goal locally: $e2');
        return false;
      }
    }
  }

  Future<bool> setWaterGoal(double goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyWater, goal);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...user.userMetadata ?? {},
              'goal_water': goal,
            },
          ),
        );
      }
      _notifyChanged();
      return true;
    } catch (e) {
      debugPrint('Error setting water goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefsKeyWater, goal);
        _notifyChanged();
        return true;
      } catch (e2) {
        debugPrint('Error saving water goal locally: $e2');
        return false;
      }
    }
  }

  Future<bool> setCaloriesGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyCalories, goal);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...user.userMetadata ?? {},
              'goal_calories': goal,
            },
          ),
        );
      }
      _notifyChanged();
      return true;
    } catch (e) {
      debugPrint('Error setting calories goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsKeyCalories, goal);
        _notifyChanged();
        return true;
      } catch (e2) {
        debugPrint('Error saving calories goal locally: $e2');
        return false;
      }
    }
  }

  Future<bool> setDistanceGoal(double goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyDistance, goal);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...user.userMetadata ?? {},
              'goal_distance': goal,
            },
          ),
        );
      }
      _notifyChanged();
      return true;
    } catch (e) {
      debugPrint('Error setting distance goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefsKeyDistance, goal);
        _notifyChanged();
        return true;
      } catch (e2) {
        debugPrint('Error saving distance goal locally: $e2');
        return false;
      }
    }
  }

  Future<bool> initializeGoals({
    required double weightKg,
    int? stepsGoal,
    double? waterGoal,
    int? caloriesGoal,
    double? distanceGoal,
  }) async {
    try {
      final calculatedWaterGoal = waterGoal ?? calculateWaterGoal(weightKg);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeySteps, stepsGoal ?? 10000);
      await prefs.setDouble(_prefsKeyWater, calculatedWaterGoal);
      await prefs.setInt(_prefsKeyCalories, caloriesGoal ?? 2000);
      await prefs.setDouble(_prefsKeyDistance, distanceGoal ?? 5.0);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...user.userMetadata ?? {},
              'goal_steps': stepsGoal ?? 10000,
              'goal_water': calculatedWaterGoal,
              'goal_calories': caloriesGoal ?? 2000,
              'goal_distance': distanceGoal ?? 5.0,
            },
          ),
        );
      }
      _notifyChanged();
      return true;
    } catch (e) {
      debugPrint('Error initializing goals: $e');
      return false;
    }
  }
}
