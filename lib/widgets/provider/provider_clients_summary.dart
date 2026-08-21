import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';

class ProviderClientPreview {
  final String id;
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final String? leadId;

  const ProviderClientPreview({
    required this.id,
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.leadId,
  });
}

class ProviderNextSessionPreview {
  final String sessionId;
  final String clientName;
  final DateTime scheduledStart;

  const ProviderNextSessionPreview({
    required this.sessionId,
    required this.clientName,
    required this.scheduledStart,
  });
}

ProviderNextSessionPreview? nextSessionPreviewFromSessions(
  List<VideoSession>? sessions,
) {
  if (sessions == null || sessions.isEmpty) return null;
  final upcoming = sessions.where((s) => s.isUpcoming).toList()
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  if (upcoming.isEmpty) return null;
  final session = upcoming.first;
  return ProviderNextSessionPreview(
    sessionId: session.id,
    clientName: _nextSessionClientName(session),
    scheduledStart: session.scheduledStart,
  );
}

String _nextSessionClientName(VideoSession session) {
  final counterpart = session.counterpartyName?.trim() ?? '';
  if (counterpart.isNotEmpty) return counterpart;
  final fromPeople = session.people
      .where((p) => p.role != 'host' && p.displayName.trim().isNotEmpty)
      .map((p) => p.displayName.trim());
  if (fromPeople.isNotEmpty) return fromPeople.first;
  if (session.participantNames.isNotEmpty) {
    return session.participantNames.first.trim();
  }
  return session.title;
}

String formatNextSessionWhen(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final clock = DateFormat('h:mm a', 'en_US').format(local);
  final today = now ?? DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == todayDay) return 'Today, $clock';
  if (day == todayDay.add(const Duration(days: 1))) return 'Tomorrow, $clock';
  return '${DateFormat('d MMM', 'en_US').format(local)}, $clock';
}

/// Compact client-management tile shared by trainer and nutritionist Home.
class ProviderClientsSummary extends StatelessWidget {
  final int activeCount;
  final int requestCount;
  final List<ProviderClientPreview> clients;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenNotes;
  final ValueChanged<ProviderClientPreview> onOpenClient;
  final bool loading;
  final ProviderNextSessionPreview? nextSession;
  final VoidCallback? onOpenNextSession;

  const ProviderClientsSummary({
    super.key,
    required this.activeCount,
    required this.requestCount,
    required this.clients,
    required this.onOpenClients,
    required this.onOpenRequests,
    required this.onOpenNotes,
    required this.onOpenClient,
    this.loading = false,
    this.nextSession,
    this.onOpenNextSession,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryTile(
          isLight: isLight,
          activeCount: activeCount,
          requestCount: requestCount,
          loading: loading,
          nextSession: nextSession,
          onOpenClients: onOpenClients,
          onOpenRequests: onOpenRequests,
          onOpenNotes: onOpenNotes,
          onOpenNextSession: onOpenNextSession,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent clients',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomePremiumTheme.primaryText(isLight),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'See all',
              child: TextButton(
                onPressed: onOpenClients,
                style: TextButton.styleFrom(
                  foregroundColor: HomePremiumTheme.recentClientAccent(isLight),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        if (loading)
          ...List.generate(2, (i) => const _RowSkeleton())
        else if (clients.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'No clients yet\nNew client connections will appear here.',
              style: TextStyle(
                height: 1.35,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          )
        else
          ...clients.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ClientRow(
                client: c,
                isLight: isLight,
                onTap: () => onOpenClient(c),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final bool isLight;
  final int activeCount;
  final int requestCount;
  final bool loading;
  final ProviderNextSessionPreview? nextSession;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenNotes;
  final VoidCallback? onOpenNextSession;

  const _SummaryTile({
    required this.isLight,
    required this.activeCount,
    required this.requestCount,
    required this.loading,
    required this.onOpenClients,
    required this.onOpenRequests,
    required this.onOpenNotes,
    this.nextSession,
    this.onOpenNextSession,
  });

  @override
  Widget build(BuildContext context) {
    final accent = HomePremiumTheme.clientsManagementAccent(isLight);
    return Semantics(
      label: 'Clients summary. $activeCount active. $requestCount requests.',
      child: PressableCard(
        borderRadius: 16,
        onTap: onOpenClients,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          decoration: BoxDecoration(
            color: HomePremiumTheme.clientsManagementSurface(isLight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 0, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clients',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: HomePremiumTheme.primaryText(isLight),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage your practice',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: HomePremiumTheme.secondaryText(isLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Open My Clients',
                    child: IconButton(
                      onPressed: onOpenClients,
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: accent,
                      ),
                      tooltip: 'Open My Clients',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _TileSkeleton(),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MetricHit(
                          icon: Icons.people_outline_rounded,
                          label: 'Active',
                          value: '$activeCount',
                          semanticLabel: '$activeCount active clients',
                          onTap: onOpenClients,
                        ),
                      ),
                      Expanded(
                        child: _MetricHit(
                          icon: Icons.person_add_alt_1_outlined,
                          label: 'Requests',
                          value: '$requestCount',
                          showDot: requestCount > 0,
                          semanticLabel: requestCount == 1
                              ? '1 request needing action'
                              : '$requestCount requests needing action',
                          onTap: onOpenRequests,
                        ),
                      ),
                      Expanded(
                        child: _MetricHit(
                          icon: Icons.description_outlined,
                          label: 'Notes',
                          value: null,
                          semanticLabel: 'Client Notes',
                          onTap: onOpenNotes,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!loading && nextSession != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Divider(
                    height: 1,
                    color: accent.withValues(alpha: 0.18),
                  ),
                ),
                _NextSessionRow(
                  isLight: isLight,
                  preview: nextSession!,
                  onTap: onOpenNextSession ?? onOpenClients,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricHit extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool showDot;

  const _MetricHit({
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticLabel,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = HomePremiumTheme.clientsManagementAccent(isLight);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 22, color: accent),
                    if (showDot)
                      Positioned(
                        right: -3,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DesignTokens.accentRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (value != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: HomePremiumTheme.primaryText(isLight),
                    ),
                  ),
                ] else
                  const SizedBox(height: 6),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HomePremiumTheme.secondaryText(isLight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextSessionRow extends StatelessWidget {
  final bool isLight;
  final ProviderNextSessionPreview preview;
  final VoidCallback onTap;

  const _NextSessionRow({
    required this.isLight,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = HomePremiumTheme.clientsManagementAccent(isLight);
    final when = formatNextSessionWhen(preview.scheduledStart);
    return Semantics(
      button: true,
      label: 'Next session ${preview.clientName} $when',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 4, 0),
            child: Row(
              children: [
                Icon(Icons.videocam_outlined, size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HomePremiumTheme.secondaryText(isLight),
                        ),
                      ),
                      Text(
                        '${preview.clientName} · $when',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: HomePremiumTheme.primaryText(isLight),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final ProviderClientPreview client;
  final bool isLight;
  final VoidCallback onTap;

  const _ClientRow({
    required this.client,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = HomePremiumTheme.recentClientAccent(isLight);
    return Semantics(
      button: true,
      label: 'Client ${client.name}',
      child: PressableCard(
        borderRadius: 16,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: HomePremiumTheme.recentClientSurface(isLight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              VideoSessionAvatar(
                name: client.name,
                imageUrl: client.avatarUrl,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: HomePremiumTheme.primaryText(isLight),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: HomePremiumTheme.secondaryText(isLight),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: accent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE4DFF3)
        : Colors.white.withValues(alpha: 0.08);
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: HomePremiumTheme.recentClientSurface(isLight),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
