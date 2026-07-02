import 'dart:ui';

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

/// Premium "Explore" hub — asymmetrical 6-in-1 bento layout.
class QuickAccessV3 extends ConsumerStatefulWidget {
  const QuickAccessV3({super.key});

  @override
  ConsumerState<QuickAccessV3> createState() => _QuickAccessV3State();
}

class _QuickAccessV3State extends ConsumerState<QuickAccessV3> {
  static const double _containerRadius = 30;
  static const double _tileRadius = 26;
  static const double _tileGap = 11;
  static const double _parentPadding = 17;

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
      'Nutrition Goals': _ExploreTileData(
        title: 'Nutrition Goals',
        subtitle: 'Calculate macros and improve daily.',
        icon: Icons.track_changes_rounded,
        accent: const Color(0xFF2EBD85),
        ctaLabel: 'Go to goals',
      ),
      'Video Sessions': _ExploreTileData(
        title: 'Video Sessions',
        subtitle: 'Join live sessions with your trainer.',
        icon: Icons.videocam_rounded,
        accent: const Color(0xFF8B7CF6),
      ),
    };

    if (isTrainer) {
      tiles['Client Notes'] = _ExploreTileData(
        title: 'Client Notes',
        subtitle: 'View trainer feedback & notes.',
        icon: Icons.edit_note_rounded,
        accent: const Color(0xFFFF6B6B),
      );
    } else if (!isNutritionist) {
      tiles['Coach Notes'] = _ExploreTileData(
        title: 'Coach Notes',
        subtitle: 'View trainer feedback & notes.',
        icon: Icons.note_rounded,
        accent: const Color(0xFFFF6B6B),
      );
    }

    if (!excludeTrainerOnly) {
      tiles['AI Planner'] = _ExploreTileData(
        title: 'AI Planner',
        subtitle: 'Get a smart workout plan customized for you.',
        icon: Icons.auto_awesome_rounded,
        accent: const Color(0xFFFFB020),
        showWaveDecoration: true,
      );
      tiles['Subscription'] = _ExploreTileData(
        title: 'Subscription',
        subtitle: 'Manage your plan and benefits.',
        icon: Icons.workspace_premium_rounded,
        accent: const Color(0xFFE91E8C),
      );
      tiles['Become a Trainer'] = _ExploreTileData(
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
      case 'AI Planner':
        return () => context.push('/ai-planner');
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_containerRadius),
              boxShadow: isLight
                  ? HomePremiumTheme.softCardShadow(true)
                  : const <BoxShadow>[],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_containerRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isLight ? 2 : 14,
                  sigmaY: isLight ? 2 : 14,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_containerRadius),
                    color: isLight
                        ? HomePremiumTheme.lightCreamCard.withValues(alpha: 0.97)
                        : const Color(0xFF0A0A0A).withValues(alpha: 0.96),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_parentPadding),
                    child: _ExploreBentoGrid(
                      tiles: tiles,
                      isLight: isLight,
                      role: _role,
                      onTileTap: (tile) =>
                          _routeFor(context, tile.title)?.call(),
                    ),
                  ),
                ),
              ),
            ),
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
  static const _leftFlex = 3;
  static const _rightFlex = 2;

  _ExploreTileData? _get(String key) => tiles[key];

  @override
  Widget build(BuildContext context) {
    final isTrainer = role == 'trainer';
    final isNutritionist = role == 'nutritionist';
    final isClient = !isTrainer && !isNutritionist;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final topH = (w * 0.42).clamp(130.0, 152.0);
        final aiH = (w * 0.18).clamp(56.0, 64.0);
        final botH = (w * 0.17).clamp(54.0, 62.0);

        if (isNutritionist) {
          return _buildNutritionistLayout(topH);
        }
        if (isTrainer) {
          return _buildTrainerLayout(topH);
        }
        if (isClient) {
          return _buildClientLayout(topH, aiH, botH);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildClientLayout(double topH, double aiH, double botH) {
    final nutrition = _get('Nutrition Goals')!;
    final coach = _get('Coach Notes')!;
    final video = _get('Video Sessions')!;
    final ai = _get('AI Planner')!;
    final become = _get('Become a Trainer')!;
    final subscription = _get('Subscription')!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: topH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: _leftFlex,
                child: _BentoTile(
                  item: nutrition,
                  size: _BentoTileSize.featured,
                  isLight: isLight,
                  onTap: () => onTileTap(nutrition),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: _rightFlex,
                child: Column(
                  children: [
                    Expanded(
                      child: _BentoTile(
                        item: coach,
                        size: _BentoTileSize.medium,
                        isLight: isLight,
                        onTap: () => onTileTap(coach),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    Expanded(
                      child: _BentoTile(
                        item: video,
                        size: _BentoTileSize.medium,
                        isLight: isLight,
                        onTap: () => onTileTap(video),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: aiH,
          width: double.infinity,
          child: _BentoTile(
            item: ai,
            size: _BentoTileSize.fullWidth,
            isLight: isLight,
            onTap: () => onTileTap(ai),
          ),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: botH,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _BentoTile(
                  item: become,
                  size: _BentoTileSize.bottom,
                  isLight: isLight,
                  onTap: () => onTileTap(become),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 3,
                child: _BentoTile(
                  item: subscription,
                  size: _BentoTileSize.bottomWide,
                  isLight: isLight,
                  onTap: () => onTileTap(subscription),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerLayout(double topH) {
    final nutrition = _get('Nutrition Goals')!;
    final notes = _get('Client Notes')!;
    final video = _get('Video Sessions')!;

    return SizedBox(
      height: topH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: _leftFlex,
            child: _BentoTile(
              item: nutrition,
              size: _BentoTileSize.featured,
              isLight: isLight,
              onTap: () => onTileTap(nutrition),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: _rightFlex,
            child: Column(
              children: [
                Expanded(
                  child: _BentoTile(
                    item: notes,
                    size: _BentoTileSize.medium,
                    isLight: isLight,
                    onTap: () => onTileTap(notes),
                  ),
                ),
                const SizedBox(height: _gap),
                Expanded(
                  child: _BentoTile(
                    item: video,
                    size: _BentoTileSize.medium,
                    isLight: isLight,
                    onTap: () => onTileTap(video),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionistLayout(double topH) {
    final nutrition = _get('Nutrition Goals')!;
    final video = _get('Video Sessions')!;

    return SizedBox(
      height: topH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: _leftFlex,
            child: _BentoTile(
              item: nutrition,
              size: _BentoTileSize.featured,
              isLight: isLight,
              onTap: () => onTileTap(nutrition),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: _rightFlex,
            child: _BentoTile(
              item: video,
              size: _BentoTileSize.featuredCompact,
              isLight: isLight,
              onTap: () => onTileTap(video),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BentoTileSize {
  featured,
  featuredCompact,
  medium,
  fullWidth,
  bottom,
  bottomWide,
}

class _BentoTile extends StatelessWidget {
  final _ExploreTileData item;
  final _BentoTileSize size;
  final bool isLight;
  final VoidCallback? onTap;

  const _BentoTile({
    required this.item,
    required this.size,
    required this.isLight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      borderRadius: _QuickAccessV3State._tileRadius,
      pressScale: 0.97,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_QuickAccessV3State._tileRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SoftTileSurface(isLight: isLight, item: item),
            Positioned(
              right: 4,
              bottom: 2,
              child: IgnorePointer(
                child: Icon(
                  item.icon,
                  size: _watermarkSizeForTile(),
                  color: item.accentFor(isLight).withValues(
                        alpha: isLight ? 0.10 : 0.08,
                      ),
                ),
              ),
            ),
            Padding(
              padding: _paddingForSize(),
              child: _contentForSize(isLight),
            ),
            if (item.showWaveDecoration)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 64,
                child: IgnorePointer(
                  child: _AiWaveDecoration(
                    color: item.accentFor(isLight),
                    isLight: isLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  EdgeInsets _paddingForSize() {
    return switch (size) {
      _BentoTileSize.featured => const EdgeInsets.fromLTRB(13, 12, 12, 11),
      _BentoTileSize.featuredCompact => const EdgeInsets.all(12),
      _BentoTileSize.medium => const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 8,
        ),
      _BentoTileSize.fullWidth => const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 8,
        ),
      _BentoTileSize.bottom => const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 8,
        ),
      _BentoTileSize.bottomWide => const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 8,
        ),
    };
  }

  double _watermarkSizeForTile() {
    return switch (size) {
      _BentoTileSize.featured => 52,
      _BentoTileSize.featuredCompact => 48,
      _BentoTileSize.medium => 36,
      _BentoTileSize.fullWidth => 40,
      _BentoTileSize.bottom => 34,
      _BentoTileSize.bottomWide => 38,
    };
  }

  Widget _contentForSize(bool isLight) {
    return switch (size) {
      _BentoTileSize.featured => _featuredContent(isLight),
      _BentoTileSize.featuredCompact => _featuredCompactContent(isLight),
      _BentoTileSize.medium => _mediumContent(isLight),
      _BentoTileSize.fullWidth => _fullWidthContent(isLight),
      _BentoTileSize.bottom => _bottomContent(isLight, showSubtitle: false),
      _BentoTileSize.bottomWide => _bottomContent(isLight, showSubtitle: true),
    };
  }

  Widget _iconBadge(bool isLight, {double iconSize = 20, double box = 36}) {
    final accent = item.accentFor(isLight);
    final radius = box * 0.32;
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: accent.withValues(alpha: isLight ? 0.14 : 0.16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isLight ? 0.12 : 0.08),
            blurRadius: isLight ? 8 : 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Icon(item.icon, color: accent, size: iconSize),
    );
  }

  Widget _titleText(
    bool isLight, {
    double fontSize = 12,
    int maxLines = 2,
  }) {
    return Text(
      item.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.2,
        color: HomePremiumTheme.primaryText(isLight),
      ),
    );
  }

  Widget _subtitleText(bool isLight, {int maxLines = 2, double fontSize = 10}) {
    return Text(
      item.subtitle,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: HomePremiumTheme.secondaryText(isLight),
      ),
    );
  }

  Widget _ctaChip(bool isLight) {
    final accent = item.accentFor(isLight);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isLight ? 0.16 : 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.ctaLabel!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: accent,
          ),
        ],
      ),
    );
  }

  Widget _featuredContent(bool isLight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final showCta = item.ctaLabel != null && h >= 138;
        final showSubtitle = h >= 108;
        final subtitleLines = h >= 128 ? 2 : 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBadge(isLight, box: h >= 140 ? 40 : 36, iconSize: 20),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleText(isLight, fontSize: 13, maxLines: 2),
                    if (showSubtitle) ...[
                      const SizedBox(height: 3),
                      _subtitleText(
                        isLight,
                        maxLines: subtitleLines,
                        fontSize: 9.5,
                      ),
                    ],
                    if (showCta) ...[
                      const SizedBox(height: 7),
                      _ctaChip(isLight),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _featuredCompactContent(bool isLight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSubtitle = constraints.maxHeight >= 100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBadge(isLight, box: 36, iconSize: 19),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleText(isLight, fontSize: 13, maxLines: 2),
                    if (showSubtitle) ...[
                      const SizedBox(height: 3),
                      _subtitleText(isLight, maxLines: 2, fontSize: 9.5),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mediumContent(bool isLight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSubtitle = constraints.maxHeight >= 62;
        return Row(
          children: [
            _iconBadge(isLight, box: 30, iconSize: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _titleText(isLight, fontSize: 10.5, maxLines: 2),
                  if (showSubtitle) ...[
                    const SizedBox(height: 2),
                    _subtitleText(isLight, maxLines: 1, fontSize: 8.5),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fullWidthContent(bool isLight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final subtitleLines = constraints.maxHeight >= 60 ? 2 : 1;
        return Row(
          children: [
            _iconBadge(isLight, box: 34, iconSize: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _titleText(isLight, fontSize: 12, maxLines: 1),
                  const SizedBox(height: 2),
                  _subtitleText(
                    isLight,
                    maxLines: subtitleLines,
                    fontSize: 9.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40),
          ],
        );
      },
    );
  }

  Widget _bottomContent(bool isLight, {required bool showSubtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowSubtitle =
            showSubtitle && constraints.maxHeight >= 56;
        return Row(
          children: [
            _iconBadge(isLight, box: 30, iconSize: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _titleText(
                    isLight,
                    fontSize: 10.5,
                    maxLines: canShowSubtitle ? 2 : 1,
                  ),
                  if (canShowSubtitle) ...[
                    const SizedBox(height: 2),
                    _subtitleText(isLight, maxLines: 1, fontSize: 8.5),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Soft gradient tile surface with subtle inner depth — no borders.
class _SoftTileSurface extends StatelessWidget {
  final bool isLight;
  final _ExploreTileData item;

  const _SoftTileSurface({required this.isLight, required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accentFor(isLight);
    final base = isLight
        ? HomePremiumTheme.lightWarmBg
        : const Color(0xFF0A0A0A);
    final tintStart = Color.lerp(
      isLight ? HomePremiumTheme.lightCreamCard : base,
      accent,
      isLight ? 0.20 : 0.07,
    )!;
    final tintEnd = Color.lerp(
      isLight ? HomePremiumTheme.lightWarmBg : base,
      accent,
      isLight ? 0.10 : 0.11,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_QuickAccessV3State._tileRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tintStart, tintEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0xFF2A2D33).withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.22),
            blurRadius: isLight ? 12 : 10,
            offset: Offset(0, isLight ? 4 : 3),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_QuickAccessV3State._tileRadius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: isLight ? 0.65 : 0.05),
              Colors.transparent,
              isLight
                  ? const Color(0xFF2A2D33).withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.14),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

class _AiWaveDecoration extends StatelessWidget {
  final Color color;
  final bool isLight;

  const _AiWaveDecoration({required this.color, required this.isLight});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WavePainter(
        color: color.withValues(alpha: isLight ? 0.16 : 0.12),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < 3; i++) {
      final path = Path();
      final yOffset = size.height * (0.2 + i * 0.28);
      path.moveTo(0, yOffset);
      final waveW = size.width / 2.5;
      for (var x = 0.0; x <= size.width; x += waveW) {
        path.quadraticBezierTo(
          x + waveW * 0.5,
          yOffset + (i.isEven ? 5 : -5),
          x + waveW,
          yOffset,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ExploreTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? ctaLabel;
  final bool showWaveDecoration;

  const _ExploreTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.ctaLabel,
    this.showWaveDecoration = false,
  });

  /// Slightly deeper accents in light mode for contrast on cream tiles.
  Color accentFor(bool isLight) {
    if (!isLight) return accent;
    return switch (title) {
      'Nutrition Goals' => const Color(0xFF1FA876),
      'Coach Notes' || 'Client Notes' => const Color(0xFFE85555),
      'Video Sessions' => const Color(0xFF6D5CE6),
      'AI Planner' => const Color(0xFFE89A10),
      'Become a Trainer' => const Color(0xFF3A96C4),
      'Subscription' => const Color(0xFFD4187A),
      _ => Color.lerp(accent, HomePremiumTheme.lightCharcoalText, 0.10)!,
    };
  }
}
