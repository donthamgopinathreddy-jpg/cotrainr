import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/video_session_models.dart';
import '../../services/meeting_storage_service.dart';
import '../../services/notification_service.dart';
import '../../pages/notifications/notification_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class VideoSessionsPage extends StatefulWidget {
  final Role role;

  const VideoSessionsPage({
    super.key,
    required this.role,
  });

  @override
  State<VideoSessionsPage> createState() => _VideoSessionsPageState();
}

class _VideoSessionsPageState extends State<VideoSessionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();

  final MeetingStorageService _meetingStorage = MeetingStorageService();
  Timer? _meetingStatusTimer;
  
  List<Meeting> get _ongoingMeetings => _meetingStorage.ongoingMeetings;
  List<Meeting> get _upcomingMeetings => _meetingStorage.upcomingMeetings;
  List<Meeting> get _recentMeetings => _meetingStorage.recentMeetings;
  final List<Meeting> _activeLinks = [];
  
  int get _totalMeetingsCount => _ongoingMeetings.length + _upcomingMeetings.length + _recentMeetings.length + _activeLinks.length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, // Only Ongoing and Upcoming tabs
      vsync: this,
    );
    
    // Check and update meeting statuses every minute
    _meetingStatusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndUpdateMeetings();
    });
    
    // Also check immediately
    _checkAndUpdateMeetings();
  }

  void _checkAndUpdateMeetings() {
    final beforeUpdate = _meetingStorage.upcomingMeetings.length;
    _meetingStorage.checkAndUpdateUpcomingMeetings();
    final afterUpdate = _meetingStorage.upcomingMeetings.length;
    
    // If a meeting moved from upcoming to ongoing, send notification
    if (beforeUpdate > afterUpdate) {
      final newlyLiveMeetings = _meetingStorage.ongoingMeetings
          .where((m) => m.scheduledFor != null && 
              m.scheduledFor!.difference(DateTime.now()).inMinutes.abs() < 2)
          .toList();
      
      for (final meeting in newlyLiveMeetings) {
        _sendMeetingNotification(meeting);
      }
    }
    
    // Update UI to reflect status changes
    if (mounted) {
      setState(() {});
    }
  }

  void _sendMeetingNotification(Meeting meeting) {
    final notificationService = NotificationService();
    final now = DateTime.now();
    
    notificationService.addNotification(
      NotificationData(
        id: 'meeting_${meeting.meetingId}_${now.millisecondsSinceEpoch}',
        type: NotificationType.meeting,
        userName: null,
        title: 'Meeting Started',
        message: '📹 Your meeting "${meeting.title}" is now live!',
        time: 'Just now',
        hasUnread: true,
        hasImage: false,
        canFollow: false,
        meetingId: meeting.meetingId,
      ),
    );
  }

  void _refreshMeetings() {
    _checkAndUpdateMeetings();
  }

  @override
  void dispose() {
    _meetingStatusTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  LinearGradient get _roleGradient {
    // Use purple gradient for all video sessions
    return const LinearGradient(
      colors: [AppColors.purple, Color(0xFFB38CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  String get _pageTitle {
    switch (widget.role) {
      case Role.client:
        return 'Video Sessions';
      case Role.trainer:
        return 'Client Sessions';
      case Role.nutritionist:
        return 'Consultations';
    }
  }

  String get _pageSubtitle {
    switch (widget.role) {
      case Role.client:
        return 'Create or join meetings';
      case Role.trainer:
        return 'Manage calls and links';
      case Role.nutritionist:
        return 'Diet calls and followups';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A0F2E) // Purple-black mix background (not too dark)
          : const Color(0xFFF0EBFF), // More vibrant light purple background
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _pageTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              children: [
                Text(
                  _pageSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                if (_totalMeetingsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_totalMeetingsCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Primary Actions - Icon Only
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.add_rounded,
                    gradient: _roleGradient,
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await context.push('/video/create?role=${widget.role.name}');
                      _refreshMeetings();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    text: widget.role == Role.client ? 'Join' : null,
                    icon: widget.role == Role.client
                        ? null
                        : Icons.calendar_today_rounded,
                    isGlass: false,
                    gradient: _roleGradient,
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (widget.role == Role.client) {
                        await context.push('/video/join');
                      } else {
                        await context.push('/video/create?role=${widget.role.name}&schedule=true');
                        _refreshMeetings();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: widget.role == Role.client
                ? _buildClientContent()
                : _buildTrainerNutritionistContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildClientContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Ongoing Meetings
        if (_ongoingMeetings.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Ongoing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _OngoingMeetingTile(
                    meeting: _ongoingMeetings[index],
                    gradient: _roleGradient,
                  ),
                );
              },
              childCount: _ongoingMeetings.length,
            ),
          ),
        ],

        // Upcoming Meetings
        if (_upcomingMeetings.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, _ongoingMeetings.isNotEmpty ? 16 : 8, 16, 12),
              child: Text(
                'Upcoming',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MeetingRow(
                    meeting: _upcomingMeetings[index],
                    gradient: _roleGradient,
                    onTap: (meeting) {
                      // Check if meeting time has arrived
                      if (meeting.scheduledFor != null && meeting.scheduledFor!.isAfter(DateTime.now())) {
                        // Show waiting screen
                        _showMeetingWaiting(context, meeting);
                      } else {
                        // Navigate to meeting room
                        context.push('/video/room/${meeting.shareKey}');
                      }
                    },
                  ),
                );
              },
              childCount: _upcomingMeetings.length,
            ),
          ),
        ],

        // Recent Meetings (ended meetings)
        if (_recentMeetings.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16, 
                (_ongoingMeetings.isNotEmpty || _upcomingMeetings.isNotEmpty) ? 16 : 8, 
                16, 
                12
              ),
              child: Text(
                'Recent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _RecentMeetingTile(
                    meeting: _recentMeetings[index],
                    gradient: _roleGradient,
                  ),
                );
              },
              childCount: _recentMeetings.length,
            ),
          ),
        ],

        // Empty State - Only show if no meetings at all
        if (_ongoingMeetings.isEmpty && _upcomingMeetings.isEmpty && _recentMeetings.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.videocam_outlined,
              title: 'No meetings yet',
              subtitle: 'Create your first meeting to get started',
              ctaLabel: 'Create Meeting',
              onTap: () => context.push('/video/create?role=client'),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  void _showMeetingWaiting(BuildContext context, Meeting meeting) {
    if (meeting.scheduledFor == null) return;
    
    final now = DateTime.now();
    final scheduledTime = meeting.scheduledFor!;
    final difference = scheduledTime.difference(now);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MeetingWaitingDialog(
        meeting: meeting,
        scheduledTime: scheduledTime,
        timeRemaining: difference,
      ),
    );
  }

  Widget _buildTrainerNutritionistContent() {
    return Column(
      children: [
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: _roleGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondaryOf(context),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUpcomingTab(),
              _buildLinksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcomingMeetings.isEmpty) {
      return _EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No upcoming sessions',
        subtitle: 'Schedule a session to get started',
        ctaLabel: 'Schedule Session',
        onTap: () => context.push('/video/create?role=${widget.role.name}&schedule=true'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcomingMeetings.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TrainerMeetingCard(
            meeting: _upcomingMeetings[index],
            gradient: _roleGradient,
          ),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    if (_activeLinks.isEmpty) {
      return _EmptyState(
        icon: Icons.link_outlined,
        title: 'No active links',
        subtitle: 'Create a meeting link to share with clients',
        ctaLabel: 'Create Link',
        onTap: () => context.push('/video/create?role=${widget.role.name}'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeLinks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LinkCard(
            link: _activeLinks[index],
            gradient: _roleGradient,
          ),
        );
      },
    );
  }

}

// Action Button - Icon Only
class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final bool isGlass;

  const _ActionButton({
    this.icon,
    this.text,
    required this.onTap,
    this.gradient,
    this.isGlass = false,
  }) : assert(icon != null || text != null, 'Either icon or text must be provided');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: isGlass ? null : gradient,
              color: isGlass
                  ? colorScheme.surface.withOpacity(0.55)
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: isGlass
                  ? Border.all(
                      color: DesignTokens.borderColorOf(context),
                      width: 1,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: isGlass ? 18 : 0, sigmaY: isGlass ? 18 : 0),
                child: Center(
                  child: icon != null
                      ? Icon(
                          icon,
                          color: isGlass
                              ? AppColors.textPrimaryOf(context)
                              : Colors.white,
                          size: 24,
                        )
                      : Text(
                          text!,
                          style: TextStyle(
                            color: isGlass
                                ? AppColors.textPrimaryOf(context)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Meeting Card Mini (for horizontal list)
class _MeetingCardMini extends StatelessWidget {
  final Meeting meeting;
  final LinearGradient gradient;

  const _MeetingCardMini({
    required this.meeting,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/video/room/${meeting.shareKey}');
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meeting.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Code: ${meeting.joinCode}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        meeting.scheduledFor != null
                            ? '${meeting.scheduledFor!.day}/${meeting.scheduledFor!.month} ${meeting.scheduledFor!.hour}:${meeting.scheduledFor!.minute.toString().padLeft(2, '0')}'
                            : 'Now',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${meeting.participantsCount}/10',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Join',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }
}

// Meeting Row (for vertical list)
class _MeetingRow extends StatelessWidget {
  final Meeting meeting;
  final LinearGradient? gradient;
  final Function(Meeting)? onTap;

  const _MeetingRow({
    required this.meeting,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = meeting.status == MeetingStatus.live;
    final isUpcoming = meeting.status == MeetingStatus.upcoming;

    // Different background colors for upcoming vs live
    Color backgroundColor;
    if (isLive) {
      backgroundColor = isDark
          ? AppColors.green.withOpacity(0.15)
          : AppColors.green.withOpacity(0.1);
    } else if (isUpcoming) {
      backgroundColor = isDark
          ? AppColors.purple.withOpacity(0.15)
          : AppColors.purple.withOpacity(0.12);
    } else {
      backgroundColor = colorScheme.surface;
    }

    String _formatDate(DateTime date) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    String _formatTime(DateTime date) {
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18), // Further reduced horizontal padding
      margin: const EdgeInsets.only(bottom: 12), // Add margin between tiles
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        // Border removed as requested
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge, // Clip to prevent overflow
        children: [
          // Main content
          Row(
                children: [
                  CircleAvatar(
                    radius: 28, // Increased size
                    backgroundColor: isLive
                        ? AppColors.green.withOpacity(0.2)
                        : AppColors.purple.withOpacity(0.2),
                    child: Icon(
                      isLive ? Icons.videocam_rounded : Icons.video_call_rounded,
                      color: isLive ? AppColors.green : AppColors.purple,
                      size: 22, // Increased icon size
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        style: TextStyle(
                          fontSize: 16, // Increased font size
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Show date and time for upcoming meetings
                      if (isUpcoming && meeting.scheduledFor != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _formatDate(meeting.scheduledFor!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryOf(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(meeting.scheduledFor!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          Text(
                            'Code: ${meeting.joinCode}',
                            style: TextStyle(
                              fontSize: 12, // Slightly increased
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ID: ${meeting.meetingId}',
                            style: TextStyle(
                              fontSize: 12, // Slightly increased
                              color: AppColors.textSecondaryOf(context),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Join Button - Smaller to prevent overflow
                Container(
                  constraints: const BoxConstraints(minWidth: 50, maxWidth: 60),
                  decoration: BoxDecoration(
                    gradient: gradient ?? const LinearGradient(
                      colors: [AppColors.purple, Color(0xFFB38CFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (onTap != null) {
                          onTap!(meeting);
                        } else {
                          // Default: navigate to meeting room
                          context.push('/video/room/${meeting.shareKey}');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: const Text(
                          'Join',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Recent Meeting Tile - Shows ended meetings
class _RecentMeetingTile extends StatelessWidget {
  final Meeting meeting;
  final LinearGradient? gradient;

  const _RecentMeetingTile({
    required this.meeting,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.purple.withOpacity(0.15)
            : AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.purple.withOpacity(0.2),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.purple,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Code: ${meeting.joinCode}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ID: ${meeting.meetingId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Ongoing Meeting Tile - Navigates directly to meeting room when tapped
class _OngoingMeetingTile extends StatelessWidget {
  final Meeting meeting;
  final LinearGradient? gradient;

  const _OngoingMeetingTile({
    required this.meeting,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/video/room/${meeting.shareKey}');
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.green.withOpacity(0.15)
                : AppColors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.green.withOpacity(0.2),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: AppColors.green,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Code: ${meeting.joinCode}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${meeting.meetingId}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Trainer Meeting Card
class _TrainerMeetingCard extends StatelessWidget {
  final Meeting meeting;
  final LinearGradient gradient;

  const _TrainerMeetingCard({
    required this.meeting,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  meeting.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Code: ${meeting.joinCode}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 4),
              Text(
                meeting.scheduledFor != null
                    ? '${meeting.scheduledFor!.day}/${meeting.scheduledFor!.month} at ${meeting.scheduledFor!.hour}:${meeting.scheduledFor!.minute.toString().padLeft(2, '0')}'
                    : 'Now',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/video/room/${meeting.shareKey}');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Link Card
class _LinkCard extends StatelessWidget {
  final Meeting link;
  final LinearGradient gradient;

  const _LinkCard({
    required this.link,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.meetingId,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${link.joinCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (link.scheduledFor != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Expires ${link.scheduledFor!.day}/${link.scheduledFor!.month}',
                    style: const TextStyle(fontSize: 10, color: AppColors.purple),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: gradient.colors.first),
                    foregroundColor: gradient.colors.first,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: gradient.colors.first,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Meeting Waiting Dialog
class _MeetingWaitingDialog extends StatefulWidget {
  final Meeting meeting;
  final DateTime scheduledTime;
  final Duration timeRemaining;

  const _MeetingWaitingDialog({
    required this.meeting,
    required this.scheduledTime,
    required this.timeRemaining,
  });

  @override
  State<_MeetingWaitingDialog> createState() => _MeetingWaitingDialogState();
}

class _MeetingWaitingDialogState extends State<_MeetingWaitingDialog>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  AnimationController? _animationController;
  Duration _remaining = Duration.zero;
  Duration _initialDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeRemaining;
    _initialDuration = widget.timeRemaining;
    
    // Initialize animation controller with a safe duration
    final safeDuration = _initialDuration.inSeconds > 0 
        ? _initialDuration 
        : const Duration(seconds: 1);
    
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: safeDuration,
      );
      
      // Start the animation
      if (_initialDuration.inSeconds > 0) {
        _animationController!.forward();
      }
    } catch (e) {
      // If initialization fails, controller remains null
      _animationController = null;
    }
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = widget.scheduledTime.difference(now);
      
      if (difference.isNegative || difference.inSeconds <= 0) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context);
          context.push('/video/room/${widget.meeting.shareKey}');
        }
      } else {
        setState(() {
          _remaining = difference;
          // Update animation progress
          if (_animationController != null && _initialDuration.inSeconds > 0) {
            final progress = 1.0 - (difference.inSeconds / _initialDuration.inSeconds);
            _animationController!.value = progress.clamp(0.0, 1.0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 64,
              color: AppColors.purple,
            ),
            const SizedBox(height: 16),
            Text(
              'Meeting Starts Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.meeting.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Animated Circular Timer
            Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.purple.withOpacity(0.1),
                    ),
                  ),
                ),
                // Animated progress circle
                SizedBox(
                  width: 180,
                  height: 180,
                  child: _animationController != null
                      ? AnimatedBuilder(
                          animation: _animationController!,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: _animationController!.value,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.purple,
                              ),
                            );
                          },
                        )
                      : CircularProgressIndicator(
                          value: 0.0,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.purple,
                          ),
                        ),
                ),
                // Timer text in center
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_remaining),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: AppColors.purple,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time Remaining',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Starts at ${widget.scheduledTime.hour}:${widget.scheduledTime.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Role Chip
class _RoleChip extends StatelessWidget {
  final Role role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final label = role.name.toUpperCase();
    // Use purple gradient for all roles
    const gradient = LinearGradient(
      colors: [AppColors.purple, Color(0xFFB38CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Status Pill
class _StatusPill extends StatelessWidget {
  final MeetingStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    LinearGradient? gradient;
    String label;
    switch (status) {
      case MeetingStatus.live:
        gradient = const LinearGradient(
          colors: [AppColors.green, Color(0xFF65E6B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        label = 'ONGOING';
        break;
      case MeetingStatus.ended:
        gradient = null;
        label = 'ENDED';
        break;
      case MeetingStatus.canceled:
        gradient = const LinearGradient(
          colors: [AppColors.red, Color(0xFFFF7A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        label = 'CANCELED';
        break;
      default:
        gradient = const LinearGradient(
          colors: [AppColors.purple, Color(0xFFB38CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        label = 'UPCOMING';
    }

    if (gradient == null) {
      final color = AppColors.textSecondaryOf(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textSecondaryOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onTap != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: AppColors.purple,
                ),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
