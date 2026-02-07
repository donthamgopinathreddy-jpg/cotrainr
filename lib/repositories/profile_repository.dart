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
      print('ProfileRepository: User not authenticated');
      throw Exception('User not authenticated');
    }

    try {
      print('ProfileRepository: Fetching profile for user: $_currentUserId');
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (response == null) {
        print('ProfileRepository: Profile not found for user: $_currentUserId');
        print('ProfileRepository: This might mean the profile was not created during signup');
      } else {
        print('ProfileRepository: Successfully fetched profile: ${response['username']}');
      }

      return response;
    } catch (e) {
      print('ProfileRepository: Error fetching profile: $e');
      print('ProfileRepository: Error type: ${e.runtimeType}');
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Fetch any user's profile by ID
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, bio, role, created_at')
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Search users by username or full name
  Future<List<Map<String, dynamic>>> searchUsers(String query, {int limit = 20}) async {
    try {
      final searchTerm = query.toLowerCase().trim();
      if (searchTerm.isEmpty) return [];

      final response = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, role')
          .or('username.ilike.%$searchTerm%,full_name.ilike.%$searchTerm%')
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error searching users: $e');
      return [];
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
