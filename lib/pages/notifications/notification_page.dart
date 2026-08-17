import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../services/notification_service.dart';
import '../../services/meeting_storage_service.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../config/feature_flags.dart';
import '../../providers/accepted_client_trainers_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/profile_role_provider.dart';
import '../../providers/unread_notifications_count_provider.dart';
import '../../services/leads_service.dart';
import '../../utils/lead_request_ui_state.dart';
import '../../widgets/notifications/lead_request_notification_actions.dart';
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
  leadRequest,
  leadAccepted,
  leadDeclined,
  videoSession,
}

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  final NotificationsRepository _notificationsRepo = NotificationsRepository();
  final ProfileRepository _profileRepo = ProfileRepository();
  final LeadsService _leadsService = LeadsService();
  List<NotificationData> _notifications = [];
  final Map<String, NotificationData> _deletedNotifications = {};
  final Map<String, DateTime> _deletedTimestamps = {};
  final Set<String> _busyLeadIds = {};
  bool _isLoading = false;
  bool _didMarkReadThisOpen = false;

  @override
  void initState() {
    super.initState();
    _loadThenMarkRead();
    _notificationService.addListener(_loadNotifications);
  }

  /// Load first; only mark read after a successful fetch (DB remains source of truth).
  Future<void> _loadThenMarkRead() async {
    await _loadRealNotifications(markReadOnSuccess: true);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_loadNotifications);
    super.dispose();
  }

  Future<void> _loadRealNotifications({bool markReadOnSuccess = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final notificationsData = await _notificationsRepo.fetchNotifications();
      final prefs = await _profileRepo.fetchNotificationPreferences();
      if (!mounted) return;

      final notifications = <NotificationData>[];
      final communityOn = prefs['community'] ?? true;
      final remindersOn = prefs['reminders'] ?? true;
      final achievementsOn = prefs['achievements'] ?? true;

      for (final notif in notificationsData) {
        // Map database type to NotificationType enum
        final type = _mapNotificationType(notif['type'] as String);

        // Filter by user preferences
        if (!_shouldShowNotification(type, notif['type'] as String, communityOn, remindersOn, achievementsOn)) {
          continue;
        }

        // Parse data JSONB for additional info
        final data = notif['data'] as Map<String, dynamic>?;
        final actorId = data?['actor_id'] as String? ??
            data?['client_id'] as String? ??
            data?['provider_id'] as String?;
        final actorProfile = actorId != null ? await _getActorProfile(actorId) : null;
        final postId = data?['post_id'] as String?;

        // Fetch post preview for like/comment notifications
        String? postContentPreview;
        String? postMediaUrl;
        if (postId != null && (type == NotificationType.postLike || type == NotificationType.comment)) {
          final preview = await _notificationsRepo.fetchPostPreview(postId);
          if (preview != null) {
            postContentPreview = preview['content'] as String?;
            postMediaUrl = preview['media_url'] as String?;
          }
        }

        // Format timestamp
        final createdAt = DateTime.parse(notif['created_at'] as String);
        final timeStr = NotificationsRepository.formatRelativeTime(createdAt);

        final leadId = data?['lead_id'] as String?;
        final clientId = data?['client_id'] as String? ??
            (type == NotificationType.leadRequest ? actorId : null);
        final videoSessionId = data?['video_session_id'] as String?;
        var message = notif['body'] as String;
        if (type == NotificationType.videoSession) {
          message = _localizedVideoSessionBody(
            dbType: notif['type'] as String,
            data: data,
            fallback: message,
          );
        }
        notifications.add(NotificationData(
          id: notif['id'] as String,
          type: type,
          userName: actorProfile?['full_name'] as String? ?? actorProfile?['username'] as String?,
          title: notif['title'] as String,
          message: message,
          time: timeStr,
          hasUnread: !(notif['read'] as bool? ?? false),
          userAvatarUrl: actorProfile?['avatar_url'] as String?,
          meetingId: data?['meeting_id'] as String?,
          videoSessionId: videoSessionId,
          postId: postId,
          postContentPreview: postContentPreview,
          postMediaUrl: postMediaUrl,
          action: data?['action'] as String?,
          leadId: leadId,
          clientId: clientId,
          providerType: data?['provider_type'] as String?,
        ));
      }

      // Resolve live lead status for actionable request cards.
      final leadIds = notifications
          .where((n) => n.type == NotificationType.leadRequest && n.leadId != null)
          .map((n) => n.leadId!)
          .toList();
      if (leadIds.isNotEmpty) {
        final statusMap = await _leadsService.getLeadStatusesByIds(leadIds);
        // Empty map means fetch failed — leave status null (no stale Accept).
        // Partial map: missing ids are treated as cancelled/unavailable.
        if (statusMap.isNotEmpty) {
          for (var i = 0; i < notifications.length; i++) {
            final n = notifications[i];
            if (n.type != NotificationType.leadRequest || n.leadId == null) {
              continue;
            }
            notifications[i] = n.copyWith(
              leadStatus: statusMap[n.leadId!] ?? 'cancelled',
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      if (markReadOnSuccess && !_didMarkReadThisOpen) {
        _didMarkReadThisOpen = true;
        await _notificationsRepo.markAllAsRead();
        if (!mounted) return;
        setState(() {
          _notifications = _notifications
              .map((n) => n.copyWith(hasUnread: false))
              .toList();
        });
        ref.invalidate(unreadNotificationsCountProvider);
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Do not mark read on failed load.
    }
  }

  bool _shouldShowNotification(
    NotificationType type,
    String dbType,
    bool communityOn,
    bool remindersOn,
    bool achievementsOn,
  ) {
    // Community: likes, follows, comments
    if (type == NotificationType.postLike ||
        type == NotificationType.following ||
        type == NotificationType.followRequest ||
        type == NotificationType.comment) {
      return communityOn && FeatureFlags.communityNotificationsActive;
    }
    // Reminders: habit/meal reminders (type 'reminder' in DB)
    if (dbType.toLowerCase() == 'reminder') {
      return remindersOn;
    }
    // Quest / achievement (Quest system)
    if (type == NotificationType.questCompleted ||
        type == NotificationType.achievement) {
      return achievementsOn && FeatureFlags.questNotificationsActive;
    }
    // Home streak + goal progress (independent of Quest)
    if (type == NotificationType.streakReached ||
        type == NotificationType.stepsGoalAchieved ||
        type == NotificationType.goalReached) {
      return achievementsOn;
    }
    // Meetings, messages: always show (important)
    return true;
  }

  String _localizedVideoSessionBody({
    required String dbType,
    required Map<String, dynamic>? data,
    required String fallback,
  }) {
    final counterpart = (data?['counterpart_name'] as String?)?.trim().isNotEmpty == true
        ? data!['counterpart_name'] as String
        : (data?['host_name'] as String?)?.trim();
    final startRaw = data?['scheduled_start'] as String?;
    final start = startRaw == null ? null : DateTime.tryParse(startRaw);
    if (counterpart == null || counterpart.isEmpty || start == null) {
      return fallback;
    }
    final when = DateFormat('d MMM yyyy · h:mm a').format(start.toLocal());
    switch (dbType.toLowerCase()) {
      case 'video_session_created':
        return '$counterpart scheduled a session with you for $when.';
      case 'video_session_rescheduled':
        return '$counterpart moved your session to $when.';
      case 'video_session_cancelled':
        return '$counterpart cancelled your video session scheduled for $when.';
      case 'video_session_reminder_5m':
        return 'Your session with $counterpart starts at ${DateFormat('h:mm a').format(start.toLocal())}.';
      case 'video_session_starting':
        return 'Your session with $counterpart is starting now.';
      default:
        return fallback;
    }
  }

  Future<Map<String, dynamic>?> _getActorProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final list = (await supabase.rpc('get_public_profile', params: {'p_user_id': userId}) as List).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
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
      case 'lead_request':
      case 'trainer_request':
      case 'provider_request':
        return NotificationType.leadRequest;
      case 'lead_accepted':
        return NotificationType.leadAccepted;
      case 'lead_declined':
        return NotificationType.leadDeclined;
      case 'video_session_created':
      case 'video_session_rescheduled':
      case 'video_session_cancelled':
      case 'video_session_reminder_5m':
      case 'video_session_starting':
        return NotificationType.videoSession;
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

  void _openClientProfile(NotificationData notification) {
    final clientId = notification.clientId;
    if (clientId == null || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client profile unavailable')),
      );
      return;
    }
    final role = ref.read(currentUserProvider).value;
    if (role?.isNutritionist == true) {
      context.push('/nutritionist/clients/$clientId');
    } else {
      // Trainer (and fallback) use trainer client detail route.
      context.push('/clients/$clientId');
    }
  }

  Future<void> _acceptLeadFromNotification(NotificationData notification) async {
    final leadId = notification.leadId;
    if (leadId == null || _busyLeadIds.contains(leadId)) return;

    setState(() => _busyLeadIds.add(leadId));
    try {
      await _leadsService.updateLeadStatus(leadId: leadId, status: 'accepted');
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(leadStatus: 'accepted');
        }
        _busyLeadIds.remove(leadId);
      });
      ref.invalidate(leadsProvider);
      ref.invalidate(incomingLeadsProvider);
      ref.invalidate(acceptedClientTrainersProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection accepted')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyLeadIds.remove(leadId));
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _loadRealNotifications();
    }
  }

  Future<void> _declineLeadFromNotification(NotificationData notification) async {
    final leadId = notification.leadId;
    if (leadId == null || _busyLeadIds.contains(leadId)) return;

    final confirmed = await confirmDeclineLeadRequest(context);
    if (!confirmed || !mounted) return;

    setState(() => _busyLeadIds.add(leadId));
    try {
      await _leadsService.updateLeadStatus(leadId: leadId, status: 'declined');
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(leadStatus: 'declined');
        }
        _busyLeadIds.remove(leadId);
      });
      ref.invalidate(leadsProvider);
      ref.invalidate(incomingLeadsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyLeadIds.remove(leadId));
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _loadRealNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final pageBg =
        isLight ? DesignTokens.lightBackground : DesignTokens.darkBackground;
    final titleColor = DesignTokens.textPrimaryOf(context);
    final unreadCount = _notifications.where((n) => n.hasUnread).length;
    final totalCount = _notifications.length + _deletedNotifications.length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
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
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.stepsGradient.createShader(bounds),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$unreadCount unread ${unreadCount == 1 ? 'message' : 'messages'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: DesignTokens.textSecondaryOf(context),
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
                _didMarkReadThisOpen = false;
                await _loadRealNotifications(markReadOnSuccess: true);
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
                              isLeadActionBusy: notification.leadId != null &&
                                  _busyLeadIds.contains(notification.leadId),
                              onViewProfile: notification.type == NotificationType.leadRequest
                                  ? () => _openClientProfile(notification)
                                  : null,
                              onAcceptLead: notification.type == NotificationType.leadRequest
                                  ? () => _acceptLeadFromNotification(notification)
                                  : null,
                              onDeclineLead: notification.type == NotificationType.leadRequest
                                  ? () => _declineLeadFromNotification(notification)
                                  : null,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                if (notification.type == NotificationType.leadRequest) {
                                  _openClientProfile(notification);
                                  return;
                                }
                                if (notification.type == NotificationType.videoSession &&
                                    notification.videoSessionId != null &&
                                    notification.videoSessionId!.isNotEmpty &&
                                    !notification.videoSessionId!.contains('google-connected')) {
                                  context.push('/video/session/${notification.videoSessionId}');
                                  return;
                                }
                                if (notification.type == NotificationType.meeting && notification.meetingId != null) {
                                  final meetingStorage = MeetingStorageService();
                                  final meeting = meetingStorage.getMeetingById(notification.meetingId!);
                                  if (meeting != null) {
                                    context.push('/video/room/${meeting.shareKey}');
                                  }
                                } else if (notification.type == NotificationType.leadAccepted) {
                                  try {
                                    ref.invalidate(acceptedClientTrainersProvider);
                                  } catch (_) {}
                                  context.push('/my-trainers');
                                } else if (notification.action == 'open_pending_requests') {
                                  context.go('/home?tab=1');
                                } else if (notification.action == 'open_messaging') {
                                  context.go('/home?tab=2');
                                } else if (notification.action == 'open_discover') {
                                  context.go('/home?tab=1');
                                }
                              },
                              onFollow: null,
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
                color: DesignTokens.surfaceOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: DesignTokens.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: DesignTokens.textSecondaryOf(context),
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
  final String? videoSessionId;
  final String? userAvatarUrl;
  final String? postId;
  final String? postContentPreview;
  final String? postMediaUrl;
  final String? action;
  final String? leadId;
  final String? clientId;
  final String? providerType;
  final String? leadStatus;

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
    this.videoSessionId,
    this.userAvatarUrl,
    this.postId,
    this.postContentPreview,
    this.postMediaUrl,
    this.action,
    this.leadId,
    this.clientId,
    this.providerType,
    this.leadStatus,
  });

  LeadRequestUiState get leadRequestUiState =>
      leadRequestUiStateFromStatus(leadStatus);

  NotificationData copyWith({
    bool? hasUnread,
    String? leadStatus,
    String? clientId,
  }) {
    return NotificationData(
      id: id,
      type: type,
      userName: userName,
      title: title,
      message: message,
      time: time,
      hasUnread: hasUnread ?? this.hasUnread,
      hasImage: hasImage,
      canFollow: canFollow,
      meetingId: meetingId,
      videoSessionId: videoSessionId,
      userAvatarUrl: userAvatarUrl,
      postId: postId,
      postContentPreview: postContentPreview,
      postMediaUrl: postMediaUrl,
      action: action,
      leadId: leadId,
      clientId: clientId ?? this.clientId,
      providerType: providerType,
      leadStatus: leadStatus ?? this.leadStatus,
    );
  }
}

class _PostPreviewThumbnail extends StatelessWidget {
  final String? mediaUrl;
  final String? contentPreview;

  const _PostPreviewThumbnail({
    this.mediaUrl,
    this.contentPreview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 48.0;

    if (mediaUrl != null && mediaUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: mediaUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: cs.surfaceContainerHighest,
              child: Icon(Icons.image, color: cs.onSurfaceVariant, size: 20),
            ),
            errorWidget: (_, __, ___) => Container(
              color: cs.surfaceContainerHighest,
              child: Icon(Icons.image_not_supported, color: cs.onSurfaceVariant, size: 20),
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        contentPreview ?? '',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
          height: 1.2,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
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
  final VoidCallback? onViewProfile;
  final VoidCallback? onAcceptLead;
  final VoidCallback? onDeclineLead;
  final bool isLeadActionBusy;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    this.onFollow,
    this.onViewProfile,
    this.onAcceptLead,
    this.onDeclineLead,
    this.isLeadActionBusy = false,
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
      case NotificationType.videoSession:
        return Icons.video_call_rounded;
      case NotificationType.questCompleted:
        return Icons.check_circle_rounded;
      case NotificationType.streakReached:
        return Icons.local_fire_department_rounded;
      case NotificationType.leadRequest:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.leadAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.leadDeclined:
        return Icons.cancel_rounded;
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
                             type == NotificationType.comment ||
                             type == NotificationType.leadRequest ||
                             type == NotificationType.leadAccepted ||
                             type == NotificationType.leadDeclined);
    
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

    final isLeadRequest =
        widget.notification.type == NotificationType.leadRequest;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLeadRequest ? null : widget.onTap,
          onTapDown: isLeadRequest
              ? null
              : (_) {
                  _animationController.forward();
                },
          onTapUp: isLeadRequest
              ? null
              : (_) {
                  _animationController.reverse();
                },
          onTapCancel: isLeadRequest
              ? null
              : () {
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
                GestureDetector(
                  onTap: isLeadRequest ? widget.onViewProfile : null,
                  child: _buildAvatar(context, widget.notification.type),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLeadRequest) ...[
                        GestureDetector(
                          onTap: widget.onViewProfile,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.notification.userName ??
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
                                'wants to connect with you',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Client',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
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
                        LeadRequestNotificationActions(
                          uiState: widget.notification.leadRequestUiState,
                          isBusy: widget.isLeadActionBusy,
                          onViewProfile: widget.onViewProfile,
                          onAccept: widget.onAcceptLead,
                          onDecline: widget.onDeclineLead,
                        ),
                      ] else ...[
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
                    ],
                  ),
                ),
                // Post preview for like/comment
                if ((widget.notification.type == NotificationType.postLike ||
                        widget.notification.type == NotificationType.comment) &&
                    (widget.notification.postMediaUrl != null ||
                        (widget.notification.postContentPreview != null &&
                            widget.notification.postContentPreview!.isNotEmpty))) ...[
                  const SizedBox(width: 12),
                  _PostPreviewThumbnail(
                    mediaUrl: widget.notification.postMediaUrl,
                    contentPreview: widget.notification.postContentPreview,
                  ),
                ],
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
