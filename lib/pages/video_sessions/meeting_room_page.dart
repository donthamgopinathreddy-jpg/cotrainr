import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/video_session_models.dart';
import '../../services/meeting_storage_service.dart';
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
  bool _isControllerInitialized = false;
  final MeetingStorageService _meetingStorage = MeetingStorageService();
  Meeting? _currentMeeting;
  Timer? _durationCheckTimer;
  // State
  bool _micOn = true;
  bool _videoOn = true;
  bool _handRaised = false;
  bool _chatOpen = false;
  String _speakerRoute = 'Auto';
  String _layoutMode = 'Grid'; // 'Grid' or 'ActiveSpeaker'
  String? _pinnedUserId;
  String? _activeSpeakerId;
  bool _isLive = true;
  Duration _meetingDuration = Duration.zero; // Start from 00:00
  DateTime? _meetingStartTime;
  int _raisedHandsCount = 0;
  int _unreadChatCount = 0;
  bool _backgroundBlur = false;
  bool _isRecording = false;
  bool _isScreenSharing = false;
  String _cameraPosition = 'front'; // 'front' or 'back'
  String _connectionStatus = 'good'; // 'good', 'poor', 'bad'
  String? _lastChatMessage;
  String? _lastChatSender;
  final List<Map<String, String>> _chatMessages = [];
  final Map<String, List<Map<String, String>>> _privateChats = {}; // userId -> messages
  String? _currentChatRecipient; // null = group chat, userId = private chat
  final TextEditingController _chatInputController = TextEditingController();

  // Participants (mock data - up to 10)
  final List<Participant> _participants = [];
  int _participantsCount = 4;
  bool _isHost = true;
  Role _userRole = Role.client; // Current user's role

  // Animation Controllers
  late AnimationController _pageEnterController;
  late AnimationController _topBarController;
  late AnimationController _dockController;
  late AnimationController _handBadgeController;
  late AnimationController _speakingIndicatorController;
  late AnimationController _pulseController;
  late AnimationController _chatToastController;
  late AnimationController _recordingBlinkController;
  late PageController _gridPageController;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pageEnterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _topBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _handBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _speakingIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _recordingBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _isControllerInitialized = true;
    // Don't start repeating immediately - only when recording starts
    _chatToastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _gridPageController = PageController();

    // Start animations
    _pageEnterController.forward();
    _topBarController.forward();
    _dockController.forward();

    // Get meeting details
    _loadMeetingDetails();
    
    // Initialize mock participants
    _initializeParticipants();
    
    // Set meeting start time - use existing startedAt if available, otherwise set to now
    if (_currentMeeting?.startedAt != null) {
      _meetingStartTime = _currentMeeting!.startedAt;
    } else {
      // First time entering - set start time and save it
      _meetingStartTime = DateTime.now();
      if (_currentMeeting != null) {
        _meetingStorage.setMeetingStartedAt(_currentMeeting!.meetingId, _meetingStartTime!);
      }
    }
    _startMeetingTimer();
    
    // Start duration check timer (check every minute)
    _durationCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkMeetingDuration();
    });
    
    // Mock active speaker
    _activeSpeakerId = _participants[1].userId;
  }

  void _loadMeetingDetails() {
    try {
      _currentMeeting = _meetingStorage.allMeetings.firstWhere(
        (m) => m.shareKey == widget.meetingId,
        orElse: () => _meetingStorage.allMeetings.firstWhere(
          (m) => m.meetingId == widget.meetingId,
        ),
      );
      
      // If meeting is live but doesn't have a startedAt time, set it now
      if (_currentMeeting != null && 
          _currentMeeting!.status == MeetingStatus.live && 
          _currentMeeting!.startedAt == null) {
        _meetingStorage.setMeetingStartedAt(_currentMeeting!.meetingId, DateTime.now());
        _currentMeeting = _meetingStorage.getMeetingById(_currentMeeting!.meetingId);
      }
    } catch (e) {
      // Meeting not found, use defaults
      _currentMeeting = null;
    }
  }

  void _checkMeetingDuration() {
    if (_currentMeeting?.durationMins == null || !_isHost) return;
    
    final elapsedMinutes = _meetingDuration.inMinutes;
    final scheduledDuration = _currentMeeting!.durationMins!;
    
    if (elapsedMinutes >= scheduledDuration) {
      // Meeting duration reached - notify host
      _showDurationReachedDialog();
    }
  }

  void _showDurationReachedDialog() {
    if (!_isHost) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DurationReachedDialog(
        onEnd: () {
          Navigator.pop(context);
          _showEndCallConfirm();
        },
        onContinue: () {
          Navigator.pop(context);
        },
        gradient: _roleGradient,
      ),
    );
  }

  LinearGradient get _roleGradient {
    // Use purple gradient for all video sessions
    return const LinearGradient(
      colors: [AppColors.purple, Color(0xFFB38CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _initializeParticipants() {
    _participants.clear();
    _participants.addAll([
      Participant(
        userId: 'self',
        displayName: 'You',
        role: _userRole,
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

  void _updateCurrentUserParticipant() {
    final index = _participants.indexWhere((p) => p.userId == 'self');
    if (index != -1) {
      final currentParticipant = _participants[index];
      _participants[index] = Participant(
        userId: currentParticipant.userId,
        displayName: currentParticipant.displayName,
        role: currentParticipant.role,
        avatarUrl: currentParticipant.avatarUrl,
        isHost: currentParticipant.isHost,
        joinedAt: currentParticipant.joinedAt,
        muted: !_micOn,
        videoOff: !_videoOn,
      );
    }
  }

  void _startMeetingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _meetingStartTime != null) {
        setState(() {
          _meetingDuration = DateTime.now().difference(_meetingStartTime!);
        });
        _startMeetingTimer();
      }
    });
  }

  @override
  void dispose() {
    _durationCheckTimer?.cancel();
    _pageEnterController.dispose();
    _topBarController.dispose();
    _dockController.dispose();
    _handBadgeController.dispose();
    _speakingIndicatorController.dispose();
    _pulseController.dispose();
    _chatToastController.dispose();
    _recordingBlinkController.dispose();
    _gridPageController.dispose();
    _chatInputController.dispose();
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
      backgroundColor: isDark
          ? const Color(0xFF1A0F2E) // Purple-black mix background (not too dark)
          : const Color(0xFFF0EBFF), // Same vibrant purple background as video sessions
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1A0F2E), // Purple-black mix (lighter)
                          const Color(0xFF2D1B3D), // Purple-black mix (darker but not too dark)
                        ]
                      : [
                          const Color(0xFFF5F5F5),
                          const Color(0xFFE8E8E8),
                        ],
                ),
              ),
            ),

            // Stage Area
            _buildStageArea(),

            // Network Poor Banner
            if (_connectionStatus != 'good') _buildNetworkBanner(),

            // Top Bar (48h)
            _buildTopBar(),

            // Raise Hand Queue Chip (Top Right)
            if (_raisedHandsCount > 0 && _isHost) _buildRaiseHandChip(),

            // Bottom Dock (72-84h)
            _buildBottomDock(),

            // Chat Toast Preview
            if (_lastChatMessage != null && !_chatOpen) _buildChatToast(),

            // Chat Overlay
            if (_chatOpen) _buildChatOverlay(),
          ],
        ),
      ),
    );
  }


  Widget _buildStageArea() {
    if (_layoutMode == 'ActiveSpeaker' && _activeSpeakerId != null) {
      return _buildActiveSpeakerView();
    }
    return _buildGridArea();
  }

  Widget _buildActiveSpeakerView() {
    final activeParticipant = _participants.firstWhere(
      (p) => p.userId == _activeSpeakerId,
      orElse: () => _participants[0],
    );

    return Positioned.fill(
      top: 72, // Updated to match new header height
      bottom: 100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _ParticipantTile(
          participant: activeParticipant,
          isPinned: _pinnedUserId == activeParticipant.userId,
          isSpeaking: true,
          isActiveSpeaker: true,
          handRaised: activeParticipant.userId == 'self' ? _handRaised : false,
          gradient: _roleGradient,
          onLongPress: _isHost ? () {
            HapticFeedback.mediumImpact();
            _showParticipantActions(activeParticipant);
          } : null,
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    final gridColumns = _getGridColumns(_participantsCount);
    final gridRows = _getGridRows(_participantsCount);
    final pages = _getPagesFor10();

    return Positioned.fill(
      top: 72, // Updated to match new header height
      bottom: 100,
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
            isSpeaking: participant.userId == _activeSpeakerId,
            isActiveSpeaker: participant.userId == _activeSpeakerId,
            handRaised: participant.userId == 'self' ? _handRaised : false,
            gradient: _roleGradient,
            onLongPress: _isHost ? () {
              HapticFeedback.mediumImpact();
              _showParticipantActions(participant);
            } : null,
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
                      isSpeaking: participant.userId == _activeSpeakerId,
                      isActiveSpeaker: participant.userId == _activeSpeakerId,
                      handRaised: participant.userId == 'self' ? _handRaised : false,
                      gradient: _roleGradient,
                      onLongPress: _isHost ? () {
                        HapticFeedback.mediumImpact();
                        _showParticipantActions(participant);
                      } : null,
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
                          ? _roleGradient.colors.first
                          : _roleGradient.colors.first.withOpacity(0.3),
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
          height: 72, // Increased header size
          child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.pop();
                },
              ),
              const SizedBox(width: 8),

              // Meeting Code + Timer + Date/Time
              Expanded(
                child: _MeetingInfoChip(
                  meetingId: widget.meetingId,
                  isLive: _isLive,
                  duration: _meetingDuration,
                ),
              ),

              const SizedBox(width: 8),

              // Screen Sharing Badge (Red) - Icon only (reduced size)
              if (_isScreenSharing)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.screen_share_rounded, size: 12, color: Colors.white),
                ),

              // Recording Badge (Red) - Blinking red dot
              if (_isRecording && _isControllerInitialized)
                AnimatedBuilder(
                  animation: _recordingBlinkController,
                  builder: (context, child) {
                    // Calculate blinking opacity (fade in and out)
                    final opacity = (_recordingBlinkController.value < 0.5)
                        ? _recordingBlinkController.value * 2
                        : 2 - (_recordingBlinkController.value * 2);
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                )
              else if (_isRecording)
                // Fallback: show solid dot if controller not initialized yet
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),

              // Connection Indicator
              _ConnectionIndicator(status: _connectionStatus),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkBanner() {
    return Positioned(
      top: 48,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Poor network connection',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaiseHandChip() {
    return Positioned(
      top: 56,
      right: 12,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showParticipantsSheet();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: _roleGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.back_hand_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '$_raisedHandsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildBottomDock() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _dockController,
          curve: Curves.easeOut,
        )),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 84,
              maxHeight: 84,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic Toggle
                  _DockButton(
                    icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    isActive: _micOn,
                    isOff: !_micOn,
                    gradient: _roleGradient,
                    onTap: () {
                      setState(() {
                        _micOn = !_micOn;
                        // Update current user's participant state
                        _updateCurrentUserParticipant();
                      });
                      HapticFeedback.selectionClick();
                    },
                  ),

                  // Camera Toggle
                  _DockButton(
                    icon: _videoOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    isActive: _videoOn,
                    isOff: !_videoOn,
                    gradient: _roleGradient,
                    onTap: () {
                      setState(() {
                        _videoOn = !_videoOn;
                        // Update current user's participant state
                        _updateCurrentUserParticipant();
                      });
                      HapticFeedback.selectionClick();
                    },
                  ),

                  // End Call (Center - Big Red Pill)
                  _EndCallButton(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _showEndCallConfirm();
                    },
                  ),

                  // More (3 dots)
                  _DockButton(
                    icon: Icons.more_vert_rounded,
                    isActive: false,
                    gradient: _roleGradient,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _showThreeDotsMenu();
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

  Widget _buildChatToast() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _chatToastController,
          curve: Curves.easeOut,
        )),
        child: GestureDetector(
          onTap: () {
            setState(() => _chatOpen = true);
            HapticFeedback.mediumImpact();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.purple.withOpacity(0.2)
                  : AppColors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              boxShadow: DesignTokens.cardShadowOf(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: _roleGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _lastChatSender ?? 'Someone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastChatMessage ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
                      if (_currentChatRecipient != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () {
                            setState(() => _currentChatRecipient = null);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentChatRecipient == null
                                  ? 'Group Chat'
                                  : _participants
                                      .firstWhere(
                                        (p) => p.userId == _currentChatRecipient,
                                        orElse: () => _participants[0],
                                      )
                                      .displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            if (_currentChatRecipient == null)
                              Text(
                                '${_participants.length} participants',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.people_rounded),
                        onPressed: () {
                          _showChatParticipantsSelector();
                          HapticFeedback.selectionClick();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() {
                            _chatOpen = false;
                            _currentChatRecipient = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Messages List
                Expanded(
                  child: _getCurrentChatMessages().isEmpty
                      ? Center(
                          child: Text(
                            _currentChatRecipient == null
                                ? 'No messages yet'
                                : 'No messages with this participant yet',
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _getCurrentChatMessages().length,
                          itemBuilder: (context, index) {
                            final msg = _getCurrentChatMessages()[index];
                            return _ChatMessage(
                              message: msg['message'] ?? '',
                              sender: msg['sender'] ?? '',
                              isMe: msg['isMe'] == 'true',
                              gradient: _roleGradient,
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
                          controller: _chatInputController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: DesignTokens.borderColorOf(context),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.purple,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.background,
                          ),
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: _roleGradient,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, size: 20),
                          color: Colors.white,
                          onPressed: () {
                            if (_chatInputController.text.trim().isNotEmpty) {
                              setState(() {
                                final message = {
                                  'message': _chatInputController.text.trim(),
                                  'sender': 'You',
                                  'isMe': 'true',
                                };
                                
                                if (_currentChatRecipient == null) {
                                  // Group chat
                                  _chatMessages.add(message);
                                } else {
                                  // Private chat
                                  if (!_privateChats.containsKey(_currentChatRecipient)) {
                                    _privateChats[_currentChatRecipient!] = [];
                                  }
                                  _privateChats[_currentChatRecipient!]!.add(message);
                                }
                                
                                _lastChatMessage = _chatInputController.text.trim();
                                _lastChatSender = 'You';
                                _chatInputController.clear();
                                if (!_chatOpen) {
                                  _chatToastController.forward(from: 0);
                                  Future.delayed(const Duration(seconds: 3), () {
                                    if (mounted) {
                                      _chatToastController.reverse();
                                    }
                                  });
                                }
                              });
                              HapticFeedback.selectionClick();
                            }
                          },
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
        layoutMode: _layoutMode,
        backgroundBlur: _backgroundBlur,
        isRecording: _isRecording,
        isScreenSharing: _isScreenSharing,
        cameraPosition: _cameraPosition,
        isHost: _isHost,
        gradient: _roleGradient,
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
        onSwitchCamera: () {
          setState(() {
            _cameraPosition = _cameraPosition == 'front' ? 'back' : 'front';
          });
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onScreenShare: () {
          setState(() => _isScreenSharing = !_isScreenSharing);
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
        onRecord: () {
          setState(() {
            _isRecording = !_isRecording;
            if (_isRecording) {
              _recordingBlinkController.repeat();
            } else {
              _recordingBlinkController.stop();
              _recordingBlinkController.reset();
            }
          });
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
        onLayoutSwitch: () {
          setState(() {
            _layoutMode = _layoutMode == 'Grid' ? 'ActiveSpeaker' : 'Grid';
          });
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onBackgroundBlur: () {
          setState(() => _backgroundBlur = !_backgroundBlur);
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onChat: () {
          setState(() {
            _chatOpen = !_chatOpen;
            if (_chatOpen) _unreadChatCount = 0;
          });
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
        onParticipants: () {
          Navigator.pop(context);
          _showParticipantsSheet();
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
        gradient: _roleGradient,
        onRouteSelected: (route) {
          setState(() => _speakerRoute = route);
          HapticFeedback.selectionClick();
          Navigator.pop(context); // Close speaker route sheet
          _showThreeDotsMenu(); // Show 3-dots menu again instead of closing
        },
        onBack: () {
          Navigator.pop(context); // Close speaker route sheet
          _showThreeDotsMenu(); // Show 3-dots menu again
        },
      ),
    );
  }

  List<Map<String, String>> _getCurrentChatMessages() {
    if (_currentChatRecipient == null) {
      return _chatMessages;
    } else {
      return _privateChats[_currentChatRecipient] ?? [];
    }
  }

  void _showChatParticipantsSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatParticipantsSelector(
        participants: _participants,
        currentRecipient: _currentChatRecipient,
        onSelectRecipient: (userId) {
          if (userId != null) {
            setState(() {
              _currentChatRecipient = userId;
              if (!_privateChats.containsKey(userId)) {
                _privateChats[userId] = [];
              }
            });
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          }
        },
        onSelectGroup: () {
          setState(() => _currentChatRecipient = null);
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
          gradient: _roleGradient,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showParticipantActions(Participant participant) {
    // Only host can access participant actions
    if (!_isHost) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ParticipantActionsSheet(
        participant: participant,
        isHost: _isHost,
        isPinned: _pinnedUserId == participant.userId,
        onPin: () {
          setState(() {
            _pinnedUserId = _pinnedUserId == participant.userId ? null : participant.userId;
          });
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onSpotlight: () {
          setState(() {
            // Spotlight: Make this participant the active speaker
            _activeSpeakerId = participant.userId;
            _layoutMode = 'ActiveSpeaker';
          });
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
        onMute: () {
          setState(() {
            // Toggle mute for the participant
            final index = _participants.indexWhere((p) => p.userId == participant.userId);
            if (index != -1) {
              final currentParticipant = _participants[index];
              _participants[index] = Participant(
                userId: currentParticipant.userId,
                displayName: currentParticipant.displayName,
                role: currentParticipant.role,
                avatarUrl: currentParticipant.avatarUrl,
                isHost: currentParticipant.isHost,
                joinedAt: currentParticipant.joinedAt,
                muted: !currentParticipant.muted,
                videoOff: currentParticipant.videoOff,
              );
            }
          });
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
        onRemove: () {
          setState(() {
            // Remove participant from the meeting
            _participants.removeWhere((p) => p.userId == participant.userId);
            _participantsCount = _participants.length;
            // If removed participant was pinned or active speaker, clear it
            if (_pinnedUserId == participant.userId) {
              _pinnedUserId = null;
            }
            if (_activeSpeakerId == participant.userId) {
              _activeSpeakerId = _participants.isNotEmpty ? _participants[0].userId : null;
            }
          });
          HapticFeedback.heavyImpact();
          Navigator.pop(context);
        },
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
          _endMeetingForUser();
          context.pop();
        },
        onEndForAll: () {
          Navigator.pop(context);
          _endMeetingForAll();
          _showEndCallSummary();
        },
      ),
    );
  }

  void _endMeetingForUser() {
    // Mark meeting as ended when user leaves
    try {
      final meeting = _meetingStorage.allMeetings.firstWhere(
        (m) => m.shareKey == widget.meetingId,
        orElse: () => _meetingStorage.allMeetings.firstWhere(
          (m) => m.meetingId == widget.meetingId,
        ),
      );
      _meetingStorage.updateMeetingStatus(meeting.meetingId, MeetingStatus.ended);
    } catch (e) {
      // Meeting not found, ignore
    }
  }

  void _endMeetingForAll() {
    // Mark meeting as ended for all participants
    try {
      final meeting = _meetingStorage.allMeetings.firstWhere(
        (m) => m.shareKey == widget.meetingId,
        orElse: () => _meetingStorage.allMeetings.firstWhere(
          (m) => m.meetingId == widget.meetingId,
        ),
      );
      _meetingStorage.updateMeetingStatus(meeting.meetingId, MeetingStatus.ended);
    } catch (e) {
      // Meeting not found, ignore
    }
  }

  void _showEndCallSummary() {
    showDialog(
      context: context,
      builder: (context) => _EndCallSummaryDialog(
        duration: _meetingDuration,
        participantsCount: _participantsCount,
        gradient: _roleGradient,
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
  final bool isActiveSpeaker;
  final bool handRaised;
  final LinearGradient gradient;
  final VoidCallback? onLongPress;

  const _ParticipantTile({
    required this.participant,
    required this.isPinned,
    required this.isSpeaking,
    required this.isActiveSpeaker,
    required this.handRaised,
    required this.gradient,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Use purple gradient for all roles
    const roleGradient = LinearGradient(
      colors: [AppColors.purple, Color(0xFFB38CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: () {
        if (onLongPress != null) {
          HapticFeedback.mediumImpact();
          onLongPress!();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.purple.withOpacity(0.15)
              : AppColors.purple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: isActiveSpeaker
              ? Border.all(
                  color: AppColors.purple,
                  width: 3,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                        color: isDark
                            ? AppColors.purple.withOpacity(0.2)
                            : AppColors.purple.withOpacity(0.15),
                        child: Center(
                          child: Icon(
                            Icons.videocam_rounded,
                            size: 48,
                            color: AppColors.purple,
                          ),
                        ),
                      ),

                // Active Speaker Pulse
                if (isActiveSpeaker)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.purple.withOpacity(1 - value),
                              width: 3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Name and Role Chips (Bottom Left)
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.6)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        participant.displayName,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                              gradient: gradient,
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

                // Muted Mic Icon (Top Right - Red) with animation
                if (participant.muted)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value,
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
                        );
                      },
                    ),
                  ),
                

                // Pin Button (Top Left)
                if (isPinned)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.purple, Color(0xFFB38CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                // Hand Raised Badge
                if (handRaised)
                  Positioned(
                    top: 8,
                    left: isPinned ? 40 : 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: gradient,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.5)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meeting ID (without red dot)
          Text(
            meetingId,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          // Meeting Timer below the ID
          Text(
            _formatDuration(duration),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Connection Indicator
class _ConnectionIndicator extends StatelessWidget {
  final String status;

  const _ConnectionIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case 'poor':
        color = AppColors.yellow;
        icon = Icons.signal_cellular_alt_2_bar_rounded;
        break;
      case 'bad':
        color = AppColors.red;
        icon = Icons.signal_cellular_off_rounded;
        break;
      default:
        color = AppColors.purple;
        icon = Icons.signal_cellular_alt_rounded;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.5)
            : Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
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
  final LinearGradient gradient;

  const _DockButton({
    required this.icon,
    required this.isActive,
    this.isOff = false,
    required this.onTap,
    this.badge,
    required this.gradient,
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
                ? widget.gradient
                : null,
            color: widget.isOff
                ? AppColors.red.withOpacity(0.3)
                : widget.isActive
                    ? null
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.15) // More subtle like 3-dot menu
                        : AppColors.purple.withOpacity(0.08), // More subtle like 3-dot menu
            borderRadius: BorderRadius.circular(18),
            border: widget.isActive || widget.isOff
                ? null
                : Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : AppColors.purple.withOpacity(0.15),
                    width: 1,
                  ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isActive
                    ? Colors.white
                    : widget.isOff
                        ? AppColors.red
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.9) // More subtle like 3-dot menu
                            : AppColors.purple.withOpacity(0.8), // More subtle like 3-dot menu
                size: 24,
              ),
              if (widget.badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.badge!,
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
    );
  }
}

// End Call Button (Big Red Pill)
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
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
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
  final String layoutMode;
  final bool backgroundBlur;
  final bool isRecording;
  final bool isScreenSharing;
  final String cameraPosition;
  final bool isHost;
  final LinearGradient gradient;
  final VoidCallback onHandRaise;
  final VoidCallback onSpeakerRoute;
  final VoidCallback onSwitchCamera;
  final VoidCallback onScreenShare;
  final VoidCallback onRecord;
  final VoidCallback onLayoutSwitch;
  final VoidCallback onBackgroundBlur;
  final VoidCallback onChat;
  final VoidCallback onParticipants;

  const _ThreeDotsMenuSheet({
    required this.handRaised,
    required this.speakerRoute,
    required this.layoutMode,
    required this.backgroundBlur,
    required this.isRecording,
    required this.isScreenSharing,
    required this.cameraPosition,
    required this.isHost,
    required this.gradient,
    required this.onHandRaise,
    required this.onSpeakerRoute,
    required this.onSwitchCamera,
    required this.onScreenShare,
    required this.onRecord,
    required this.onLayoutSwitch,
    required this.onBackgroundBlur,
    required this.onChat,
    required this.onParticipants,
  });

  IconData _getSpeakerRouteIcon(String route) {
    switch (route) {
      case 'Auto':
        return Icons.tune_rounded;
      case 'Earpiece':
        return Icons.hearing_rounded; // Ear icon for earpiece
      case 'Speaker':
        return Icons.volume_up_rounded;
      case 'Bluetooth':
        return Icons.bluetooth_rounded;
      default:
        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
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
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary Actions Row - Speaker, Raise Hand, and Switch Camera (equal size boxes)
                      Row(
                        children: [
                          Expanded(
                            child: _MenuAction(
                              icon: _getSpeakerRouteIcon(speakerRoute), // Dynamic icon based on selected route
                              label: speakerRoute, // Dynamic label based on selected route
                              subtitle: null, // Remove subtitle since label now shows the route
                              isActive: speakerRoute != 'Auto',
                              gradient: gradient,
                              onTap: onSpeakerRoute,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MenuAction(
                              icon: handRaised
                                  ? Icons.back_hand_rounded
                                  : Icons.back_hand_outlined,
                              label: 'Raise Hand',
                              isActive: handRaised,
                              gradient: gradient,
                              onTap: onHandRaise,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MenuAction(
                              icon: cameraPosition == 'front'
                                  ? Icons.camera_front_rounded
                                  : Icons.camera_rear_rounded,
                              label: 'Switch Camera',
                              gradient: gradient,
                              onTap: onSwitchCamera,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Secondary Actions - List Style (Chat, Screen Share, Record first)
                      _MenuListItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        gradient: gradient,
                        onTap: onChat,
                      ),
                      if (isHost || isScreenSharing) ...[
                        _MenuListItem(
                          icon: Icons.screen_share_rounded,
                          label: 'Screen Share',
                          isActive: isScreenSharing,
                          gradient: gradient,
                          onTap: onScreenShare,
                        ),
                      ],
                      if (isHost) ...[
                        _MenuListItem(
                          icon: isRecording
                              ? Icons.circle
                              : Icons.circle_outlined,
                          label: 'Record',
                          isActive: isRecording,
                          gradient: gradient,
                          onTap: onRecord,
                        ),
                      ],
                      // Other options
                      _MenuListItem(
                        icon: Icons.people_rounded,
                        label: 'Participants',
                        gradient: gradient,
                        onTap: onParticipants,
                      ),
                      _MenuListItem(
                        icon: layoutMode == 'Grid'
                            ? Icons.grid_view_rounded
                            : Icons.person_rounded,
                        label: layoutMode == 'Grid' ? 'Active Speaker View' : 'Grid View',
                        gradient: gradient,
                        onTap: onLayoutSwitch,
                      ),
                      _MenuListItem(
                        icon: backgroundBlur
                            ? Icons.blur_on_rounded
                            : Icons.blur_off_rounded,
                        label: 'Background Blur',
                        isActive: backgroundBlur,
                        gradient: gradient,
                        onTap: onBackgroundBlur,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Menu Action
class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isActive;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    this.subtitle,
    this.isActive = false,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isActive ? gradient : null,
                  color: isActive
                      ? null
                      : AppColors.purple.withOpacity(0.15), // Purple background instead of grey
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : AppColors.purple, // Purple icon color when not active
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32, // Fixed height for text area to prevent overlapping
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? gradient.colors.first
                          : AppColors.textPrimaryOf(context),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Allow 2 lines for "Raise Hand" and "Switch Camera"
                    overflow: TextOverflow.clip, // Clip overflow
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Simple Menu Action (no boxes, just icon and label)
class _SimpleMenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isActive;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _SimpleMenuAction({
    required this.icon,
    required this.label,
    this.subtitle,
    this.isActive = false,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? gradient.colors.first
                    : AppColors.textSecondaryOf(context),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? gradient.colors.first
                      : AppColors.textSecondaryOf(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Menu List Item
class _MenuListItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _MenuListItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.gradient,
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isActive
                ? gradient.colors.first.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: isActive ? gradient : null,
                  color: isActive
                      ? null
                      : AppColors.purple.withOpacity(0.15), // Purple background instead of grey
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : AppColors.purple, // Purple icon color when not active
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? gradient.colors.first
                        : AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_circle_rounded,
                  color: gradient.colors.first,
                  size: 20,
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
  final LinearGradient gradient;
  final ValueChanged<String> onRouteSelected;
  final VoidCallback onBack;

  const _SpeakerRouteSheet({
    required this.currentRoute,
    required this.gradient,
    required this.onRouteSelected,
    required this.onBack,
  });

  IconData _getRouteIcon(String route) {
    switch (route) {
      case 'Auto':
        return Icons.tune_rounded; // Better understood icon for Auto
      case 'Earpiece':
        return Icons.hearing_rounded; // Ear icon for earpiece
      case 'Speaker':
        return Icons.volume_up_rounded;
      case 'Bluetooth':
        return Icons.bluetooth_rounded;
      default:
        return Icons.tune_rounded;
    }
  }

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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      color: AppColors.textPrimaryOf(context),
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        'Audio Route',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: routes.map((route) => _RouteOption(
                        route: route,
                        icon: _getRouteIcon(route),
                        isSelected: route == currentRoute,
                        gradient: gradient,
                        onTap: () => onRouteSelected(route),
                      )).toList(),
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

// Route Option
class _RouteOption extends StatelessWidget {
  final String route;
  final IconData icon;
  final bool isSelected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _RouteOption({
    required this.route,
    required this.icon,
    required this.isSelected,
    required this.gradient,
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: isSelected ? gradient : null,
            color: isSelected
                ? null
                : AppColors.purple.withOpacity(0.15),
            shape: BoxShape.circle,
            // Border removed as requested
          ),
          child: Icon(
            icon,
            color: isSelected
                ? Colors.white
                : AppColors.purple,
            size: 28,
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
  final LinearGradient gradient;
  final ScrollController scrollController;

  const _ParticipantsSheet({
    required this.participants,
    required this.isHost,
    required this.raisedHandsCount,
    required this.gradient,
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
                  gradient: gradient,
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
    // Different colors for different roles
    LinearGradient roleGradient;
    switch (participant.role) {
      case Role.trainer:
        roleGradient = const LinearGradient(
          colors: [AppColors.red, Color(0xFFFF7A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case Role.nutritionist:
        roleGradient = const LinearGradient(
          colors: [AppColors.green, Color(0xFF65E6B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      default:
        roleGradient = const LinearGradient(
          colors: [AppColors.purple, Color(0xFFB38CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
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

// Participant Actions Sheet
class _ParticipantActionsSheet extends StatelessWidget {
  final Participant participant;
  final bool isHost;
  final bool isPinned;
  final VoidCallback onPin;
  final VoidCallback onSpotlight;
  final VoidCallback onMute;
  final VoidCallback onRemove;

  const _ParticipantActionsSheet({
    required this.participant,
    required this.isHost,
    required this.isPinned,
    required this.onPin,
    required this.onSpotlight,
    required this.onMute,
    required this.onRemove,
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
            child: Column(
              children: [
                Text(
                  participant.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionItem(
                  icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  label: isPinned ? 'Unpin' : 'Pin',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPin();
                  },
                ),
                if (isHost) ...[
                  _ActionItem(
                    icon: Icons.star_rounded,
                    label: 'Spotlight',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onSpotlight();
                    },
                  ),
                  _ActionItem(
                    icon: participant.muted ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: participant.muted ? 'Unmute' : 'Mute',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onMute();
                    },
                  ),
                  _ActionItem(
                    icon: Icons.person_remove_rounded,
                    label: 'Remove',
                    isDanger: true,
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      onRemove();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Action Item
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
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
          child: Row(
            children: [
              Icon(
                icon,
                color: isDanger ? AppColors.red : AppColors.textPrimaryOf(context),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDanger ? AppColors.red : AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
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
                  side: const BorderSide(color: AppColors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  isHost ? 'Leave Only' : 'Leave',
                  style: const TextStyle(
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
  final LinearGradient gradient;
  final VoidCallback onClose;

  const _EndCallSummaryDialog({
    required this.duration,
    required this.participantsCount,
    required this.gradient,
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
                gradient: gradient,
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
                  gradient: gradient,
                ),
                _SummaryItem(
                  icon: Icons.people_rounded,
                  label: 'Participants',
                  value: '$participantsCount',
                  gradient: gradient,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gradient.colors.first,
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

// Duration Reached Dialog
class _DurationReachedDialog extends StatelessWidget {
  final VoidCallback onEnd;
  final VoidCallback onContinue;
  final LinearGradient gradient;

  const _DurationReachedDialog({
    required this.onEnd,
    required this.onContinue,
    required this.gradient,
  });

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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Meeting Time Reached',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The scheduled meeting duration has been reached. Would you like to end the meeting or continue?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onEnd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'End Meeting',
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
                onPressed: onContinue,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: gradient.colors.first),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Continue Meeting',
                  style: TextStyle(
                    color: gradient.colors.first,
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
  final LinearGradient gradient;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: gradient.colors.first, size: 24),
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

// Chat Participants Selector
class _ChatParticipantsSelector extends StatelessWidget {
  final List<Participant> participants;
  final String? currentRecipient;
  final ValueChanged<String?> onSelectRecipient;
  final VoidCallback onSelectGroup;

  const _ChatParticipantsSelector({
    required this.participants,
    required this.currentRecipient,
    required this.onSelectRecipient,
    required this.onSelectGroup,
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
            child: Text(
              'Select Chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
          // Group Chat Option
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSelectGroup,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: currentRecipient == null
                      ? AppColors.purple.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.purple, Color(0xFFB38CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.group_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          Text(
                            'All participants',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentRecipient == null)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.purple,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 8),
          // Individual Participants
          ...participants.where((p) => p.userId != 'self').map((participant) {
            // Get role gradient
            LinearGradient roleGradient;
            switch (participant.role) {
              case Role.trainer:
                roleGradient = const LinearGradient(
                  colors: [AppColors.red, Color(0xFFFF7A7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );
                break;
              case Role.nutritionist:
                roleGradient = const LinearGradient(
                  colors: [AppColors.green, Color(0xFF65E6B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );
                break;
              default:
                roleGradient = const LinearGradient(
                  colors: [AppColors.purple, Color(0xFFB38CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelectRecipient(participant.userId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentRecipient == participant.userId
                        ? roleGradient.colors.first.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: roleGradient.colors.first.withOpacity(0.3),
                        child: Icon(
                          Icons.person_rounded,
                          color: roleGradient.colors.first,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  participant.displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                if (participant.isHost) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.purple, Color(0xFFB38CFF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
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
                                ],
                              ],
                            ),
                            Text(
                              participant.role.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentRecipient == participant.userId)
                        Icon(
                          Icons.check_circle_rounded,
                          color: roleGradient.colors.first,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Chat Message
class _ChatMessage extends StatelessWidget {
  final String message;
  final String sender;
  final bool isMe;
  final LinearGradient gradient;

  const _ChatMessage({
    required this.message,
    required this.sender,
    required this.isMe,
    required this.gradient,
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
          gradient: isMe ? gradient : null,
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
