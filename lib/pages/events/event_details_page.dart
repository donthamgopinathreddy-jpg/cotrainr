import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/community_event.dart';
import '../../providers/community_events_provider.dart';
import '../../repositories/community_events_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/community_event_datetime.dart';
import '../../utils/launch_utils.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import 'join_event_sheet.dart';

class EventDetailsPage extends ConsumerStatefulWidget {
  const EventDetailsPage({
    super.key,
    this.eventId,
    this.initialData,
  });

  final String? eventId;
  final CommunityEventCardData? initialData;

  @override
  ConsumerState<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends ConsumerState<EventDetailsPage> {
  CommunityEventCardData? _localData;

  @override
  void initState() {
    super.initState();
    _localData = widget.initialData;
  }

  CommunityEventCardData? _resolveData() {
    if (_localData != null) return _localData;
    if (widget.initialData != null) return widget.initialData;

    final home = ref.watch(homeCommunityEventProvider).valueOrNull;
    final id = widget.eventId;
    if (home != null && id != null && home.event.id == id) {
      return home;
    }
    return null;
  }

  Future<void> _onJoin(CommunityEventCardData data) async {
    await showJoinEventSheet(
      context,
      data: data,
      onRegistered: () {
        setState(() {
          _localData = data.copyWith(
            isRegistered: true,
            attendeeCount: data.attendeeCount + (data.isRegistered ? 0 : 1),
          );
        });
        ref.invalidate(homeCommunityEventProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;
    final data = _resolveData();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Community Event',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: data == null
          ? _UnavailableBody(textPrimary: textPrimary, textSecondary: textSecondary)
          : _EventDetailsBody(
              data: data,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isLight: isLight,
              onJoin: () => _onJoin(data),
            ),
    );
  }
}

class _UnavailableBody extends StatelessWidget {
  const _UnavailableBody({
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 48, color: textSecondary),
            const SizedBox(height: 12),
            Text(
              'Event unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This event could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
              ),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailsBody extends StatelessWidget {
  const _EventDetailsBody({
    required this.data,
    required this.textPrimary,
    required this.textSecondary,
    required this.isLight,
    required this.onJoin,
  });

  final CommunityEventCardData data;
  final Color textPrimary;
  final Color textSecondary;
  final bool isLight;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final event = data.event;
    final availability = data.joinAvailability();
    final imageUrl = CommunityEventsRepository.publicImageUrl(event.imagePath);
    final fullDesc = event.fullDescription?.trim();
    final location = event.locationName?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _Cover(imageUrl: imageUrl, isLight: isLight),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          event.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.2,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.schedule_outlined, size: 18, color: textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                CommunityEventDateTime.scheduleLabel(event),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (location != null && location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (event.hasValidMapUrl) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => LaunchUtils.openMapUrl(context, event.mapUrl),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Open in Maps'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
        if (data.attendeeCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '${data.attendeeCount} joined',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
        ],
        if (fullDesc != null && fullDesc.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            fullDesc,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: textPrimary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (availability == EventJoinAvailability.joined)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "✓ You're registered",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          )
        else if (availability == EventJoinAvailability.canJoin)
          FilledButton(
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Join Event'),
          )
        else if (availability == EventJoinAvailability.full)
          Text(
            'This event is full.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          )
        else if (availability == EventJoinAvailability.deadlinePassed)
          Text(
            'Registration has closed.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          )
        else if (availability == EventJoinAvailability.ended)
          Text(
            'This event has ended.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          )
        else
          Text(
            'Registration is not available.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.imageUrl, required this.isLight});

  final String? imageUrl;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: isLight
          ? AppColors.orange.withValues(alpha: 0.12)
          : AppColors.orange.withValues(alpha: 0.18),
      child: const Center(
        child: Icon(Icons.event_rounded, size: 56, color: AppColors.orange),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
