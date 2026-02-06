import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
