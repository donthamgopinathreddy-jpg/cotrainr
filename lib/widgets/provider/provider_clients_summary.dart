import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../../widgets/video_sessions/video_session_theme.dart';

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
          onOpenClients: onOpenClients,
          onOpenRequests: onOpenRequests,
          onOpenNotes: onOpenNotes,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Clients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HomePremiumTheme.primaryText(isLight),
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: 'See all',
              child: TextButton(
                onPressed: onOpenClients,
                style: TextButton.styleFrom(
                  foregroundColor: DesignTokens.videoSessionsAccent,
                  minimumSize: const Size(44, 44),
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
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenNotes;

  const _SummaryTile({
    required this.isLight,
    required this.activeCount,
    required this.requestCount,
    required this.loading,
    required this.onOpenClients,
    required this.onOpenRequests,
    required this.onOpenNotes,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Clients summary. $activeCount active. $requestCount requests.',
      child: PressableCard(
        borderRadius: VideoSessionUi.radius,
        onTap: onOpenClients,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: VideoSessionUi.cardBox(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Clients',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: HomePremiumTheme.primaryText(isLight),
                      ),
                    ),
                  ),
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.videoSessionsAccent,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: DesignTokens.videoSessionsAccent,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Manage clients, requests and follow-ups',
                style: TextStyle(
                  fontSize: 13,
                  color: HomePremiumTheme.secondaryText(isLight),
                ),
              ),
              const SizedBox(height: 12),
              if (loading)
                const _TileSkeleton()
              else
                Row(
                  children: [
                    Expanded(
                      child: _MetricHit(
                        label: 'Active',
                        value: '$activeCount',
                        semanticLabel: '$activeCount active clients',
                        onTap: onOpenClients,
                      ),
                    ),
                    Expanded(
                      child: _MetricHit(
                        label: 'Request',
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
                        label: 'Notes',
                        value: '→',
                        semanticLabel: 'Client Notes',
                        onTap: onOpenNotes,
                        emphasize: true,
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

class _MetricHit extends StatelessWidget {
  final String label;
  final String value;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool showDot;
  final bool emphasize;

  const _MetricHit({
    required this.label,
    required this.value,
    required this.semanticLabel,
    required this.onTap,
    this.showDot = false,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: emphasize ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: emphasize
                            ? DesignTokens.videoSessionsAccent
                            : HomePremiumTheme.primaryText(isLight),
                      ),
                    ),
                  ),
                  if (showDot) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DesignTokens.accentRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
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
    return Semantics(
      button: true,
      label: 'Client ${client.name}',
      child: PressableCard(
        borderRadius: VideoSessionUi.radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: VideoSessionUi.cardBox(context),
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
                color: HomePremiumTheme.secondaryText(isLight),
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
        ? const Color(0xFFE8E8EA)
        : Colors.white.withValues(alpha: 0.08);
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 36,
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
    final color = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE8E8EA)
        : Colors.white.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(VideoSessionUi.radius),
        ),
      ),
    );
  }
}
