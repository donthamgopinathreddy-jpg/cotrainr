import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/meeting_storage_service.dart';

enum NotificationType {
  followRequest,
  goalReached,
  following,
  postLike,
  comment,
  achievement,
  message,
  meeting,
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationData> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _notificationService.addListener(_loadNotifications);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadNotifications);
    super.dispose();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = _notificationService.notifications;
    });
  }

  NotificationData? _deletedNotification;
  int? _deletedIndex;

  void _deleteNotification(int index) {
    setState(() {
      _deletedNotification = _notifications[index];
      _deletedIndex = index;
      _notificationService.removeNotification(_notifications[index].id);
      _notifications = _notificationService.notifications;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            if (_deletedNotification != null && _deletedIndex != null) {
              setState(() {
                _notificationService.addNotification(_deletedNotification!);
                _notifications = _notificationService.notifications;
                _deletedNotification = null;
                _deletedIndex = null;
              });
            }
          },
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Clear deleted notification after snackbar duration
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _deletedNotification = null;
          _deletedIndex = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: cs.onSurface,
            size: 20,
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 72,
                  color: cs.surfaceContainerHighest,
                ),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _NotificationTile(
                    notification: notification,
                    onLongPress: () => _deleteNotification(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationData {
  final String id;
  final NotificationType type;
  final String? userName;
  final String message;
  final String time;
  final bool hasUnread;
  final bool hasImage;
  final bool canFollow;
  final String? meetingId;

  NotificationData({
    required this.id,
    required this.type,
    this.userName,
    required this.message,
    required this.time,
    this.hasUnread = false,
    this.hasImage = false,
    this.canFollow = false,
    this.meetingId,
  });
}

class _NotificationTile extends StatelessWidget {
  final NotificationData notification;
  final VoidCallback onLongPress;

  const _NotificationTile({
    required this.notification,
    required this.onLongPress,
  });

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.followRequest:
        return Icons.person_add_rounded;
      case NotificationType.goalReached:
        return Icons.emoji_events_rounded;
      case NotificationType.following:
        return Icons.people_rounded;
      case NotificationType.postLike:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.comment_rounded;
      case NotificationType.achievement:
        return Icons.star_rounded;
      case NotificationType.message:
        return Icons.chat_bubble_rounded;
      case NotificationType.meeting:
        return Icons.video_call_rounded;
    }
  }

  LinearGradient _getGradientForType(NotificationType type) {
    switch (type) {
      case NotificationType.goalReached:
        return AppColors.stepsGradient;
      case NotificationType.following:
      case NotificationType.followRequest:
        return AppColors.waterGradient;
      case NotificationType.postLike:
        return LinearGradient(
          colors: [AppColors.red, AppColors.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case NotificationType.comment:
        return AppColors.distanceGradient;
      case NotificationType.achievement:
        return LinearGradient(
          colors: [AppColors.orange, AppColors.yellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case NotificationType.message:
        return AppColors.waterGradient;
      case NotificationType.meeting:
        return const LinearGradient(
          colors: [AppColors.purple, Color(0xFFB38CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        if (notification.type == NotificationType.meeting && notification.meetingId != null) {
          // Navigate to meeting room if it's a meeting notification
          final meetingStorage = MeetingStorageService();
          final meeting = meetingStorage.getMeetingById(notification.meetingId!);
          if (meeting != null) {
            context.push('/video/room/${meeting.shareKey}');
          }
        }
      },
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar/Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _getGradientForType(notification.type),
                shape: BoxShape.circle,
              ),
              child: notification.userName != null
                  ? Center(
                      child: Text(
                        notification.userName!.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      _getIconForType(notification.type),
                      color: Colors.white,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            // Message and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.orange, AppColors.yellow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        children: [
                          if (notification.userName != null)
                            TextSpan(
                              text: notification.userName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          if (notification.userName != null && notification.message.isNotEmpty)
                            TextSpan(text: ' ${notification.message}')
                          else
                            TextSpan(text: notification.message),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Follow button or image/unread dot
            if (notification.canFollow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.stepsGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            else if (notification.hasImage)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            else if (notification.hasUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
