import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../config/feature_flags.dart';

/// Repository for managing notifications from Supabase
class NotificationsRepository {
  final SupabaseClient _supabase;

  NotificationsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all notifications for current user
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    if (_currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select('''
            id,
            type,
            title,
            body,
            data,
            read,
            read_at,
            created_at
          ''')
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({
            'read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', _currentUserId!)
          .eq('read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({
            'read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Fetch unread count filtered by notification preferences
  Future<int> fetchUnreadCount({
    bool community = true,
    bool reminders = true,
    bool achievements = true,
  }) async {
    if (_currentUserId == null) return 0;
    try {
      final response = await _supabase
          .from('notifications')
          .select('id, type')
          .eq('user_id', _currentUserId!)
          .eq('read', false);
      final list = (response as List).cast<Map<String, dynamic>>();
      var communityFiltered = 0;
      var questFiltered = 0;
      final count = list.where((n) {
        final type = (n['type'] as String?)?.toLowerCase() ?? '';
        if (type == 'like' ||
            type == 'following' ||
            type == 'follow' ||
            type == 'comment') {
          final show = community && FeatureFlags.communityNotificationsActive;
          if (!show) communityFiltered++;
          return show;
        }
        if (type == 'reminder') return reminders;
        if (type == 'quest' || type == 'achievement') {
          final show = achievements && FeatureFlags.questNotificationsActive;
          if (!show) questFiltered++;
          return show;
        }
        if (type == 'streak' ||
            type == 'goal_reached' ||
            type == 'steps_goal') {
          return achievements;
        }
        return true; // meeting, message, etc.
      }).length;
      if (communityFiltered > 0) {
        FeatureFlags.logBlockedOnce(
          'notif_community',
          'CoCircle disabled: excluding $communityFiltered community notification(s) from count',
        );
      }
      if (questFiltered > 0) {
        FeatureFlags.logBlockedOnce(
          'notif_quest',
          'Quest disabled: excluding $questFiltered quest notification(s) from count',
        );
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  static const videoSessionNotificationTypes = [
    'video_session_created',
    'video_session_rescheduled',
    'video_session_cancelled',
    'video_session_reminder_5m',
    'video_session_starting',
  ];

  static bool isVideoSessionType(String? type) {
    final t = type?.toLowerCase() ?? '';
    return t.startsWith('video_session_');
  }

  Future<int> fetchUnreadVideoSessionCount() async {
    if (_currentUserId == null) return 0;
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('read', false)
          .inFilter('type', videoSessionNotificationTypes);
      return (response as List).length;
    } catch (e) {
      print('Error fetching unread video session notifications: $e');
      return 0;
    }
  }

  Future<void> markVideoSessionNotificationsRead({String? sessionId}) async {
    if (_currentUserId == null) return;
    try {
      var query = _supabase
          .from('notifications')
          .update({
            'read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', _currentUserId!)
          .eq('read', false)
          .inFilter('type', videoSessionNotificationTypes);
      if (sessionId != null && sessionId.isNotEmpty) {
        query = query.contains('data', {'video_session_id': sessionId});
      }
      await query;
    } catch (e) {
      print('Error marking video session notifications read: $e');
    }
  }

  /// Fetch post preview (content + first media URL) for notification display
  Future<Map<String, dynamic>?> fetchPostPreview(String postId) async {
    if (!FeatureFlags.enableCoCircle) return null;
    try {
      final postResponse = await _supabase
          .from('posts')
          .select('id, content')
          .eq('id', postId)
          .maybeSingle();
      if (postResponse == null) return null;

      final mediaResponse = await _supabase
          .from('post_media')
          .select('media_url')
          .eq('post_id', postId)
          .order('order_index')
          .limit(1);
      final mediaList = (mediaResponse as List).cast<Map<String, dynamic>>();
      final firstMediaUrl = mediaList.isNotEmpty ? mediaList[0]['media_url'] as String? : null;

      return {
        'content': postResponse['content'] as String? ?? '',
        'media_url': firstMediaUrl,
      };
    } catch (e) {
      return null;
    }
  }

  /// Format timestamp to relative time (e.g., "2h ago", "1d ago")
  static String formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
