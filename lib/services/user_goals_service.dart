import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage user goals (steps, water, calories, distance)
class UserGoalsService {
  static final UserGoalsService _instance = UserGoalsService._internal();
  factory UserGoalsService() => _instance;
  UserGoalsService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  static const String _prefsKeySteps = 'user_goal_steps';
  static const String _prefsKeyWater = 'user_goal_water';
  static const String _prefsKeyCalories = 'user_goal_calories';
  static const String _prefsKeyDistance = 'user_goal_distance';

  /// Calculate water goal based on weight (in liters)
  /// Formula: weight_kg * 0.033 liters per kg
  /// This is a standard recommendation for daily water intake
  static double calculateWaterGoal(double weightKg) {
    // Standard formula: 30-35ml per kg of body weight
    // We use 33ml per kg (0.033 liters per kg)
    final calculated = weightKg * 0.033;
    // Round to nearest 0.25L for practical purposes
    return (calculated * 4).round() / 4.0;
  }

  /// Get steps goal (default: 10000)
  Future<int> getStepsGoal() async {
    try {
      // First try to get from Supabase user metadata
      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_steps'];
        if (goal != null) {
          return (goal as num).toInt();
        }
      }

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_prefsKeySteps) ?? 10000;
    } catch (e) {
      print('Error getting steps goal: $e');
      return 10000;
    }
  }

  /// Get water goal (default: 2.5L)
  Future<double> getWaterGoal() async {
    try {
      // First try to get from Supabase user metadata
      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_water'];
        if (goal != null) {
          return (goal as num).toDouble();
        }
      }

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_prefsKeyWater) ?? 2.5;
    } catch (e) {
      print('Error getting water goal: $e');
      return 2.5;
    }
  }

  /// Get calories goal (default: 2000)
  Future<int> getCaloriesGoal() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_calories'];
        if (goal != null) {
          return (goal as num).toInt();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_prefsKeyCalories) ?? 2000;
    } catch (e) {
      print('Error getting calories goal: $e');
      return 2000;
    }
  }

  /// Get distance goal (default: 5.0 km)
  Future<double> getDistanceGoal() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final goal = user.userMetadata?['goal_distance'];
        if (goal != null) {
          return (goal as num).toDouble();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_prefsKeyDistance) ?? 5.0;
    } catch (e) {
      print('Error getting distance goal: $e');
      return 5.0;
    }
  }

  /// Set steps goal
  Future<bool> setStepsGoal(int goal) async {
    try {
      // Save to Supabase user metadata
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

      // Also save to local storage as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeySteps, goal);
      return true;
    } catch (e) {
      print('Error setting steps goal: $e');
      // Fallback to local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsKeySteps, goal);
        return true;
      } catch (e2) {
        print('Error saving to local storage: $e2');
        return false;
      }
    }
  }

  /// Set water goal
  Future<bool> setWaterGoal(double goal) async {
    try {
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyWater, goal);
      return true;
    } catch (e) {
      print('Error setting water goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefsKeyWater, goal);
        return true;
      } catch (e2) {
        print('Error saving to local storage: $e2');
        return false;
      }
    }
  }

  /// Set calories goal
  Future<bool> setCaloriesGoal(int goal) async {
    try {
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyCalories, goal);
      return true;
    } catch (e) {
      print('Error setting calories goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsKeyCalories, goal);
        return true;
      } catch (e2) {
        print('Error saving to local storage: $e2');
        return false;
      }
    }
  }

  /// Set distance goal
  Future<bool> setDistanceGoal(double goal) async {
    try {
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyDistance, goal);
      return true;
    } catch (e) {
      print('Error setting distance goal: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefsKeyDistance, goal);
        return true;
      } catch (e2) {
        print('Error saving to local storage: $e2');
        return false;
      }
    }
  }

  /// Initialize goals during signup (calculate water goal from weight)
  Future<bool> initializeGoals({
    required double weightKg,
    int? stepsGoal,
    double? waterGoal,
    int? caloriesGoal,
    double? distanceGoal,
  }) async {
    try {
      // Calculate water goal if not provided
      final calculatedWaterGoal = waterGoal ?? calculateWaterGoal(weightKg);

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

      // Also save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeySteps, stepsGoal ?? 10000);
      await prefs.setDouble(_prefsKeyWater, calculatedWaterGoal);
      await prefs.setInt(_prefsKeyCalories, caloriesGoal ?? 2000);
      await prefs.setDouble(_prefsKeyDistance, distanceGoal ?? 5.0);

      return true;
    } catch (e) {
      print('Error initializing goals: $e');
      return false;
    }
  }
}
