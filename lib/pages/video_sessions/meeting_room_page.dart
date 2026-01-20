import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/video_session_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class MeetingRoomPage extends StatefulWidget {
  final String meetingId;

  const MeetingRoomPage({
    super.key,
    required this.meetingId,
  });

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage>
    with TickerProviderStateMixin {
  // State
  bool _micOn = true;
  bool _videoOn = true;
  bool _handRaised = false;
  bool _chatOpen = false;
  String _speakerRoute = 'Auto';
  String _layoutMode = 'Grid';
  String? _pinnedUserId;
  bool _isLive = true;
  Duration _meetingDuration = const Duration(minutes: 5);
  int _raisedHandsCount = 0;
  bool _unreadChat = false;
  bool _unreadRaisedHands = false;

  // Participants (mock data - up to 10)
  final List<Participant> _participants = [];
  int _participantsCount = 4;
  bool _isHost = true;

  // Animation Controllers
  late AnimationController _pageEnterController;
  late AnimationController _topBarController;
  late AnimationController _dockController;
  late AnimationController _handBadgeController;
  late AnimationController _speakingIndicatorController;
  late PageController _gridPageController;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pageEnterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _topBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _dockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _handBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _speakingIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _gridPageController = PageController();

    // Start animations
    _pageEnterController.forward();
    _topBarController.forward();
    _dockController.forward();

    // Initialize mock participants
    _initializeParticipants();
    
    // Start meeting timer
    _startMeetingTimer();
  }

  void _initializeParticipants() {
    _participants.clear();
    _participants.addAll([
      Participant(
        userId: 'self',
        displayName: 'You',
        role: Role.client,
        isHost: _isHost,
        muted: !_micOn,
        videoOff: !_videoOn,
      ),
      Participant(
        userId: 'user1',
        displayName: 'Sarah',
        role: Role.trainer,
        isHost: false,
        muted: false,
        videoOff: false,
      ),
      Participant(
        userId: 'user2',
        displayName: 'Mike',
        role: Role.client,
        isHost: false,
        muted: true,
        videoOff: true,
      ),
      Participant(
        userId: 'user3',
        displayName: 'Emma',
        role: Role.nutritionist,
        isHost: false,
        muted: false,
        videoOff: false,
      ),
    ]);
    _participantsCount = _participants.length;
  }

  void _startMeetingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _meetingDuration = _meetingDuration + const Duration(seconds: 1);
        });
        _startMeetingTimer();
      }
    });
  }

  @override
  void dispose() {
    _pageEnterController.dispose();
    _topBarController.dispose();
    _dockController.dispose();
    _handBadgeController.dispose();
    _speakingIndicatorController.dispose();
    _gridPageController.dispose();
    super.dispose();
  }

  // Grid Layout Calculation
  int _getGridColumns(int count) {
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 2;
    if (count <= 6) return 3;
    return 3;
  }

  int _getGridRows(int count) {
    if (count == 1) return 1;
    if (count == 2) return 1;
    if (count <= 4) return 2;
    if (count <= 6) return 2;
    return 3;
  }

  int _getPagesFor10() {
    return _participantsCount == 10 ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0B1220),
                          const Color(0xFF121A2B),
                        ]
                      : [
                          const Color(0xFFF5F5F5),
                          const Color(0xFFE8E8E8),
                        ],
                ),
              ),
            ),

            // Grid Area
            _buildGridArea(),

            // Top Bar
            _buildTopBar(),

            // Bottom Dock
            _buildBottomDock(),

            // Chat Overlay
            if (_chatOpen) _buildChatOverlay(),

            // Participants Overlay
            // Will be shown via bottom sheet
          ],
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    final gridColumns = _getGridColumns(_participantsCount);
    final gridRows = _getGridRows(_participantsCount);
    final pages = _getPagesFor10();

    return Positioned.fill(
      top: 56,
      bottom: 84,
      child: pages > 1
          ? _buildPagedGrid(pages, gridColumns, gridRows)
          : _buildSingleGrid(gridColumns, gridRows),
    );
  }

  Widget _buildSingleGrid(int columns, int rows) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _participantsCount,
        itemBuilder: (context, index) {
          final participant = index < _participants.length
              ? _participants[index]
              : Participant(
                  userId: 'user$index',
                  displayName: 'User ${index + 1}',
                  role: Role.client,
                );
          return _ParticipantTile(
            participant: participant,
            isPinned: _pinnedUserId == participant.userId,
            isSpeaking: index == 1, // Mock speaking
            handRaised: participant.userId == 'self' ? _handRaised : false,
            onPin: _isHost || participant.userId == 'self'
                ? () {
                    setState(() {
                      _pinnedUserId = _pinnedUserId == participant.userId
                          ? null
                          : participant.userId;
                    });
                    HapticFeedback.selectionClick();
                  }
                : null,
          );
        },
      ),
    );
  }

  Widget _buildPagedGrid(int pages, int columns, int rows) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _gridPageController,
            itemCount: pages,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * 6;
              final endIndex = (startIndex + 6).clamp(0, _participantsCount);
              final pageParticipants = _participants.sublist(
                startIndex,
                endIndex.clamp(0, _participants.length),
              );

              return Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: pageParticipants.length,
                  itemBuilder: (context, index) {
                    final participant = pageParticipants[index];
                    return _ParticipantTile(
                      participant: participant,
                      isPinned: _pinnedUserId == participant.userId,
                      isSpeaking: index == 1,
                      handRaised: participant.userId == 'self' ? _handRaised : false,
                      onPin: _isHost || participant.userId == 'self'
                          ? () {
                              setState(() {
                                _pinnedUserId = _pinnedUserId == participant.userId
                                    ? null
                                    : participant.userId;
                              });
                              HapticFeedback.selectionClick();
                            }
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Page Indicator
        Container(
          height: 24,
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages,
              (index) => AnimatedBuilder(
                animation: _gridPageController,
                builder: (context, child) {
                  final currentPage = _gridPageController.hasClients
                      ? _gridPageController.page?.round() ?? 0
                      : 0;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentPage == index
                          ? AppColors.orange
                          : AppColors.orange.withOpacity(0.3),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return FadeTransition(
      opacity: _topBarController,
      child: Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 56,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface.withOpacity(0.7),
                    Theme.of(context).colorScheme.surface.withOpacity(0.0),
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Back Button
                  _GlassCircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.pop();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Meeting Info Chip
                  Expanded(
                    child: _MeetingInfoChip(
                      meetingId: widget.meetingId,
                      isLive: _isLive,
                      duration: _meetingDuration,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Participants Button
                  _GlassCircleButton(
                    icon: Icons.people_rounded,
                    badge: _unreadRaisedHands ? '$_raisedHandsCount' : null,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _showParticipantsSheet();
                    },
                  ),

                  if (_isHost) ...[
                    const SizedBox(width: 8),
                    _GlassCircleButton(
                      icon: Icons.volume_off_rounded,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        // Mute all
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _dockController,
        curve: Curves.easeOut,
      )),
      child: Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 84,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.06),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic Toggle
                  _DockButton(
                    icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    isActive: _micOn,
                    isOff: !_micOn,
                    onTap: () {
                      setState(() => _micOn = !_micOn);
                      HapticFeedback.selectionClick();
                    },
                  ),

                  // Video Toggle
                  _DockButton(
                    icon: _videoOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    isActive: _videoOn,
                    isOff: !_videoOn,
                    onTap: () {
                      setState(() => _videoOn = !_videoOn);
                      HapticFeedback.selectionClick();
                    },
                  ),

                  // Three Dots Menu
                  _DockButton(
                    icon: Icons.more_vert_rounded,
                    isActive: false,
                    badge: (_unreadChat || _unreadRaisedHands) ? '•' : null,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _showThreeDotsMenu();
                    },
                  ),

                  // End Call (Wide)
                  _EndCallButton(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _showEndCallConfirm();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle Bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() => _chatOpen = false);
                        },
                      ),
                    ],
                  ),
                ),

                // Messages List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: 5, // Mock messages
                    itemBuilder: (context, index) {
                      return _ChatMessage(
                        message: 'Message ${index + 1}',
                        sender: 'User ${index + 1}',
                        isMe: index == 0,
                      );
                    },
                  ),
                ),

                // Input Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () {},
                      ),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.background,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.stepsGradient,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, size: 20),
                          color: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThreeDotsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThreeDotsMenuSheet(
        handRaised: _handRaised,
        speakerRoute: _speakerRoute,
        chatOpen: _chatOpen,
        unreadChat: _unreadChat,
        unreadRaisedHands: _unreadRaisedHands,
        onHandRaise: () {
          setState(() {
            _handRaised = !_handRaised;
            if (_handRaised) {
              _raisedHandsCount++;
              _handBadgeController.forward(from: 0);
            } else {
              _raisedHandsCount--;
            }
          });
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onSpeakerRoute: () {
          Navigator.pop(context);
          _showSpeakerRouteSheet();
        },
        onChat: () {
          setState(() {
            _chatOpen = !_chatOpen;
            _unreadChat = false;
          });
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
        onParticipants: () {
          Navigator.pop(context);
          _showParticipantsSheet();
        },
        onLayoutSwitch: () {
          setState(() {
            _layoutMode = _layoutMode == 'Grid' ? 'Focus' : 'Grid';
          });
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onPinActiveSpeaker: () {
          // Pin active speaker logic
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSpeakerRouteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SpeakerRouteSheet(
        currentRoute: _speakerRoute,
        onRouteSelected: (route) {
          setState(() => _speakerRoute = route);
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showParticipantsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _ParticipantsSheet(
          participants: _participants,
          isHost: _isHost,
          raisedHandsCount: _raisedHandsCount,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showEndCallConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _EndCallConfirmSheet(
        isHost: _isHost,
        onEndForMe: () {
          Navigator.pop(context);
          context.pop();
        },
        onEndForAll: () {
          Navigator.pop(context);
          _showEndCallSummary();
        },
      ),
    );
  }

  void _showEndCallSummary() {
    showDialog(
      context: context,
      builder: (context) => _EndCallSummaryDialog(
        duration: _meetingDuration,
        participantsCount: _participantsCount,
        onClose: () {
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }
}

// Participant Tile
class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isPinned;
  final bool isSpeaking;
  final bool handRaised;
  final VoidCallback? onPin;

  const _ParticipantTile({
    required this.participant,
    required this.isPinned,
    required this.isSpeaking,
    required this.handRaised,
    this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    LinearGradient roleGradient;
    switch (participant.role) {
      case Role.trainer:
        roleGradient = AppColors.trainerVideoGradient;
        break;
      case Role.nutritionist:
        roleGradient = AppColors.nutritionistVideoGradient;
        break;
      default:
        roleGradient = AppColors.clientVideoGradient;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or Avatar
              participant.videoOff
                  ? Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: roleGradient.colors.first.withOpacity(0.3),
                        child: participant.avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  participant.avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: 50,
                                color: roleGradient.colors.first,
                              ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.withOpacity(0.3),
                      child: const Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    ),

              // Speaking Indicator
              if (isSpeaking)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.green,
                        width: 3,
                      ),
                    ),
                  ),
                ),

              // Name and Badges
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        participant.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (participant.isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.stepsGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: roleGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            participant.role.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Muted Indicator
              if (participant.muted)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_off_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // Pin Button (Top Left)
              if (onPin != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: Icon(
                      isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: onPin,
                  ),
                ),

              // Hand Raised Badge
              if (handRaised)
                Positioned(
                  top: 8,
                  left: isPinned ? 48 : 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.stepsGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.back_hand_rounded,
                      color: Colors.white,
                      size: 16,
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

// Glass Circle Button
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  if (badge != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: AppColors.stepsGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

// Meeting Info Chip
class _MeetingInfoChip extends StatelessWidget {
  final String meetingId;
  final bool isLive;
  final Duration duration;

  const _MeetingInfoChip({
    required this.meetingId,
    required this.isLive,
    required this.duration,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            meetingId,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Dock Button
class _DockButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final bool isOff;
  final VoidCallback onTap;
  final String? badge;

  const _DockButton({
    required this.icon,
    required this.isActive,
    this.isOff = false,
    required this.onTap,
    this.badge,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedScale(
        scale: _scaleController.value * 0.04 + 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.isActive
                ? AppColors.stepsGradient
                : widget.isOff
                    ? null
                    : null,
            color: widget.isOff
                ? AppColors.red.withOpacity(0.3)
                : widget.isActive
                    ? null
                    : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 24,
              ),
              if (widget.badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: AppColors.stepsGradient,
                      shape: BoxShape.circle,
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

// End Call Button (Wide)
class _EndCallButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EndCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.red, Color(0xFFFF7A7A)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text(
            'End Call',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// Three Dots Menu Sheet
class _ThreeDotsMenuSheet extends StatelessWidget {
  final bool handRaised;
  final String speakerRoute;
  final bool chatOpen;
  final bool unreadChat;
  final bool unreadRaisedHands;
  final VoidCallback onHandRaise;
  final VoidCallback onSpeakerRoute;
  final VoidCallback onChat;
  final VoidCallback onParticipants;
  final VoidCallback onLayoutSwitch;
  final VoidCallback onPinActiveSpeaker;

  const _ThreeDotsMenuSheet({
    required this.handRaised,
    required this.speakerRoute,
    required this.chatOpen,
    required this.unreadChat,
    required this.unreadRaisedHands,
    required this.onHandRaise,
    required this.onSpeakerRoute,
    required this.onChat,
    required this.onParticipants,
    required this.onLayoutSwitch,
    required this.onPinActiveSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MenuAction(
                  icon: handRaised
                      ? Icons.back_hand_rounded
                      : Icons.back_hand_outlined,
                  label: 'Raise Hand',
                  isActive: handRaised,
                  onTap: onHandRaise,
                ),
                _MenuAction(
                  icon: Icons.volume_up_rounded,
                  label: speakerRoute,
                  onTap: onSpeakerRoute,
                ),
                _MenuAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  isActive: chatOpen,
                  badge: unreadChat ? '•' : null,
                  onTap: onChat,
                ),
                _MenuAction(
                  icon: Icons.people_rounded,
                  label: 'Participants',
                  badge: unreadRaisedHands ? '•' : null,
                  onTap: onParticipants,
                ),
                _MenuAction(
                  icon: Icons.grid_view_rounded,
                  label: 'Layout',
                  onTap: onLayoutSwitch,
                ),
                _MenuAction(
                  icon: Icons.push_pin_rounded,
                  label: 'Pin Speaker',
                  onTap: onPinActiveSpeaker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Menu Action
class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 48) / 3,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.orange.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.stepsGradient : null,
                      color: isActive
                          ? null
                          : Theme.of(context).colorScheme.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isActive
                          ? Colors.white
                          : AppColors.textPrimaryOf(context),
                      size: 24,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: AppColors.stepsGradient,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.orange
                      : AppColors.textPrimaryOf(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Speaker Route Sheet
class _SpeakerRouteSheet extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onRouteSelected;

  const _SpeakerRouteSheet({
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final routes = ['Auto', 'Earpiece', 'Speaker', 'Bluetooth'];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Audio Route',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                ...routes.map((route) => _RouteOption(
                      route: route,
                      isSelected: route == currentRoute,
                      onTap: () => onRouteSelected(route),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Route Option
class _RouteOption extends StatelessWidget {
  final String route;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteOption({
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.orange.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  route,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.orange,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Participants Sheet
class _ParticipantsSheet extends StatelessWidget {
  final List<Participant> participants;
  final bool isHost;
  final int raisedHandsCount;
  final ScrollController scrollController;

  const _ParticipantsSheet({
    required this.participants,
    required this.isHost,
    required this.raisedHandsCount,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Participants (${participants.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
          if (isHost && raisedHandsCount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.stepsGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.back_hand_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '$raisedHandsCount Raised Hand${raisedHandsCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                return _ParticipantRow(
                  participant: participant,
                  isHost: isHost,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Participant Row
class _ParticipantRow extends StatelessWidget {
  final Participant participant;
  final bool isHost;

  const _ParticipantRow({
    required this.participant,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    LinearGradient roleGradient;
    switch (participant.role) {
      case Role.trainer:
        roleGradient = AppColors.trainerVideoGradient;
        break;
      case Role.nutritionist:
        roleGradient = AppColors.nutritionistVideoGradient;
        break;
      default:
        roleGradient = AppColors.clientVideoGradient;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleGradient.colors.first.withOpacity(0.3),
            child: Icon(
              Icons.person_rounded,
              color: roleGradient.colors.first,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: roleGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    participant.role.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                participant.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: participant.muted
                    ? AppColors.red
                    : AppColors.textSecondaryOf(context),
                size: 20,
              ),
              const SizedBox(width: 8),
              Icon(
                participant.videoOff
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                color: participant.videoOff
                    ? AppColors.red
                    : AppColors.textSecondaryOf(context),
                size: 20,
              ),
              if (isHost && !participant.isHost) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onPressed: () {},
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// End Call Confirm Sheet
class _EndCallConfirmSheet extends StatelessWidget {
  final bool isHost;
  final VoidCallback onEndForMe;
  final VoidCallback onEndForAll;

  const _EndCallConfirmSheet({
    required this.isHost,
    required this.onEndForMe,
    required this.onEndForAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'End Call?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isHost
                  ? 'End call for everyone or just leave?'
                  : 'Are you sure you want to leave?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isHost)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onEndForAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'End for All',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEndForMe,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  isHost ? 'Leave Only' : 'Leave',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// End Call Summary Dialog
class _EndCallSummaryDialog extends StatelessWidget {
  final Duration duration;
  final int participantsCount;
  final VoidCallback onClose;

  const _EndCallSummaryDialog({
    required this.duration,
    required this.participantsCount,
    required this.onClose,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.stepsGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Call Ended',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryItem(
                  icon: Icons.access_time_rounded,
                  label: 'Duration',
                  value: _formatDuration(duration),
                ),
                _SummaryItem(
                  icon: Icons.people_rounded,
                  label: 'Participants',
                  value: '$participantsCount',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

// Summary Item
class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.orange, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

// Chat Message
class _ChatMessage extends StatelessWidget {
  final String message;
  final String sender;
  final bool isMe;

  const _ChatMessage({
    required this.message,
    required this.sender,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.stepsGradient : null,
          color: isMe
              ? null
              : Theme.of(context).colorScheme.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                sender,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMe
                      ? Colors.white
                      : AppColors.textPrimaryOf(context),
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isMe
                    ? Colors.white
                    : AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
