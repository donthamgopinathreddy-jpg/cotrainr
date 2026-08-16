import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/startup/startup_router_bridge.dart';
import '../../repositories/video_sessions_repository.dart';
import '../../services/profile_role_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import 'create_session_sheet.dart';

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
      GoogleMeetIntegrationStatus.disconnected();
  bool _loading = true;
  bool _googleLoading = false;
  String? _error;

  bool get _isHost =>
      _userRole == 'trainer' || _userRole == 'nutritionist';

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
      final err = widget.uri?.queryParameters['google_error'];
      if (err != null && err.isNotEmpty && mounted) {
        showHubSnackBar(context, 'Google Meet: ${Uri.decodeComponent(err)}');
      } else if (mounted) {
        showHubSnackBar(context, 'Google Meet connected');
      }
    }
  }

  void _handleQueryParams() {
    final uri = widget.uri;
    if (uri == null) return;
    final openCreate = uri.queryParameters['openCreate'] == '1';
    final openJoin = uri.queryParameters['openJoin'] == '1';
    final clientId = uri.queryParameters['clientId'];
    if (uri.queryParameters['google-connected'] == '1') {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
      setState(() => _googleLoading = false);
      _refreshGoogleStatus();
      final err = uri.queryParameters['google_error'];
      if (err != null && err.isNotEmpty && mounted) {
        showHubSnackBar(context, 'Google Meet: ${Uri.decodeComponent(err)}');
      } else if (mounted) {
        showHubSnackBar(context, 'Google Meet connected');
      }
    }
    if (openCreate && _isHost) {
      _openCreateSession(preselectedClientId: clientId);
    } else if (openJoin) {
      _showJoinWithLinkSheet(context);
    }
  }

  Future<void> _refreshGoogleStatus() async {
    if (!_isHost && _userRole.isNotEmpty) {
      // Role may not be loaded yet on first call.
    }
    try {
      final status = await _repo.getGoogleMeetStatus();
      if (mounted) setState(() => _googleStatus = status);
    } catch (_) {}
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
      GoogleMeetIntegrationStatus google =
          GoogleMeetIntegrationStatus.disconnected();
      if (isHost) {
        try {
          google = await _repo.getGoogleMeetStatus();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _userRole = roleLower;
        _sessions = sessions;
        _googleStatus = google;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      var message = 'Could not load sessions. Pull to retry.';
      if (kDebugMode && e is PostgrestException) {
        message =
            'Could not load sessions (${e.code ?? 'error'}): ${e.message}';
        debugPrint(
          '[VideoSessionsPage] list failed code=${e.code} '
          'message=${e.message} details=${e.details} hint=${e.hint}',
        );
      } else if (kDebugMode) {
        debugPrint('[VideoSessionsPage] list failed: $e');
      }
      setState(() {
        _loading = false;
        _error = message;
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

  Future<void> _disconnectGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _repo.disconnectGoogleMeet();
      await _refreshGoogleStatus();
      if (mounted) showHubSnackBar(context, 'Google Meet disconnected');
    } catch (e) {
      if (mounted) {
        showHubSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _openCreateSession({String? preselectedClientId}) {
    if (!_isHost) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateSessionSheet(
        preselectedClientId: preselectedClientId,
        googleStatus: _googleStatus,
        googleConnecting: _googleLoading,
        onConnectGoogle: _connectGoogle,
        onCreate: (session) async {
          Navigator.pop(ctx);
          await _load();
          if (!mounted) return;
          showHubSnackBar(context, 'Session scheduled');
          context.push('/video/session/${session.id}');
        },
      ),
    );
  }

  List<VideoSession> get _upcoming =>
      _sessions.where((s) => s.isUpcoming).toList()
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  List<VideoSession> get _past =>
      _sessions.where((s) => s.isPast).toList()
        ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final me = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          _isHost
              ? (_userRole == 'nutritionist'
                  ? 'Nutritionist Sessions'
                  : 'Trainer Sessions')
              : 'Video Sessions',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: _isHost
          ? FloatingActionButton.extended(
              onPressed: _openCreateSession,
              backgroundColor: DesignTokens.accentOrange,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Schedule Session',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.accentOrange,
              ),
            )
          : RefreshIndicator(
              color: DesignTokens.accentOrange,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: AccountHubTheme.dangerRed),
                        ),
                      ),
                    ),
                  if (_isHost)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _GoogleConnectionCard(
                          status: _googleStatus,
                          loading: _googleLoading,
                          onConnect: _connectGoogle,
                          onDisconnect: _disconnectGoogle,
                        ),
                      ),
                    ),
                  if (!_isHost)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _showJoinWithLinkSheet(context),
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Join with link'),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Upcoming',
                        style: AccountHubTheme.sectionTitle(context),
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
                              ? 'Schedule a video session with a Member.'
                              : 'Your Trainer or Nutritionist can schedule sessions here.',
                          actionLabel: _isHost ? 'Schedule Session' : null,
                          onAction: _isHost ? _openCreateSession : null,
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
                            child: _SessionCard(
                              session: s,
                              isHost: s.hostId == me,
                              onTap: () =>
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
                        style: AccountHubTheme.sectionTitle(context),
                      ),
                    ),
                  ),
                  if (_past.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        child: Text(
                          'No past sessions yet.',
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final s = _past[index];
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              index == _past.length - 1 ? 96 : 10,
                            ),
                            child: _SessionCard(
                              session: s,
                              isHost: s.hostId == me,
                              compact: true,
                              onTap: () =>
                                  context.push('/video/session/${s.id}'),
                            ),
                          );
                        },
                        childCount: _past.length,
                      ),
                    ),
                ],
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
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AccountHubTheme.cardBg(context),
        borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
        boxShadow: AccountHubTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AccountHubTheme.rowTitle(context)),
          const SizedBox(height: 6),
          Text(body, style: AccountHubTheme.rowSubtitle(context)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.accentOrange,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final VideoSession session;
  final bool isHost;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  const _SessionCard({
    required this.session,
    required this.isHost,
    required this.onTap,
    this.onJoin,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final withName = session.counterpartyName ?? (isHost ? 'Member' : 'Provider');
    final when = _formatWhen(session.scheduledStart);
    final status = _statusLabel(session);
    final statusColor = _statusColor(session);

    return Material(
      color: AccountHubTheme.cardBg(context),
      borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
            boxShadow: AccountHubTheme.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: AccountHubTheme.rowTitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'with $withName',
                style: AccountHubTheme.rowSubtitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                '$when · ${session.durationMinutes} min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onJoin != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.accentOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Join'),
                        ),
                      ),
                    if (onJoin != null) const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isHost ? 'Manage' : 'Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(VideoSession s) {
    if (s.isCancelled) return 'Cancelled';
    if (s.isPast) return 'Past';
    return 'Upcoming';
  }

  Color _statusColor(VideoSession s) {
    if (s.isCancelled) return AccountHubTheme.dangerRed;
    if (s.isPast) return const Color(0xFF9CA3AF);
    return DesignTokens.accentOrange;
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

class _GoogleConnectionCard extends StatelessWidget {
  final GoogleMeetIntegrationStatus status;
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _GoogleConnectionCard({
    required this.status,
    required this.loading,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final ready = status.connected && !status.reconnectRequired;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountHubTheme.cardBg(context),
        borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
        boxShadow: AccountHubTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.videocam_outlined,
                color: ready
                    ? AccountHubTheme.goalsGreen
                    : DesignTokens.accentOrange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ready ? 'Google Meet: Connected' : 'Google Meet',
                  style: AccountHubTheme.rowTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ready
                ? (status.googleEmail ??
                    'Ready to create Meet links for sessions.')
                : status.reconnectRequired
                    ? 'Reconnect Google Meet to schedule sessions.'
                    : 'Connect Google once to create Meet links automatically.',
            style: AccountHubTheme.rowSubtitle(context),
          ),
          const SizedBox(height: 12),
          if (!ready)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.accentOrange,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  loading
                      ? 'Connecting…'
                      : status.reconnectRequired
                          ? 'Reconnect Google Meet'
                          : 'Connect Google',
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: loading ? null : onDisconnect,
                child: const Text('Disconnect'),
              ),
            ),
        ],
      ),
    );
  }
}

void _showJoinWithLinkSheet(BuildContext context) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AccountHubTheme.cardBg(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paste invite link',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Opens the meeting outside Cotrainr. This does not add the session to your list.',
                style: AccountHubTheme.rowSubtitle(ctx),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://…',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final url = controller.text.trim();
                  if (url.isEmpty) return;
                  Navigator.pop(ctx);
                  final uri = Uri.tryParse(url);
                  if (uri == null || uri.scheme.toLowerCase() != 'https') {
                    showHubSnackBar(context, 'Enter a valid https link');
                    return;
                  }
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    showHubSnackBar(context, 'Could not open link');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.accentOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open link'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
