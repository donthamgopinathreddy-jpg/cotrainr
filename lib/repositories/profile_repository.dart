import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing user profile data
class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    if (_currentUserId == null) throw Exception('User not authenticated');
    try {
      final response = await _supabase.rpc('get_my_profile');
      final list = (response as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      print('ProfileRepository: Error fetching profile: $e');
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      if (userId == _currentUserId) {
        final list = (await _supabase.rpc('get_my_profile') as List)
            .cast<Map<String, dynamic>>();
        return list.isNotEmpty ? list.first : null;
      }
      final list = (await _supabase.rpc(
        'get_public_profile',
        params: {'p_user_id': userId},
      ) as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query,
      {int limit = 20}) async {
    try {
      final searchTerm = query.trim();
      if (searchTerm.isEmpty) return [];
      final response = await _supabase.rpc('search_public_profiles', params: {
        'p_query': searchTerm,
        'p_limit': limit,
      });
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<Map<String, bool>> fetchNotificationPreferences() async {
    if (_currentUserId == null) return _defaultNotificationPrefs;
    try {
      final list = (await _supabase.rpc('get_my_profile') as List)
          .cast<Map<String, dynamic>>();
      final response = list.isNotEmpty ? list.first : null;
      if (response == null) return _defaultNotificationPrefs;
      return {
        'push': response['notification_push'] as bool? ?? true,
        'community': response['notification_community'] as bool? ?? true,
        'reminders': response['notification_reminders'] as bool? ?? true,
        'achievements': response['notification_achievements'] as bool? ?? true,
        'videoSessions': response['notification_video_sessions'] as bool? ?? true,
        'videoSessionReminders':
            response['notification_video_session_reminders'] as bool? ?? true,
        'messages': response['notification_messages'] as bool? ?? true,
      };
    } catch (_) {
      return _defaultNotificationPrefs;
    }
  }

  static const _defaultNotificationPrefs = {
    'push': true,
    'community': true,
    'reminders': true,
    'achievements': true,
    'videoSessions': true,
    'videoSessionReminders': true,
    'messages': true,
  };

  /// Persist only the current user's notification preferences through the
  /// server-authoritative RPC. Direct profile UPDATE is intentionally revoked.
  Future<void> updateNotificationPreferences({
    required bool push,
    required bool community,
    required bool reminders,
    required bool achievements,
    bool? videoSessions,
    bool? videoSessionReminders,
    bool? messages,
  }) async {
    if (_currentUserId == null) return;
    try {
      await _supabase.rpc('update_my_notification_preferences', params: {
        'p_push': push,
        'p_community': community,
        'p_reminders': reminders,
        'p_achievements': achievements,
        'p_video_sessions': videoSessions,
        'p_video_session_reminders': videoSessionReminders,
        'p_messages': messages,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating notification preferences: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUserId == null) throw Exception('User not authenticated');
    try {
      await _supabase.rpc('update_my_profile', params: {'p_updates': updates});
      await fetchMyProfile();
      if (kDebugMode) debugPrint('ProfileRepository: Profile updated');
    } catch (e) {
      if (kDebugMode) debugPrint('ProfileRepository: Error updating profile');
      throw Exception('Failed to update profile: $e');
    }
  }

  static double calculateBMI(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightMeters = heightCm / 100.0;
    return weightKg / (heightMeters * heightMeters);
  }

  static String getBMIStatus(double bmi) {
    if (bmi == 0.0) return '';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
}
