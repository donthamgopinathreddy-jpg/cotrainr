import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../pages/discover/center_detail_page.dart';
import '../../pages/discover/discover_page.dart';
import '../../providers/partner_centers_provider.dart';
import '../../providers/profile_role_provider.dart';
import '../../repositories/partner_centers_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';
import '../common/pressable_card.dart';
import '../common/shimmer_skeleton.dart';
import 'home_premium_theme.dart';
import 'home_section_error.dart';

/// 3 rows on compact phones; up to 5 when the Home column is wide enough.
int homeCentersPreviewCountForWidth(double width) => width < 390 ? 3 : 5;

void openHomeCentersSeeAll(BuildContext context, {required bool isProvider}) {
  HapticFeedback.lightImpact();
  if (isProvider) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DiscoverPage(initialDiscoverTab: 2),
      ),
    );
    return;
  }
  context.go('/home?tab=1&discover=centers');
}

void openPartnerCenterDetail(
  BuildContext context,
  PartnerCenterDiscoverItem center,
) {
  HapticFeedback.lightImpact();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CenterDetailPage(
        centerId: center.id,
        centerName: center.name,
        subtitle: center.businessType,
        location: center.locationLabel,
        rating: 0,
        reviews: 0,
        distance: double.nan,
        isCotrainrPartner: true,
        activeOfferTitle: center.offerTitle,
      ),
    ),
  );
}

/// Compact Home preview of real Cotrainr partner centers (no fake venues).
class HomeCentersPreview extends ConsumerWidget {
  final VoidCallback? onSeeAll;
  final ValueChanged<PartnerCenterDiscoverItem>? onOpenCenter;

  const HomeCentersPreview({
    super.key,
    this.onSeeAll,
    this.onOpenCenter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homePartnerCentersProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isProvider =
        ref.watch(currentUserProvider).value?.isProvider ?? false;
    final maxCount =
        homeCentersPreviewCountForWidth(MediaQuery.sizeOf(context).width);

    return async.when(
      loading: () => _shell(
        context,
        isLight: isLight,
        isProvider: isProvider,
        body: Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i == 2 ? 0 : 8),
              child: const ShimmerBox(height: 64, radius: 16),
            ),
          ),
        ),
      ),
      error: (_, __) => _shell(
        context,
        isLight: isLight,
        isProvider: isProvider,
        body: HomeSectionError(
          message: 'Couldn’t load centers',
          onRetry: () => ref.invalidate(homePartnerCentersProvider),
        ),
      ),
      data: (centers) {
        if (centers.isEmpty) return const SizedBox.shrink();
        final preview = centers.take(maxCount).toList();
        return _shell(
          context,
          isLight: isLight,
          isProvider: isProvider,
          body: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _CenterPreviewRow(
                  center: preview[i],
                  isLight: isLight,
                  onTap: () {
                    final cb = onOpenCenter;
                    if (cb != null) {
                      cb(preview[i]);
                    } else {
                      openPartnerCenterDetail(context, preview[i]);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shell(
    BuildContext context, {
    required bool isLight,
    required bool isProvider,
    required Widget body,
  }) {
    final titleColor = HomePremiumTheme.primaryText(isLight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.stepsGradient.createShader(bounds),
              child: const Icon(
                Icons.apartment_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppColors.stepsGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Centers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle(context, color: titleColor),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (onSeeAll != null) {
                  onSeeAll!();
                } else {
                  openHomeCentersSeeAll(context, isProvider: isProvider);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.accentOrange,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: DesignTokens.accentOrange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Fitness & wellness centers',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

class _CenterPreviewRow extends StatelessWidget {
  final PartnerCenterDiscoverItem center;
  final bool isLight;
  final VoidCallback onTap;

  const _CenterPreviewRow({
    required this.center,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = center.businessType.trim();
    final city = center.city.trim();
    final metaParts = <String>[
      if (type.isNotEmpty) type,
      if (city.isNotEmpty) city,
    ];
    final offer = center.offerTitle?.trim();
    final hasOffer = offer != null && offer.isNotEmpty;

    return PressableCard(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: isLight
              ? HomePremiumTheme.lightCreamCard
              : HomePremiumTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _CenterThumb(logoUrl: center.logoUrl, isLight: isLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    center.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: HomePremiumTheme.primaryText(isLight),
                    ),
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      metaParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: HomePremiumTheme.secondaryText(isLight),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MiniChip(
                        label: 'Cotrainr Partner',
                        isLight: isLight,
                      ),
                      if (hasOffer)
                        _MiniChip(
                          label: 'Offer',
                          isLight: isLight,
                          accent: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final bool isLight;
  final bool accent;

  const _MiniChip({
    required this.label,
    required this.isLight,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? DesignTokens.accentOrange
        : HomePremiumTheme.secondaryText(isLight);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _CenterThumb extends StatelessWidget {
  final String? logoUrl;
  final bool isLight;

  const _CenterThumb({required this.logoUrl, required this.isLight});

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    final hasRemote = url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: hasRemote
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: isLight
          ? const Color(0xFFF3EDE6)
          : Colors.white.withValues(alpha: 0.08),
      child: Icon(
        Icons.apartment_rounded,
        color: DesignTokens.accentOrange.withValues(alpha: 0.85),
        size: 24,
      ),
    );
  }
}
