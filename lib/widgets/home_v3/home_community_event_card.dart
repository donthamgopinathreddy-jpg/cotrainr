import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/community_event.dart';
import '../../pages/events/join_event_sheet.dart';
import '../../providers/community_events_provider.dart';
import '../../repositories/community_events_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/community_event_datetime.dart';
import '../common/pressable_card.dart';
import 'home_premium_theme.dart';

/// Home Community Event tile. Renders nothing when loading / error / null.
class HomeCommunityEventCard extends ConsumerWidget {
  const HomeCommunityEventCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeCommunityEventProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        return _CommunityEventCardBody(
          data: data,
          onRegistered: () => ref.invalidate(homeCommunityEventProvider),
        );
      },
    );
  }
}

class _CommunityEventCardBody extends StatelessWidget {
  const _CommunityEventCardBody({
    required this.data,
    required this.onRegistered,
  });

  final CommunityEventCardData data;
  final VoidCallback onRegistered;

  void _openDetails(BuildContext context) {
    context.push('/events/${data.event.id}', extra: data);
  }

  Future<void> _openJoin(BuildContext context) async {
    await showJoinEventSheet(
      context,
      data: data,
      onRegistered: onRegistered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final event = data.event;
    final availability = data.joinAvailability();
    final badge = CommunityEventDateTime.dateBadge(event.startsAt);
    final imageUrl =
        CommunityEventsRepository.publicImageUrl(event.imagePath);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final narrow = MediaQuery.sizeOf(context).width < 360;

    // Layout height is reserved first; entrance slide stays inside those bounds.
    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 290),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - value)),
              child: child,
            ),
          );
        },
        child: PressableCard(
          onTap: () => _openDetails(context),
          borderRadius: 22,
          pressScale: 0.985,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLight
                        ? [
                            Colors.white.withValues(alpha: 0.88),
                            const Color(0xFFF3F4F7).withValues(alpha: 0.92),
                            Color.lerp(
                              const Color(0xFFF3F4F7),
                              AppColors.orange,
                              0.04,
                            )!.withValues(alpha: 0.95),
                          ]
                        : [
                            const Color(0xFF1A1A1A).withValues(alpha: 0.78),
                            const Color(0xFF141414).withValues(alpha: 0.82),
                            Color.lerp(
                              const Color(0xFF121212),
                              AppColors.orange,
                              0.05,
                            )!.withValues(alpha: 0.86),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    if (!isLight)
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.05),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3.5,
                        color: AppColors.orange,
                      ),
                      Expanded(
                        child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'COMMUNITY EVENT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.85,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                          _CompactDateChip(
                            month: badge.$1,
                            day: badge.$2,
                            isLight: isLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: HomePremiumTheme.primaryText(
                                      isLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  CommunityEventDateTime.scheduleLabel(event),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: HomePremiumTheme.secondaryText(
                                      isLight,
                                    ),
                                  ),
                                ),
                                if (event.locationName != null &&
                                    event.locationName!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 13,
                                        color: HomePremiumTheme.secondaryText(
                                          isLight,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          event.locationName!.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                HomePremiumTheme.secondaryText(
                                              isLight,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (imageUrl != null &&
                              imageUrl.isNotEmpty &&
                              !narrow) ...[
                            const SizedBox(width: 10),
                            _CompactCover(imageUrl: imageUrl),
                          ] else if (!hasImage && !narrow) ...[
                            const SizedBox(width: 8),
                            _GlassCalendarTile(isLight: isLight),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (data.attendeeCount > 0) ...[
                            Icon(
                              Icons.people_outline_rounded,
                              size: 14,
                              color: AppColors.orange.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${data.attendeeCount} joined',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HomePremiumTheme.secondaryText(isLight),
                              ),
                            ),
                          ],
                          const Spacer(),
                          TextButton(
                            onPressed: () => _openDetails(context),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  HomePremiumTheme.primaryText(isLight),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(44, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Details'),
                          ),
                          const SizedBox(width: 4),
                          _JoinAction(
                            availability: availability,
                            onJoin: () => _openJoin(context),
                            isLight: isLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                        ),
                      ),
                    ],
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

class _CompactDateChip extends StatelessWidget {
  const _CompactDateChip({
    required this.month,
    required this.day,
    required this.isLight,
  });

  final String month;
  final String day;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        '$month $day',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _CompactCover extends StatelessWidget {
  const _CompactCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        height: 92,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => _GlassCalendarTile(
            isLight: Theme.of(context).brightness == Brightness.light,
          ),
          errorWidget: (_, _, _) => _GlassCalendarTile(
            isLight: Theme.of(context).brightness == Brightness.light,
          ),
        ),
      ),
    );
  }
}

class _GlassCalendarTile extends StatelessWidget {
  const _GlassCalendarTile({required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isLight
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Icon(
        Icons.event_rounded,
        size: 22,
        color: isLight
            ? HomePremiumTheme.secondaryText(true)
            : Colors.white.withValues(alpha: 0.55),
      ),
    );
  }
}

class _JoinAction extends StatelessWidget {
  const _JoinAction({
    required this.availability,
    required this.onJoin,
    required this.isLight,
  });

  final EventJoinAvailability availability;
  final VoidCallback onJoin;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (availability) {
        EventJoinAvailability.canJoin => FilledButton(
            key: const ValueKey('join'),
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Join'),
          ),
        EventJoinAvailability.joined => Container(
            key: const ValueKey('joined'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isLight
                  ? AppColors.orange.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: isLight
                    ? AppColors.orange.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: isLight
                      ? AppColors.orange
                      : Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  'Joined',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: HomePremiumTheme.primaryText(isLight),
                  ),
                ),
              ],
            ),
          ),
        EventJoinAvailability.full => Text(
            key: const ValueKey('full'),
            'Full',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        EventJoinAvailability.disabled ||
        EventJoinAvailability.deadlinePassed ||
        EventJoinAvailability.ended =>
          const SizedBox.shrink(key: ValueKey('hidden')),
      },
    );
  }
}
