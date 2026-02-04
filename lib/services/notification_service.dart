import 'package:flutter/material.dart';
import '../pages/notifications/notification_page.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationData> _notifications = [];
  final List<VoidCallback> _listeners = [];

  List<NotificationData> get notifications => List.unmodifiable(_notifications);

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void addNotification(NotificationData notification) {
    _notifications.insert(0, notification); // Add to top
    _notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final notification = _notifications[index];
      final updatedNotification = NotificationData(
        id: notification.id,
        type: notification.type,
        userName: notification.userName,
        title: notification.title,
        message: notification.message,
        time: notification.time,
        hasUnread: false,
        hasImage: notification.hasImage,
        canFollow: notification.canFollow,
        meetingId: notification.meetingId,
        userAvatarUrl: notification.userAvatarUrl,
      );
      _notifications[index] = updatedNotification;
      _notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].hasUnread) {
        final notification = _notifications[i];
        _notifications[i] = NotificationData(
          id: notification.id,
          type: notification.type,
          userName: notification.userName,
          title: notification.title,
          message: notification.message,
          time: notification.time,
          hasUnread: false,
          hasImage: notification.hasImage,
          canFollow: notification.canFollow,
          meetingId: notification.meetingId,
          userAvatarUrl: notification.userAvatarUrl,
        );
      }
    }
    _notifyListeners();
  }

  int get unreadCount => _notifications.where((n) => n.hasUnread).length;

  void clear() {
    _notifications.clear();
    _notifyListeners();
  }

  /// Creates a streak milestone notification for every 100 days
  /// Call this when a user reaches a streak milestone (100, 200, 300, etc.)
  void addStreakMilestoneNotification(int streakDays) {
    if (streakDays % 100 == 0 && streakDays > 0) {
      final now = DateTime.now();
      addNotification(
        NotificationData(
          id: 'streak_${streakDays}_${now.millisecondsSinceEpoch}',
          type: NotificationType.streakReached,
          title: 'Streak Reached $streakDays Days!',
          message: 'Congratulations! You\'ve maintained your workout streak for $streakDays days. Keep going strong!',
          time: 'Just now',
          hasUnread: true,
        ),
      );
    }
  }
}
