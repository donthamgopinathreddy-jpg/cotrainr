import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/startup/startup_router_bridge.dart';
import '../../providers/unread_notifications_count_provider.dart';
import '../../providers/unread_video_session_notifications_provider.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/video_sessions_repository.dart';
import '../../services/profile_role_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/video_session_error_messages.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/video_sessions/video_session_card_actions.dart';
import '../../widgets/video_sessions/video_session_people_sheet.dart';
import '../../widgets/video_sessions/video_session_theme.dart';
import 'google_meet_oauth_launcher.dart';
import 'past_sessions_page.dart';
import 'schedule_session_page.dart';

/// Video Sessions with Google Meet auto-created links.
class VideoSessionsPageV2 extends ConsumerStatefulWidget {
  final Uri? uri;

  const VideoSessionsPageV2({super.key, this.uri});

  @override
  ConsumerState<VideoSessionsPageV2> createState() => _VideoSessionsPageV2State();
}

class _VideoSessionsPageV2State extends ConsumerState<VideoSessionsPageV2> {
  final _repo = VideoSessionsRepository();
  final _roleService = ProfileRoleService();
  String _userRole = 'client';
  List<VideoSession> _sessions = [];
  GoogleMeetIntegrationStatus _googleStatus =
      GoogleMeetIntegrationStatus.loading();
  bool _loading = true;
  bool _googleLoading = false;
  String? _error;

  bool get _isHost =>
      _userRole == 'trainer' || _userRole == 'nutritionist';

  bool get _googleReady =>
      _googleStatus.connected && !_googleStatus.reconnectRequired;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (mounted) _handleQueryParams();
    });
  }

  @override
  void didUpdateWidget(covariant VideoSessionsPageV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.uri?.queryParameters['google-connected'] == '1';
    final now = widget.uri?.queryParameters['google-connected'] == '1';
    if (now && !was) {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
      setState(() => _googleLoading = false);
      _refreshGoogleStatus();
      _showGoogleCallbackResult(widget.uri?.queryParameters['google_error']);
    }
  }

  /// The callback appends a diagnostic slug, never user copy.
  void _showGoogleCallbackResult(String? rawSlug) {
    if (!mounted) return;
    if (rawSlug == null || rawSlug.isEmpty) {
      showHubSnackBar(context, 'Google Meet connected');
      return;
    }
    String slug;
    try {
      slug = Uri.decodeComponent(rawSlug);
    } catch (_) {
      slug = rawSlug;
    }
    VideoSessionErrorMessages.log('googleOAuthCallback', slug);
    showHubSnackBar(context, VideoSessionErrorMessages.forOAuthSlug(slug));
  }

  void _handleQueryParams() {
    final uri = widget.uri;
    if (uri == null) return;
    final openCreate = uri.queryParameters['openCreate'] == '1';
    final clientId = uri.queryParameters['clientId'];
    if (uri.queryParameters['google-connected'] == '1') {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
      setState(() => _googleLoading = false);
      _refreshGoogleStatus();
      _showGoogleCallbackResult(uri.queryParameters['google_error']);
    }
    if (openCreate && _isHost) {
      _openCreateSession(preselectedClientId: clientId);
    }
  }

  Future<void> _refreshGoogleStatus() async {
    try {
      final status = await _repo.getGoogleMeetStatus();
      if (mounted) setState(() => _googleStatus = status);
    } catch (e, s) {
      VideoSessionErrorMessages.log('getGoogleMeetStatus', e, s);
      if (mounted) {
        setState(() {
          _googleStatus =
              GoogleMeetIntegrationStatus.unknown(lastKnown: _googleStatus);
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await _roleService.getCurrentUserRole();
      final roleLower = role?.toLowerCase() ?? 'client';
      final isHost = roleLower == 'trainer' || roleLower == 'nutritionist';
      final sessions = await _repo.listSessions();
      var google = _googleStatus;
      if (isHost) {
        try {
          google = await _repo.getGoogleMeetStatus();
        } catch (e, s) {
          VideoSessionErrorMessages.log('getGoogleMeetStatus', e, s);
          google = GoogleMeetIntegrationStatus.unknown(lastKnown: _googleStatus);
        }
      }
      unawaited(NotificationsRepository().markVideoSessionNotificationsRead());
      if (!mounted) return;
      setState(() {
        _userRole = roleLower;
        _sessions = sessions;
        _googleStatus = google;
        _loading = false;
      });
      ref.invalidate(unreadVideoSessionNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode && e is PostgrestException) {
        debugPrint(
          '[VideoSessionsPage] list failed code=${e.code} '
          'message=${e.message} details=${e.details} hint=${e.hint}',
        );
      } else {
        VideoSessionErrorMessages.log('listSessions', e);
      }
      setState(() {
        _loading = false;
        _error = VideoSessionErrorMessages.forLoadSessions(e);
      });
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await launchGoogleMeetOAuth(context, _repo);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _openCreateSession({String? preselectedClientId}) async {
    if (!_isHost) return;
    HapticFeedback.mediumImpact();
    final created = await Navigator.of(context).push<VideoSession>(
      PageRouteBuilder(
        transitionDuration: VideoSessionUi.motion(context),
        reverseTransitionDuration: VideoSessionUi.motion(context),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: ScheduleSessionPage(
                preselectedClientId: preselectedClientId,
                googleStatus: _googleStatus,
                googleConnecting: _googleLoading,
                onConnectGoogle: _connectGoogle,
                onRetryGoogleStatus: _refreshGoogleStatus,
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (created != null) {
      await _load();
      if (!mounted) return;
      showHubSnackBar(context, 'Session scheduled');
      context.push('/video/session/${created.id}');
    } else {
      await _refreshGoogleStatus();
    }
  }

  void _openPastSessions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PastSessionsPage(sessions: _past),
      ),
    );
  }

  List<VideoSession> get _upcoming =>
      _sessions.where((s) => s.isUpcoming).toList()
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  List<VideoSession> get _past =>
      _sessions.where((s) => s.isPast).toList()
        ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));

  List<VideoSession> get _pastPreview => _past.take(3).toList();

  @override
  Widget build(BuildContext context) {
    final bottomPad = _isHost ? 8.0 : 24.0;
    final title = _isHost
        ? (_userRole == 'nutritionist'
            ? 'Nutritionist Sessions'
            : 'Trainer Sessions')
        : 'Video Sessions';

    return CotrainrPopScope(
      fallbackRoute: '/home',
      child: Scaffold(
      backgroundColor: VideoSessionUi.pageBg(context),
      appBar: CotrainrAppBar(
        title: title,
        backgroundColor: VideoSessionUi.pageBg(context),
        fallbackRoute: '/home',
      ),
      bottomNavigationBar: _isHost
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Semantics(
                  button: true,
                  label: 'Schedule Session',
                  child: ElevatedButton(
                    onPressed: _openCreateSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.videoSessionsAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(VideoSessionUi.radius),
                      ),
                    ),
                    child: const Text(
                      'Schedule Session',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.videoSessionsAccent,
              ),
            )
          : RefreshIndicator(
              color: DesignTokens.videoSessionsAccent,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                  if (_isHost && !_googleReady)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _CompactGooglePrompt(
                          status: _googleStatus,
                          loading: _googleLoading,
                          onConnect: _connectGoogle,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Upcoming',
                        style: VideoSessionUi.sectionLabel(context).copyWith(
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  if (_upcoming.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _EmptyCard(
                          title: 'No sessions scheduled',
                          body: _isHost
                              ? 'Schedule a video session with a connected client.'
                              : 'Your trainer or nutritionist can schedule sessions here.',
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final s = _upcoming[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _UpcomingSessionCard(
                              session: s,
                              myUserId: Supabase
                                  .instance.client.auth.currentUser?.id,
                              onDetails: () =>
                                  context.push('/video/session/${s.id}'),
                              onJoin: s.canJoin
                                  ? () => _openJoinUrl(s.joinUrl)
                                  : null,
                            ),
                          );
                        },
                        childCount: _upcoming.length,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Past',
                        style: VideoSessionUi.sectionLabel(context).copyWith(
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  if (_past.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                        child: Text(
                          'No past sessions yet.',
                          style: TextStyle(
                            color: VideoSessionUi.secondaryText(context),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final s = _pastPreview[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: PastSessionRow(
                              session: s,
                              onTap: () =>
                                  context.push('/video/session/${s.id}'),
                            ),
                          );
                        },
                        childCount: _pastPreview.length,
                      ),
                    ),
                    if (_past.length > 3)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openPastSessions,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    DesignTokens.videoSessionsAccent,
                                minimumSize: const Size(48, 44),
                              ),
                              child: const Text(
                                'View all past sessions',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                ],
              ),
            ),
    ),
    );
  }

  Future<void> _openJoinUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showHubSnackBar(context, 'Invalid meeting link');
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) showHubSnackBar(context, 'Could not open meeting link');
    }
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: VideoSessionUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: VideoSessionUi.secondaryText(context)),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSessionCard extends StatelessWidget {
  final VideoSession session;
  final VoidCallback onDetails;
  final VoidCallback? onJoin;
  final String? myUserId;

  const _UpcomingSessionCard({
    required this.session,
    required this.onDetails,
    this.onJoin,
    this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final when = _formatWhen(session.scheduledStart);
    final status = videoSessionMeaningfulStatus(session);

    return Material(
      color: VideoSessionUi.cardBg(context),
      borderRadius: BorderRadius.circular(VideoSessionUi.radius),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(VideoSessionUi.radius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VideoSessionUi.radius),
            border: Border.all(color: VideoSessionUi.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status != null)
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: videoSessionStatusColor(context, status),
                      ),
                    ),
                ],
              ),
              VideoSessionWithLine(session: session, myUserId: myUserId),
              const SizedBox(height: 4),
              Text(
                '$when · ${session.durationMinutes} min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.78),
                ),
              ),
              if (!session.hasRejected && session.isTooEarlyToJoin)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Available 5 min before',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.videoSessionsAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              VideoSessionCardActionRow(
                onJoin: session.hasRejected ? null : onJoin,
                onDetails: onDetails,
                outlineColor: cs.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final time = DateFormat('h:mm a').format(local);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Today · $time';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow · $time';
    return '${DateFormat('d MMM yyyy').format(local)} · $time';
  }
}

class _CompactGooglePrompt extends StatelessWidget {
  final GoogleMeetIntegrationStatus status;
  final bool loading;
  final VoidCallback onConnect;

  const _CompactGooglePrompt({
    required this.status,
    required this.loading,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: VideoSessionUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect Google Meet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            status.reconnectRequired
                ? 'Reconnect Google Meet to schedule sessions.'
                : 'Connect Google Meet to create session links automatically.',
            style: TextStyle(
              fontSize: 13,
              color: VideoSessionUi.secondaryText(context),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: loading ? null : onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.videoSessionsAccent,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(
                loading
                    ? 'Connecting…'
                    : status.reconnectRequired
                        ? 'Reconnect Google Meet'
                        : 'Connect Google Meet',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
