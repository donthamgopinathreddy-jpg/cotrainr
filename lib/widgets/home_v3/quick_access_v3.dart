import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/accepted_client_trainers_provider.dart';
import '../../providers/unread_video_session_notifications_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';
import '../../utils/client_notes_grouping.dart';
import '../common/pressable_card.dart';
import 'home_premium_theme.dart';

const _exploreHeaderGradient = LinearGradient(
  colors: [AppColors.blue, AppColors.cyan],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

/// Explore hub — bento grid aligned with home metric/BMI tile styling.
class QuickAccessV3 extends ConsumerStatefulWidget {
  const QuickAccessV3({super.key});

  @override
  ConsumerState<QuickAccessV3> createState() => _QuickAccessV3State();
}

class _QuickAccessV3State extends ConsumerState<QuickAccessV3> {
  static const double _tileRadius = 28;
  static const double _tileGap = 10;

  String get _role =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['role']
          ?.toString()
          .toLowerCase() ??
      'client';

  String _providersSubtitle(int trainerCount, int nutritionistCount) {
    final total = trainerCount + nutritionistCount;
    if (total <= 0) return 'No coaches connected yet';
    if (total == 1) return '1 coach connected';
    return '$total coaches connected';
  }

  Map<String, _ExploreTileData> _tilesForRole(
    String userRole, {
    required int acceptedTrainerCount,
    required int acceptedNutritionistCount,
  }) {
    final isTrainer = userRole == 'trainer';
    final isNutritionist = userRole == 'nutritionist';
    final excludeTrainerOnly = isTrainer || isNutritionist;

    final tiles = <String, _ExploreTileData>{
      'Nutrition Goals': const _ExploreTileData(
        title: 'Nutrition Goals',
        subtitle: 'Calculate macros and hit your daily targets.',
        icon: Icons.track_changes_rounded,
        accent: Color(0xFF2EBD85),
      ),
      'Video Sessions': const _ExploreTileData(
        title: 'Video Sessions',
        subtitle: 'Join live sessions with your trainer.',
        icon: Icons.videocam_rounded,
        accent: Color(0xFF8B7CF6),
      ),
    };

    if (!isTrainer && !isNutritionist) {
      tiles['Notes'] = const _ExploreTileData(
        title: kClientNotesExploreTitle,
        subtitle: kClientNotesExploreSubtitle,
        icon: Icons.note_rounded,
        accent: Color(0xFFFF6B6B),
      );
      tiles['Trainers & Nutritionists'] = _ExploreTileData(
        title: 'Trainers & Nutritionists',
        subtitle: _providersSubtitle(
          acceptedTrainerCount,
          acceptedNutritionistCount,
        ),
        icon: Icons.groups_rounded,
        accent: DesignTokens.accentOrange,
      );
    }

    if (!excludeTrainerOnly) {
      tiles['Subscription'] = const _ExploreTileData(
        title: 'Subscription',
        subtitle: 'Manage your plan and member benefits.',
        icon: Icons.workspace_premium_rounded,
        accent: Color(0xFFE91E8C),
      );
    }

    return tiles;
  }

  VoidCallback? _routeFor(BuildContext context, String title) {
    switch (title) {
      case 'Notes':
      case 'Coach Notes':
        return () => context.push('/coach-notes');
      case 'Client Notes':
        return () => context.push('/trainer/notes');
      case 'Video Sessions':
        return () => context.push('/video');
      case 'Nutrition Goals':
        return () => context.push('/nutrition-goals');
      case 'Subscription':
        return () => context.push('/subscription');
      case 'Trainers & Nutritionists':
      case 'Trainers':
      case 'My Trainers':
        return () {
          final loc = GoRouterState.of(context).matchedLocation;
          if (loc == '/my-trainers') return;
          context.push('/my-trainers');
        };
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final trainerCount = ref.watch(acceptedClientTrainersCountProvider);
    final nutritionistCount =
        ref.watch(acceptedClientNutritionistsCountProvider);
    final videoUnread = ref.watch(unreadVideoSessionNotificationsProvider)
        .maybeWhen(data: (n) => n, orElse: () => 0);
    // Ensure realtime/list provider is warm for clients.
    if (_role != 'trainer' && _role != 'nutritionist') {
      ref.watch(acceptedClientTrainersProvider);
      ref.watch(acceptedClientNutritionistsProvider);
    }
    final tiles = _tilesForRole(
      _role,
      acceptedTrainerCount: trainerCount,
      acceptedNutritionistCount: nutritionistCount,
    );
    if (tiles.isEmpty) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExploreSectionHeader(isLight: isLight),
          const SizedBox(height: 14),
          _ExploreBentoGrid(
            tiles: tiles,
            isLight: isLight,
            role: _role,
            videoUnread: videoUnread,
            onTileTap: (tile) => _routeFor(context, tile.title)?.call(),
          ),
        ],
      ),
    );
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  final bool isLight;

  const _ExploreSectionHeader({required this.isLight});

  @override
  Widget build(BuildContext context) {
    final titleColor = HomePremiumTheme.primaryText(isLight);
    final headerGradient = isLight
        ? const LinearGradient(
            colors: [Color(0xFF1FB6E8), Color(0xFF4DA3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : _exploreHeaderGradient;

    return Row(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => headerGradient.createShader(bounds),
          child: const Icon(
            Icons.bolt_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: headerGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Explore',
          style: AppTextStyles.sectionTitle(context, color: titleColor),
        ),
      ],
    );
  }
}

class _ExploreBentoGrid extends StatelessWidget {
  final Map<String, _ExploreTileData> tiles;
  final bool isLight;
  final String role;
  final int videoUnread;
  final ValueChanged<_ExploreTileData> onTileTap;

  const _ExploreBentoGrid({
    required this.tiles,
    required this.isLight,
    required this.role,
    required this.videoUnread,
    required this.onTileTap,
  });

  static const _gap = _QuickAccessV3State._tileGap;

  _ExploreTileData? _get(String key) => tiles[key];

  @override
  Widget build(BuildContext context) {
    final isTrainer = role == 'trainer';
    final isNutritionist = role == 'nutritionist';
    final isClient = !isTrainer && !isNutritionist;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final pairH = (w * 0.48).clamp(148.0, 172.0);
        final bannerH = (w * 0.30).clamp(104.0, 124.0);

        if (isNutritionist) {
          return _buildPairRow(
            pairH,
            _get('Nutrition Goals')!,
            _get('Video Sessions')!,
          );
        }
        if (isTrainer) {
          return _buildPairRow(
            pairH,
            _get('Nutrition Goals')!,
            _get('Video Sessions')!,
          );
        }
        if (isClient) {
          return _buildClientLayout(pairH, bannerH);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildClientLayout(double pairH, double bannerH) {
    final nutrition = _get('Nutrition Goals')!;
    final coach = _get('Notes')!;
    final video = _get('Video Sessions')!;
    final providers = _get('Trainers & Nutritionists')!;
    final subscription = _get('Subscription')!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPairRow(pairH, nutrition, coach),
        const SizedBox(height: _gap),
        SizedBox(
          height: bannerH,
          width: double.infinity,
          child: _ExploreTile(
            item: video,
            layout: _ExploreTileLayout.banner,
            isLight: isLight,
            showAlertDot: videoUnread > 0,
            onTap: () => onTileTap(video),
          ),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: bannerH,
          width: double.infinity,
          child: _ExploreTile(
            item: providers,
            layout: _ExploreTileLayout.banner,
            isLight: isLight,
            onTap: () => onTileTap(providers),
          ),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: bannerH,
          width: double.infinity,
          child: _ExploreTile(
            item: subscription,
            layout: _ExploreTileLayout.banner,
            isLight: isLight,
            onTap: () => onTileTap(subscription),
          ),
        ),
      ],
    );
  }

  Widget _buildPairRow(
    double height,
    _ExploreTileData left,
    _ExploreTileData right,
  ) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ExploreTile(
              item: left,
              layout: _ExploreTileLayout.half,
              isLight: isLight,
              showAlertDot: left.title == 'Video Sessions' && videoUnread > 0,
              onTap: () => onTileTap(left),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: _ExploreTile(
              item: right,
              layout: _ExploreTileLayout.half,
              isLight: isLight,
              showAlertDot: right.title == 'Video Sessions' && videoUnread > 0,
              onTap: () => onTileTap(right),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ExploreTileLayout { half, banner }

class _ExploreTile extends StatelessWidget {
  final _ExploreTileData item;
  final _ExploreTileLayout layout;
  final bool isLight;
  final bool showAlertDot;
  final VoidCallback? onTap;

  const _ExploreTile({
    required this.item,
    required this.layout,
    required this.isLight,
    this.showAlertDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBanner = layout == _ExploreTileLayout.banner;
    final accent = item.accentFor(isLight);
    final titleColor = HomePremiumTheme.primaryText(isLight);
    final subtitleColor = HomePremiumTheme.secondaryText(isLight);

    return PressableCard(
      onTap: onTap,
      borderRadius: _QuickAccessV3State._tileRadius,
      pressScale: 0.97,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_QuickAccessV3State._tileRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: HomePremiumTheme.bmiTileGradient(isLight, accent),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: isBanner ? 6 : 10,
                right: isBanner ? 4 : 6,
                child: IgnorePointer(
                  child: _TileWatermark(
                    icon: item.icon,
                    accent: accent,
                    size: isBanner ? 72 : 60,
                  ),
                ),
              ),
              if (showAlertDot)
                Positioned(
                  top: isBanner ? 12 : 12,
                  right: isBanner ? 14 : 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isBanner ? 18 : 16,
                  isBanner ? 14 : 16,
                  isBanner ? 80 : 68,
                  isBanner ? 14 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isBanner ? 12 : 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: subtitleColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.subtitle,
                      maxLines: isBanner ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isBanner ? 15 : 14,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft watermark icon — top-right decorative accent like Samsung Health tiles.
class _TileWatermark extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;

  const _TileWatermark({
    required this.icon,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Icon(
      icon,
      size: size,
      color: accent.withValues(alpha: isLight ? 0.28 : 0.12),
    );
  }
}

class _ExploreTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _ExploreTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  Color accentFor(bool isLight) {
    if (!isLight) return accent;
    // Brighter light-mode accents for Explore tiles.
    return switch (title) {
      'Nutrition Goals' => const Color(0xFF12C07A),
      'Notes' || 'Coach Notes' || 'Client Notes' => const Color(0xFFFF4D4D),
      'Video Sessions' => const Color(0xFF7C5CFF),
      'My Trainers' || 'Trainers' || 'Trainers & Nutritionists' =>
        const Color(0xFFFF8A00),
      'Subscription' => const Color(0xFFFF2D95),
      _ => accent,
    };
  }
}
