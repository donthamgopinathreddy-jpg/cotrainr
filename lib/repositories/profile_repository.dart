import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing user profile data
class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch current user's profile
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', _currentUserId!)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Update profile fields
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', _currentUserId!);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Calculate BMI from height (cm) and weight (kg)
  static double calculateBMI(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightMeters = heightCm / 100.0;
    return weightKg / (heightMeters * heightMeters);
  }

  /// Get BMI status category
  static String getBMIStatus(double bmi) {
    if (bmi == 0.0) return '';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
}
