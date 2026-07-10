import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
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

  Map<String, _ExploreTileData> _tilesForRole(String userRole) {
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

    if (isTrainer) {
      tiles['Client Notes'] = const _ExploreTileData(
        title: 'Client Notes',
        subtitle: 'Review feedback and session notes.',
        icon: Icons.edit_note_rounded,
        accent: Color(0xFFFF6B6B),
      );
    } else if (!isNutritionist) {
      tiles['Coach Notes'] = const _ExploreTileData(
        title: 'Coach Notes',
        subtitle: 'View trainer feedback and notes.',
        icon: Icons.note_rounded,
        accent: Color(0xFFFF6B6B),
      );
    }

    if (!excludeTrainerOnly) {
      tiles['Subscription'] = const _ExploreTileData(
        title: 'Subscription',
        subtitle: 'Manage your plan and member benefits.',
        icon: Icons.workspace_premium_rounded,
        accent: Color(0xFFE91E8C),
      );
      tiles['Become a Trainer'] = const _ExploreTileData(
        title: 'Become a Trainer',
        subtitle: 'Share your knowledge and grow with us.',
        icon: Icons.school_rounded,
        accent: AppColors.becomeTrainerAccent,
      );
    }

    return tiles;
  }

  VoidCallback? _routeFor(BuildContext context, String title) {
    switch (title) {
      case 'Become a Trainer':
        return () => context.push('/trainer/become');
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
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tiles = _tilesForRole(_role);
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
            colors: [Color(0xFF3BA8D4), Color(0xFF4DA3FF)],
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
  final ValueChanged<_ExploreTileData> onTileTap;

  const _ExploreBentoGrid({
    required this.tiles,
    required this.isLight,
    required this.role,
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPairRow(
                pairH,
                _get('Nutrition Goals')!,
                _get('Client Notes')!,
              ),
              const SizedBox(height: _gap),
              SizedBox(
                height: bannerH,
                width: double.infinity,
                child: _ExploreTile(
                  item: _get('Video Sessions')!,
                  layout: _ExploreTileLayout.banner,
                  isLight: isLight,
                  onTap: () => onTileTap(_get('Video Sessions')!),
                ),
              ),
            ],
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
    final coach = _get('Coach Notes')!;
    final video = _get('Video Sessions')!;
    final become = _get('Become a Trainer')!;
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
            onTap: () => onTileTap(video),
          ),
        ),
        const SizedBox(height: _gap),
        _buildPairRow(pairH, become, subscription),
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
              onTap: () => onTileTap(left),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: _ExploreTile(
              item: right,
              layout: _ExploreTileLayout.half,
              isLight: isLight,
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
  final VoidCallback? onTap;

  const _ExploreTile({
    required this.item,
    required this.layout,
    required this.isLight,
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
    return Icon(
      icon,
      size: size,
      color: accent.withValues(alpha: 0.12),
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
    return switch (title) {
      'Nutrition Goals' => const Color(0xFF1FA876),
      'Coach Notes' || 'Client Notes' => const Color(0xFFE85555),
      'Video Sessions' => const Color(0xFF6D5CE6),
      'Become a Trainer' => const Color(0xFF3A96C4),
      'Subscription' => const Color(0xFFD4187A),
      _ => Color.lerp(accent, HomePremiumTheme.lightCharcoalText, 0.10)!,
    };
  }
}
