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
      // Explicitly select columns to avoid issues with missing columns
      final response = await _supabase
          .from('profiles')
          .select('id, role, email, username, username_lower, full_name, avatar_url, cover_url, bio, phone, date_of_birth, gender, height_cm, weight_kg, created_at, updated_at')
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (response == null) {
        print('ProfileRepository: Profile not found for user: $_currentUserId');
        print('ProfileRepository: This might mean the profile was not created during signup');
      } else {
        print('ProfileRepository: Successfully fetched profile: ${response['username']}');
        print('ProfileRepository: Profile fields - full_name: ${response['full_name']}, avatar_url: ${response['avatar_url']}, cover_url: ${response['cover_url']}');
        print('ProfileRepository: Profile fields - height_cm: ${response['height_cm']}, weight_kg: ${response['weight_kg']}');
        print('ProfileRepository: Profile fields - email: ${response['email']}, phone: ${response['phone']}, gender: ${response['gender']}, dob: ${response['date_of_birth']}');
        print('ProfileRepository: Full profile data: $response');
      }

      return response;
    } catch (e) {
      print('ProfileRepository: Error fetching profile: $e');
      print('ProfileRepository: Error type: ${e.runtimeType}');
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Fetch any user's profile by ID
  /// Includes followers_count, following_count when migration 20250213_follower_counts_on_profiles has run
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, bio, role, created_at, followers_count, following_count')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      // Fallback if followers_count/following_count columns don't exist (migration not run)
      final msg = e.toString().toLowerCase();
      if (msg.contains('followers_count') || msg.contains('following_count') || msg.contains('does not exist')) {
        try {
          return await _supabase
              .from('profiles')
              .select('id, username, full_name, avatar_url, bio, role, created_at')
              .eq('id', userId)
              .maybeSingle();
        } catch (e2) {
          print('Error fetching user profile: $e2');
          return null;
        }
      }
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
      print('ProfileRepository: Updating profile for user: $_currentUserId');
      print('ProfileRepository: Updates: $updates');
      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', _currentUserId!)
          .select()
          .single();
      print('ProfileRepository: Profile updated successfully: $response');
    } catch (e) {
      print('ProfileRepository: Error updating profile: $e');
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
