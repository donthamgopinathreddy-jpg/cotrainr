import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../repositories/video_sessions_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../services/profile_role_service.dart';
import 'create_session_sheet.dart';

/// Video Sessions page with Zoom OAuth connection states.
/// - Trainer/Nutritionist: Connection card, Create Session (Zoom or paste link)
/// - Client: Session list (only sessions where user is participant)
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
  ZoomIntegrationStatus? _zoomStatus;
  List<VideoSession> _sessions = [];
  bool _loading = true;
  bool _zoomLoading = false;
  bool _connectZoomCardDismissed = false;

  bool get _isHost => _userRole == 'trainer' || _userRole == 'nutritionist';
  bool get _canCreateSession =>
      _userRole == 'trainer' || _userRole == 'nutritionist';
  bool get _zoomConnected =>
      _zoomStatus?.status == ZoomConnectionStatus.connected;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (mounted) _handleQueryParams();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = widget.uri;
    if (uri != null && uri.queryParameters['zoom-connected'] == '1') {
      _refreshZoomStatus();
    }
  }

  void _handleQueryParams() {
    final uri = widget.uri;
    if (uri == null) return;
    final openCreate = uri.queryParameters['openCreate'] == '1';
    final openJoin = uri.queryParameters['openJoin'] == '1';
    final clientId = uri.queryParameters['clientId'];
    final zoomError = uri.queryParameters['zoom_error'];
    if (uri.queryParameters['zoom-connected'] == '1') {
      _refreshZoomStatus();
      if (zoomError != null && zoomError.isNotEmpty && mounted) {
        final decoded = Uri.decodeComponent(zoomError);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoom: $decoded'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    if (openCreate && _canCreateSession) {
      _openCreateSession(preselectedClientId: clientId);
    } else if (openJoin) {
      _showJoinWithLinkSheet(context);
    }
  }

  Future<void> _refreshZoomStatus() async {
    try {
      final status = await _repo.getZoomStatus();
      if (mounted) {
        setState(() => _zoomStatus = status);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final role = await _roleService.getCurrentUserRole();
      final zoomStatus = await _repo.getZoomStatus();
      List<VideoSession> sessions = [];
      try {
        sessions = await _repo.listSessions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load sessions: $e')),
          );
        }
      }
      if (mounted) {
        setState(() {
          _userRole = role?.toLowerCase() ?? 'client';
          _zoomStatus = zoomStatus;
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  Future<void> _connectZoom() async {
    setState(() => _zoomLoading = true);
    try {
      final url = await _repo.getZoomOAuthUrl();
      final uri = Uri.parse(url);
      final canOpen = await canLaunchUrl(uri);
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Complete sign-in in the browser, then return here')),
          );
        }
      } else {
        // Try anyway - canLaunchUrl can be overly conservative on some devices
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Complete sign-in in the browser, then return here')),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open browser. Try again or use an external link.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoom: $msg'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _zoomLoading = false);
    }
  }

  Future<void> _disconnectZoom() async {
    setState(() => _zoomLoading = true);
    try {
      await _repo.disconnectZoom();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zoom disconnected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _zoomLoading = false);
    }
  }

  void _openCreateSession({String? preselectedClientId}) {
    if (!_canCreateSession) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateSessionSheet(
        onCreate: (session) async {
          Navigator.pop(ctx);
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invite link copied to clipboard')),
            );
            context.push('/video/session/${session.id}');
          }
        },
        preselectedClientId: preselectedClientId,
        zoomConnected: _zoomConnected,
        onConnectZoom: _connectZoom,
        zoomConnecting: _zoomLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A0F2E) : const Color(0xFFF0EBFF),
      appBar: AppBar(
        title: Text(
          _userRole == 'trainer'
              ? 'Trainer Sessions'
              : _userRole == 'nutritionist'
                  ? 'Nutritionist Sessions'
                  : 'My Sessions',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? _isHost
              ? _buildHostLoadingSkeleton()
              : const Center(child: CircularProgressIndicator(color: AppColors.purple))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.orange,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  if (_isHost && _zoomStatus != null) ...[
                    if (!_zoomConnected && !_connectZoomCardDismissed)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: _ConnectZoomGateCard(
                            loading: _zoomLoading,
                            onConnect: _connectZoom,
                            onDismiss: () => setState(() => _connectZoomCardDismissed = true),
                          ),
                        ),
                      )
                    else if (_zoomConnected || _zoomStatus!.status == ZoomConnectionStatus.expired)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: _ConnectionCard(
                            status: _zoomStatus!,
                            loading: _zoomLoading,
                            onConnect: _connectZoom,
                            onReconnect: _connectZoom,
                            onDisconnect: _disconnectZoom,
                          ),
                        ),
                      ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        _sessions.isEmpty ? 'Sessions' : 'Upcoming',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ),
                  if (_sessions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        isHost: _isHost,
                        canCreate: _canCreateSession,
                        onCreate: () => _openCreateSession(),
                        onJoin: () => _showJoinWithLinkSheet(context),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sessions = _sessions.where((s) => !s.isCancelled).toList();
                          if (index >= sessions.length) return const SizedBox.shrink();
                          final s = sessions[index];
                          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _SessionTile(
                              session: s,
                              isHost: s.hostId == currentUserId,
                              onTap: () => context.push('/video/session/${s.id}'),
                            ),
                          );
                        },
                        childCount: _sessions.where((s) => !s.isCancelled).length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
      floatingActionButton: _isHost
          ? FloatingActionButton.extended(
              onPressed: _canCreateSession ? () => _openCreateSession() : null,
              backgroundColor: _canCreateSession ? AppColors.purple : Colors.grey,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Create Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildHostLoadingSkeleton() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: DesignTokens.cardShadowOf(context),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.purple),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _ConnectZoomGateCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onDismiss;

  const _ConnectZoomGateCard({
    required this.loading,
    required this.onConnect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect Zoom to create meetings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect once to schedule sessions. You can still paste an external link without Zoom.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : onConnect,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(loading ? 'Connecting...' : 'Connect Zoom'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: loading ? null : onDismiss,
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final ZoomIntegrationStatus status;
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;

  const _ConnectionCard({
    required this.status,
    required this.loading,
    required this.onConnect,
    required this.onReconnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.videocam_rounded,
                color: status.status == ZoomConnectionStatus.connected
                    ? AppColors.green
                    : status.status == ZoomConnectionStatus.expired
                        ? AppColors.orange
                        : AppColors.textSecondaryOf(context),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.status == ZoomConnectionStatus.connected
                          ? 'Connected'
                          : status.status == ZoomConnectionStatus.expired
                              ? 'Connection expired'
                              : 'Not connected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    if (status.email != null && status.email!.isNotEmpty)
                      Text(
                        status.email!,
                        style: TextStyle(
                          fontSize: 12,
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
          const SizedBox(height: 12),
          if (status.status == ZoomConnectionStatus.notConnected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onConnect,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_rounded, size: 18),
                label: Text(loading ? 'Connecting...' : 'Connect Zoom'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (status.status == ZoomConnectionStatus.expired)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onReconnect,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(loading ? 'Reconnecting...' : 'Reconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loading ? null : onDisconnect,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Disconnect'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final VideoSession session;
  final bool isHost;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.isHost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: DesignTokens.cardShadowOf(context),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.purple.withOpacity(0.2),
                child: const Icon(Icons.videocam_rounded, color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(session.scheduledStart),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    if (isHost)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Host',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dt.year, dt.month, dt.day);
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (sessionDate == today) {
      return 'Today at $timeStr';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (sessionDate == tomorrow) {
      return 'Tomorrow at $timeStr';
    }
    return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
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
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://zoom.us/j/...',
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
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Invalid or unsupported link')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _EmptyState extends StatelessWidget {
  final bool isHost;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _EmptyState({
    required this.isHost,
    required this.canCreate,
    required this.onCreate,
    required this.onJoin,
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
              Icons.videocam_outlined,
              size: 64,
              color: AppColors.textSecondaryOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              isHost ? 'No sessions yet' : 'No upcoming sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isHost
                  ? (canCreate
                      ? 'No sessions scheduled. Create one.'
                      : 'Connect Zoom or paste a link to create sessions')
                  : 'No upcoming sessions. Your trainer/nutritionist will schedule one.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isHost && canCreate)
              ElevatedButton(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Create Session'),
              )
            else if (!isHost)
              ElevatedButton(
                onPressed: () => _showJoinWithLinkSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Join with link'),
              ),
          ],
        ),
      ),
    );
  }
}
