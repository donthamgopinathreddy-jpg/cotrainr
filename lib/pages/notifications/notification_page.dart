import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

enum NotificationType {
  followRequest,
  goalReached,
  following,
  postLike,
  comment,
  achievement,
  message,
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final List<_NotificationData> _notifications = [
    _NotificationData(
      id: '1',
      type: NotificationType.followRequest,
      userName: 'attitude_bablu_28',
      message: 'attitude_bablu_28 + 4 others requested to follow you',
      time: 'Just now',
      hasUnread: true,
      canFollow: true,
    ),
    _NotificationData(
      id: '2',
      type: NotificationType.postLike,
      userName: 'stylin_snazzy',
      message: 'stylin_snazzy, alkaaxyz and 236 others liked your reel',
      time: '2h',
      hasUnread: false,
      hasImage: true,
    ),
    _NotificationData(
      id: '3',
      type: NotificationType.following,
      userName: 'rak_hi5',
      message: 'rak_hi5 started following you',
      time: '1d',
      hasUnread: false,
      canFollow: true,
    ),
    _NotificationData(
      id: '4',
      type: NotificationType.comment,
      userName: 'fitness_coach',
      message: 'fitness_coach commented: "Great form! Keep it up."',
      time: '1d',
      hasUnread: false,
    ),
    _NotificationData(
      id: '5',
      type: NotificationType.goalReached,
      userName: null,
      message: '🎉 Daily steps goal reached! 10,000 steps completed',
      time: '2d',
      hasUnread: true,
    ),
    _NotificationData(
      id: '6',
      type: NotificationType.postLike,
      userName: 'stylin_snazzy',
      message: 'stylin_snazzy, yashwanth_chippada and 174 others liked your reel',
      time: '3d',
      hasUnread: false,
      hasImage: true,
    ),
    _NotificationData(
      id: '7',
      type: NotificationType.achievement,
      userName: null,
      message: '🏆 New achievement unlocked: 7 Day Streak!',
      time: '4d',
      hasUnread: true,
    ),
    _NotificationData(
      id: '8',
      type: NotificationType.following,
      userName: 'gig_glygang',
      message: 'gig_glygang started following you',
      time: '5d',
      hasUnread: false,
      canFollow: true,
    ),
  ];

  _NotificationData? _deletedNotification;
  int? _deletedIndex;

  void _deleteNotification(int index) {
    setState(() {
      _deletedNotification = _notifications[index];
      _deletedIndex = index;
      _notifications.removeAt(index);
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
                _notifications.insert(_deletedIndex!, _deletedNotification!);
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
      body: SafeArea(
        child: Column(
          children: [
            // Orange gradient header
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.stepsGradient,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

class _NotificationData {
  final String id;
  final NotificationType type;
  final String? userName;
  final String message;
  final String time;
  final bool hasUnread;
  final bool hasImage;
  final bool canFollow;

  _NotificationData({
    required this.id,
    required this.type,
    this.userName,
    required this.message,
    required this.time,
    this.hasUnread = false,
    this.hasImage = false,
    this.canFollow = false,
  });
}

class _NotificationTile extends StatelessWidget {
  final _NotificationData notification;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {},
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
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      children: [
                        if (notification.userName != null)
                          TextSpan(
                            text: notification.userName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        if (notification.userName != null && notification.message.isNotEmpty)
                          TextSpan(text: ' ${notification.message}')
                        else
                          TextSpan(text: notification.message),
                      ],
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
