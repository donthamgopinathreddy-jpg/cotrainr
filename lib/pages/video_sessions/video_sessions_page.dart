import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/video_session_models.dart';
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

  // Mock data
  final List<Meeting> _upcomingMeetings = [];
  final List<Meeting> _recentMeetings = [];
  final List<Meeting> _activeLinks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.role == Role.client ? 2 : 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  LinearGradient get _roleGradient {
    switch (widget.role) {
      case Role.client:
        return AppColors.clientVideoGradient;
      case Role.trainer:
        return AppColors.trainerVideoGradient;
      case Role.nutritionist:
        return AppColors.nutritionistVideoGradient;
    }
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
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
            Text(
              _pageSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              HapticFeedback.mediumImpact();
              context.push('/video/create?role=${widget.role.name}');
            },
          ),
        ],
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
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.push('/video/create?role=${widget.role.name}');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: widget.role == Role.client
                        ? Icons.qr_code_scanner_rounded
                        : Icons.calendar_today_rounded,
                    isGlass: true,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (widget.role == Role.client) {
                        context.push('/video/join');
                      } else {
                        context.push('/video/create?role=${widget.role.name}&schedule=true');
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
        // Upcoming Meetings
        if (_upcomingMeetings.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _upcomingMeetings.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _MeetingCardMini(
                    meeting: _upcomingMeetings[index],
                    gradient: _roleGradient,
                  );
                },
              ),
            ),
          ),
        ],

        // Recent Meetings
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
        if (_recentMeetings.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.videocam_outlined,
              title: 'No meetings yet',
              subtitle: 'Create your first meeting to get started',
              ctaLabel: 'Create Meeting',
              onTap: () => context.push('/video/create?role=client'),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _MeetingRow(meeting: _recentMeetings[index]),
                );
              },
              childCount: _recentMeetings.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
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
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUpcomingTab(),
              _buildLinksTab(),
              _buildHistoryTab(),
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

  Widget _buildHistoryTab() {
    if (_recentMeetings.isEmpty) {
      return _EmptyState(
        icon: Icons.history_outlined,
        title: 'No history',
        subtitle: 'Your past calls will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentMeetings.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MeetingRow(meeting: _recentMeetings[index]),
        );
      },
    );
  }
}

// Action Button - Icon Only
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final bool isGlass;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.gradient,
    this.isGlass = false,
  });

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
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
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

    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
              const SizedBox(height: 12),
              _RoleChip(role: meeting.hostRole),
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
                          ? '${meeting.scheduledFor!.hour}:${meeting.scheduledFor!.minute.toString().padLeft(2, '0')}'
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
                      'Open',
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

  const _MeetingRow({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
            boxShadow: DesignTokens.cardShadowOf(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.orange.withOpacity(0.2),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meeting.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusPill(status: meeting.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meeting.meetingId,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondaryOf(context),
                    size: 20,
                  ),
                ],
              ),
            ),
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
        color: colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Client Name',
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
                    child: const Text(
                      'Goal: Weight Loss',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
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
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: gradient.colors.first,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        color: colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
                        color: AppColors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Expires ${link.scheduledFor!.day}/${link.scheduledFor!.month}',
                        style: const TextStyle(fontSize: 10, color: AppColors.orange),
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
    LinearGradient gradient;
    switch (role) {
      case Role.trainer:
        gradient = AppColors.trainerVideoGradient;
        break;
      case Role.nutritionist:
        gradient = AppColors.nutritionistVideoGradient;
        break;
      default:
        gradient = AppColors.clientVideoGradient;
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

// Status Pill
class _StatusPill extends StatelessWidget {
  final MeetingStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case MeetingStatus.live:
        color = AppColors.green;
        label = 'LIVE';
        break;
      case MeetingStatus.ended:
        color = AppColors.textSecondaryOf(context);
        label = 'ENDED';
        break;
      case MeetingStatus.canceled:
        color = AppColors.red;
        label = 'CANCELED';
        break;
      default:
        color = AppColors.orange;
        label = 'UPCOMING';
    }

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
                  backgroundColor: AppColors.orange,
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
