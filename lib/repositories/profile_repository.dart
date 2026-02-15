import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing user profile data
class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch current user's profile (RPC get_my_profile)
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    if (_currentUserId == null) {
      print('ProfileRepository: User not authenticated');
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase.rpc('get_my_profile');
      final list = (response as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      print('ProfileRepository: Error fetching profile: $e');
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Fetch any user's profile by ID (RPC get_my_profile for self, get_public_profile for others)
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      if (userId == _currentUserId) {
        final list = (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
        return list.isNotEmpty ? list.first : null;
      }
      final list = (await _supabase.rpc('get_public_profile', params: {'p_user_id': userId}) as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Search users by username or full name (RPC search_public_profiles)
  Future<List<Map<String, dynamic>>> searchUsers(String query, {int limit = 20}) async {
    try {
      final searchTerm = query.trim();
      if (searchTerm.isEmpty) return [];

      final response = await _supabase.rpc('search_public_profiles', params: {'p_query': searchTerm, 'p_limit': limit});
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Fetch notification preferences (RPC get_my_profile)
  Future<Map<String, bool>> fetchNotificationPreferences() async {
    if (_currentUserId == null) {
      return {
        'push': true,
        'community': true,
        'reminders': true,
        'achievements': true,
      };
    }
    try {
      final list = (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
      final response = list.isNotEmpty ? list.first : null;
      if (response == null) return _defaultNotificationPrefs;
      return {
        'push': response['notification_push'] as bool? ?? true,
        'community': response['notification_community'] as bool? ?? true,
        'reminders': response['notification_reminders'] as bool? ?? true,
        'achievements': response['notification_achievements'] as bool? ?? true,
      };
    } catch (e) {
      return _defaultNotificationPrefs;
    }
  }

  static const _defaultNotificationPrefs = {
    'push': true,
    'community': true,
    'reminders': true,
    'achievements': true,
  };

  /// Update notification preferences
  Future<void> updateNotificationPreferences({
    required bool push,
    required bool community,
    required bool reminders,
    required bool achievements,
  }) async {
    if (_currentUserId == null) return;
    try {
      await _supabase.from('profiles').update({
        'notification_push': push,
        'notification_community': community,
        'notification_reminders': reminders,
        'notification_achievements': achievements,
      }).eq('id', _currentUserId!);
    } catch (e) {
      print('Error updating notification preferences: $e');
      rethrow;
    }
  }

  /// Update profile fields (uses update_my_profile RPC for robust handling of new users)
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      print('ProfileRepository: Updating profile for user: $_currentUserId');
      print('ProfileRepository: Updates: $updates');
      // Use RPC to handle missing profile (new users) and ensure avatar/cover save works
      await _supabase.rpc('update_my_profile', params: {'p_updates': updates});
      final response = await fetchMyProfile();
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
