import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/meeting_storage_service.dart';
import '../../repositories/notifications_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final NotificationsRepository _notificationsRepo = NotificationsRepository();
  List<NotificationData> _notifications = [];
  final Map<String, NotificationData> _deletedNotifications = {};
  final Map<String, DateTime> _deletedTimestamps = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRealNotifications();
    _notificationService.addListener(_loadNotifications);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadNotifications);
    super.dispose();
  }

  Future<void> _loadRealNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final notificationsData = await _notificationsRepo.fetchNotifications();
      if (!mounted) return;

      final notifications = <NotificationData>[];
      
      for (final notif in notificationsData) {
        // Map database type to NotificationType enum
        final type = _mapNotificationType(notif['type'] as String);
        
        // Parse data JSONB for additional info
        final data = notif['data'] as Map<String, dynamic>?;
        final actorId = data?['actor_id'] as String?;
        final actorProfile = actorId != null ? await _getActorProfile(actorId) : null;
        
        // Format timestamp
        final createdAt = DateTime.parse(notif['created_at'] as String);
        final timeStr = NotificationsRepository.formatRelativeTime(createdAt);
        
        notifications.add(NotificationData(
          id: notif['id'] as String,
          type: type,
          userName: actorProfile?['full_name'] as String? ?? actorProfile?['username'] as String?,
          title: notif['title'] as String,
          message: notif['body'] as String,
          time: timeStr,
          hasUnread: !(notif['read'] as bool? ?? false),
          userAvatarUrl: actorProfile?['avatar_url'] as String?,
          meetingId: data?['meeting_id'] as String?,
        ));
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _getActorProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching actor profile: $e');
      return null;
    }
  }

  NotificationType _mapNotificationType(String dbType) {
    switch (dbType.toLowerCase()) {
      case 'follow':
      case 'follow_request':
        return NotificationType.followRequest;
      case 'following':
        return NotificationType.following;
      case 'like':
        return NotificationType.postLike;
      case 'comment':
        return NotificationType.comment;
      case 'achievement':
        return NotificationType.achievement;
      case 'message':
        return NotificationType.message;
      case 'meeting':
        return NotificationType.meeting;
      case 'quest':
        return NotificationType.questCompleted;
      case 'goal_reached':
      case 'steps_goal':
        return NotificationType.stepsGoalAchieved;
      case 'streak':
        return NotificationType.streakReached;
      default:
        return NotificationType.goalReached;
    }
  }

  void _loadNotifications() {
    // Keep for compatibility with NotificationService listeners
    // But prefer real data loading
    if (mounted) {
      _loadRealNotifications();
    }
  }

  void _deleteNotification(int index) async {
    if (index < 0 || index >= _notifications.length) return;
    
    final notification = _notifications[index];
    HapticFeedback.mediumImpact();
    
    // Delete from database
    await _notificationsRepo.deleteNotification(notification.id);
    
    if (mounted) {
      setState(() {
        _deletedNotifications[notification.id] = notification;
        _deletedTimestamps[notification.id] = DateTime.now();
        _notifications.removeAt(index);
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
    
    // Note: We can't undo delete from database, but we can restore in UI
    // In a real app, you might want to implement soft delete
    if (mounted) {
      setState(() {
        final notification = _deletedNotifications[notificationId]!;
        _notifications.insert(0, notification);
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
                await _loadRealNotifications();
              },
              color: AppColors.orange,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : totalCount == 0
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
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                if (notification.type == NotificationType.meeting && notification.meetingId != null) {
                                  final meetingStorage = MeetingStorageService();
                                  final meeting = meetingStorage.getMeetingById(notification.meetingId!);
                                  if (meeting != null) {
                                    context.push('/video/room/${meeting.shareKey}');
                                  }
                                }
                                if (notification.hasUnread) {
                                  await _notificationsRepo.markAsRead(notification.id);
                                  if (mounted) {
                                    _loadRealNotifications();
                                  }
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
