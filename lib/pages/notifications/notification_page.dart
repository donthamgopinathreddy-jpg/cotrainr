import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  questCompleted,
  stepsGoalAchieved,
  streakReached,
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationData> _notifications = [];
  final Map<String, NotificationData> _deletedNotifications = {};
  final Map<String, DateTime> _deletedTimestamps = {};

  @override
  void initState() {
    super.initState();
    _initializeSampleNotifications();
    _loadNotifications();
    _notificationService.addListener(_loadNotifications);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadNotifications);
    super.dispose();
  }

  void _initializeSampleNotifications() {
    if (_notificationService.notifications.isEmpty) {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      
      _notificationService.addNotification(
        NotificationData(
          id: 'steps_goal_$timestamp',
          type: NotificationType.stepsGoalAchieved,
          title: 'Daily Steps Goal Achieved!',
          message: "Congratulations! You've reached your 10,000 steps goal for today. Keep up the great work!",
          time: '2h ago',
          hasUnread: true,
        ),
      );

      _notificationService.addNotification(
        NotificationData(
          id: 'post_like_${timestamp + 1}',
          type: NotificationType.postLike,
          userName: 'Sarah Mitchell',
          title: 'Sarah Mitchell',
          message: 'liked your post',
          time: '3h ago',
          hasUnread: true,
          userAvatarUrl: '',
        ),
      );

      _notificationService.addNotification(
        NotificationData(
          id: 'quest_completed_${timestamp + 2}',
          type: NotificationType.questCompleted,
          title: 'Quest Completed!',
          message: "You completed 'Drink 8 Glasses of Water' and earned 30 XP!",
          time: '5h ago',
          hasUnread: true,
        ),
      );

      _notificationService.addNotification(
        NotificationData(
          id: 'follow_${timestamp + 3}',
          type: NotificationType.following,
          userName: 'John Smith',
          title: 'John Smith',
          message: 'started following you',
          time: '1d ago',
          hasUnread: true,
          userAvatarUrl: '',
          canFollow: true,
        ),
      );

      _notificationService.addNotification(
        NotificationData(
          id: 'comment_${timestamp + 4}',
          type: NotificationType.comment,
          userName: 'Mike Johnson',
          title: 'Mike Johnson',
          message: 'commented on your post',
          time: '1d ago',
          hasUnread: true,
          userAvatarUrl: '',
        ),
      );

      _notificationService.addNotification(
        NotificationData(
          id: 'streak_100_${timestamp + 5}',
          type: NotificationType.streakReached,
          title: 'Streak Reached 100 Days!',
          message: 'Congratulations! You\'ve maintained your workout streak for 100 days. Keep going strong!',
          time: '2d ago',
          hasUnread: true,
        ),
      );
    }
  }

  void _loadNotifications() {
    if (mounted) {
      setState(() {
        _notifications = _notificationService.notifications;
      });
    }
  }

  void _deleteNotification(int index) {
    if (index < 0 || index >= _notifications.length) return;
    
    final notification = _notifications[index];
    HapticFeedback.mediumImpact();
    
    if (mounted) {
      setState(() {
        _deletedNotifications[notification.id] = notification;
        _deletedTimestamps[notification.id] = DateTime.now();
        _notificationService.removeNotification(notification.id);
        _notifications = _notificationService.notifications;
      });
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _deletedNotifications.containsKey(notification.id)) {
        setState(() {
          _deletedNotifications.remove(notification.id);
          _deletedTimestamps.remove(notification.id);
        });
      }
    });
  }

  void _undoDelete(String notificationId) {
    if (!_deletedNotifications.containsKey(notificationId)) return;
    
    HapticFeedback.lightImpact();
    
    if (mounted) {
      setState(() {
        final notification = _deletedNotifications[notificationId]!;
        _notificationService.addNotification(notification);
        _notifications = _notificationService.notifications;
        _deletedNotifications.remove(notificationId);
        _deletedTimestamps.remove(notificationId);
      });
    }
  }

  void _handleFollowAction(BuildContext context, NotificationData notification) {
    HapticFeedback.mediumImpact();
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You followed ${notification.userName ?? 'user'}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    
    if (mounted) {
      setState(() {
        final updatedNotification = NotificationData(
          id: notification.id,
          type: notification.type,
          userName: notification.userName,
          title: notification.title,
          message: notification.message,
          time: notification.time,
          hasUnread: notification.hasUnread,
          hasImage: notification.hasImage,
          canFollow: false,
          meetingId: notification.meetingId,
          userAvatarUrl: notification.userAvatarUrl,
        );
        _notificationService.removeNotification(notification.id);
        _notificationService.addNotification(updatedNotification);
        _loadNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unreadCount = _notifications.where((n) => n.hasUnread).length;
    final totalCount = _notifications.length + _deletedNotifications.length;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            icon: ShaderMask(
              shaderCallback: (bounds) => AppColors.stepsGradient.createShader(bounds),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        leadingWidth: 48,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.stepsGradient.createShader(bounds),
              child: const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$unreadCount unread ${unreadCount == 1 ? 'message' : 'messages'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                _loadNotifications();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: AppColors.orange,
              child: totalCount == 0
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: totalCount,
                      itemBuilder: (context, index) {
                        if (index < _deletedNotifications.length) {
                          final entries = _deletedNotifications.entries.toList();
                          if (index < entries.length) {
                            final entry = entries[index];
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.scale(
                                    scale: 0.95 + (0.05 * value),
                                    child: child,
                                  ),
                                );
                              },
                              child: _DeletedNotificationCard(
                                notification: entry.value,
                                onUndo: () => _undoDelete(entry.key),
                              ),
                            );
                          }
                        }
                        final notificationIndex = index - _deletedNotifications.length;
                        if (notificationIndex < 0 || notificationIndex >= _notifications.length) {
                          return const SizedBox.shrink();
                        }
                        final notification = _notifications[notificationIndex];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 200 + (notificationIndex * 30)),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Dismissible(
                            key: Key(notification.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: cs.error,
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            onDismissed: (direction) {
                              _deleteNotification(notificationIndex);
                            },
                            child: _NotificationItem(
                              notification: notification,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                if (notification.type == NotificationType.meeting && notification.meetingId != null) {
                                  final meetingStorage = MeetingStorageService();
                                  final meeting = meetingStorage.getMeetingById(notification.meetingId!);
                                  if (meeting != null) {
                                    context.push('/video/room/${meeting.shareKey}');
                                  }
                                }
                                if (notification.hasUnread) {
                                  _notificationService.markAsRead(notification.id);
                                  _loadNotifications();
                                }
                              },
                              onFollow: notification.type == NotificationType.following && notification.canFollow
                                  ? () => _handleFollowAction(context, notification)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
  final String title;
  final String message;
  final String time;
  final bool hasUnread;
  final bool hasImage;
  final bool canFollow;
  final String? meetingId;
  final String? userAvatarUrl;

  NotificationData({
    required this.id,
    required this.type,
    this.userName,
    required this.title,
    required this.message,
    required this.time,
    this.hasUnread = false,
    this.hasImage = false,
    this.canFollow = false,
    this.meetingId,
    this.userAvatarUrl,
  });
}

class _DeletedNotificationCard extends StatelessWidget {
  final NotificationData notification;
  final VoidCallback onUndo;

  const _DeletedNotificationCard({
    required this.notification,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.delete_outline_rounded,
            color: cs.error,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notification deleted',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Undo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatefulWidget {
  final NotificationData notification;
  final VoidCallback onTap;
  final VoidCallback? onFollow;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    this.onFollow,
  });

  @override
  State<_NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<_NotificationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.followRequest:
        return Icons.person_add_rounded;
      case NotificationType.goalReached:
      case NotificationType.stepsGoalAchieved:
        return Icons.star_rounded;
      case NotificationType.following:
        return Icons.people_rounded;
      case NotificationType.postLike:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.comment_rounded;
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.message:
        return Icons.chat_bubble_rounded;
      case NotificationType.meeting:
        return Icons.video_call_rounded;
      case NotificationType.questCompleted:
        return Icons.check_circle_rounded;
      case NotificationType.streakReached:
        return Icons.local_fire_department_rounded;
    }
  }

  Color _getIconBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.stepsGoalAchieved:
      case NotificationType.goalReached:
      case NotificationType.achievement:
        return AppColors.orange;
      case NotificationType.postLike:
      case NotificationType.following:
      case NotificationType.comment:
        return Colors.grey.shade300;
      case NotificationType.questCompleted:
        return const Color(0xFFE8D5FF);
      case NotificationType.streakReached:
        return const Color(0xFFFF6B35);
      default:
        return AppColors.orange;
    }
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.questCompleted:
        return AppColors.purple;
      default:
        return Colors.white;
    }
  }

  Widget _buildAvatar(BuildContext context, NotificationType type) {
    final cs = Theme.of(context).colorScheme;
    
    final shouldShowAvatar = widget.notification.userName != null && 
                            (type == NotificationType.postLike || 
                             type == NotificationType.following || 
                             type == NotificationType.comment);
    
    if (shouldShowAvatar) {
      if (widget.notification.userAvatarUrl != null && widget.notification.userAvatarUrl!.isNotEmpty) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
            child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.notification.userAvatarUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 44,
                height: 44,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.person_rounded,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 44,
                height: 44,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.person_rounded,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      } else {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.person_rounded,
            color: cs.onSurfaceVariant,
            size: 22,
          ),
        );
      }
    } else {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _getIconBackgroundColor(type),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getIconForType(type),
          color: _getIconColor(type),
          size: 22,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showFollowButton = widget.notification.type == NotificationType.following && 
                             widget.notification.canFollow && 
                             widget.onFollow != null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) {
            _animationController.forward();
          },
          onTapUp: (_) {
            _animationController.reverse();
          },
          onTapCancel: () {
            _animationController.reverse();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.notification.hasUnread 
                  ? (isDark 
                      ? AppColors.orange.withValues(alpha: 0.08)
                      : AppColors.orange.withValues(alpha: 0.05))
                  : Colors.transparent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread indicator dot
                if (widget.notification.hasUnread) ...[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 12),
                    decoration: const BoxDecoration(
                      gradient: AppColors.stepsGradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                ] else
                  const SizedBox(width: 20),
                // Avatar/Icon
                _buildAvatar(context, widget.notification.type),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.notification.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.notification.time,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Follow button - smaller and simpler
                if (showFollowButton) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onFollow,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.stepsGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Follow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
