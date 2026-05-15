import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import 'home_premium_theme.dart';
import '../common/pressable_card.dart';

/// Quick actions — horizontal stacked carousel (swipe to cycle cards).
class QuickAccessV3 extends ConsumerStatefulWidget {
  const QuickAccessV3({super.key});

  @override
  ConsumerState<QuickAccessV3> createState() => _QuickAccessV3State();
}

class _QuickAccessV3State extends ConsumerState<QuickAccessV3> {
  static const int _visibleLayers = 3;
  static const double _cardHeight = 92.0;
  static const double _layerShiftX = 14.0;
  static const double _layerScaleStep = 0.045;

  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static LinearGradient _surfaceTint(
    ColorScheme cs,
    bool isLight,
    LinearGradient accent,
  ) {
    final top = accent.colors.first;
    final bottom =
        accent.colors.length > 1 ? accent.colors.last : accent.colors.first;
    final a0 = isLight ? 0.34 : 0.40;
    final a1 = isLight ? 0.22 : 0.26;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(cs.surface, top, a0)!,
        Color.lerp(cs.surface, bottom, a1)!,
        cs.surface,
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  List<_QuickTileData> _itemsForRole(String userRole) {
    final exclude = <String>[];
    if (userRole == 'trainer' || userRole == 'nutritionist') {
      exclude.addAll(['BECOME A TRAINER', 'SUBSCRIPTION', 'AI PLANNER', 'NOTES']);
    }
    return [
      if (!exclude.contains('NOTES'))
        _QuickTileData(
          'Coach Notes',
          Icons.note_rounded,
          const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFE96A6A)]),
        ),
      _QuickTileData(
        'Video Sessions',
        Icons.videocam_rounded,
        const LinearGradient(colors: [AppColors.purple, Color(0xFFB38CFF)]),
      ),
      if (!exclude.contains('AI PLANNER'))
        _QuickTileData(
          'AI Planner',
          Icons.auto_awesome_rounded,
          const LinearGradient(colors: [AppColors.orange, AppColors.yellow]),
        ),
      if (!exclude.contains('BECOME A TRAINER'))
        _QuickTileData(
          'Become a Trainer',
          Icons.school_rounded,
          AppColors.becomeTrainerGradient,
        ),
      if (!exclude.contains('SUBSCRIPTION'))
        _QuickTileData(
          'Subscription',
          Icons.card_membership_rounded,
          const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
        ),
    ];
  }

  VoidCallback? _routeFor(BuildContext context, String title) {
    switch (title) {
      case 'AI Planner':
        return () => context.push('/ai-planner');
      case 'Become a Trainer':
        return () => context.push('/trainer/become');
      case 'Coach Notes':
        return () => context.push('/coach-notes');
      case 'Video Sessions':
        return () => context.push('/video');
      default:
        return null;
    }
  }

  void _goTo(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final role =
        Supabase.instance.client.auth.currentUser?.userMetadata?['role']
                ?.toString()
                .toLowerCase() ??
            'client';
    final items = _itemsForRole(role);

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
              ).createShader(b),
              child: const Icon(Icons.bolt_rounded, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.blue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: GoogleFonts.montserrat(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w500,
                color: HomePremiumTheme.primaryText(isLight),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _cardHeight,
          child: items.length == 1
              ? _QuickActionCard(
                  item: items[0],
                  isFront: true,
                  isLight: isLight,
                  colorScheme: cs,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _routeFor(context, items[0].title)?.call();
                  },
                )
              : PageView.builder(
                  controller: _pageController,
                  padEnds: true,
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _activeIndex = i),
                  itemBuilder: (context, pageIndex) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        final page = _pageController.hasClients
                            ? (_pageController.page ?? pageIndex.toDouble()) -
                                pageIndex
                            : 0.0;
                        final focus = (1 - page.abs()).clamp(0.0, 1.0);
                        final parallax = page * 10.0;

                        return Transform.translate(
                          offset: Offset(parallax, 0),
                          child: Opacity(
                            opacity: 0.55 + focus * 0.45,
                            child: Transform.scale(
                              scale: 0.94 + focus * 0.06,
                              alignment: Alignment.centerLeft,
                              child: _HorizontalStackSlide(
                                items: items,
                                frontIndex: pageIndex,
                                isLight: isLight,
                                colorScheme: cs,
                                cardHeight: _cardHeight,
                                layerShiftX: _layerShiftX,
                                layerScaleStep: _layerScaleStep,
                                maxLayers: _visibleLayers,
                                focus: focus,
                                onOpen: (title) {
                                  HapticFeedback.lightImpact();
                                  _routeFor(context, title)?.call();
                                },
                                onBringForward: _goTo,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _activeIndex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _goTo(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? items[i].gradient.colors.first
                        : HomePremiumTheme.secondaryText(isLight)
                            .withValues(alpha: 0.28),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _QuickTileData {
  final String title;
  final IconData icon;
  final LinearGradient gradient;

  const _QuickTileData(this.title, this.icon, this.gradient);
}

/// Cards fan to the right; front card is left-most and tappable.
class _HorizontalStackSlide extends StatelessWidget {
  final List<_QuickTileData> items;
  final int frontIndex;
  final bool isLight;
  final ColorScheme colorScheme;
  final double cardHeight;
  final double layerShiftX;
  final double layerScaleStep;
  final int maxLayers;
  final double focus;
  final void Function(String title) onOpen;
  final void Function(int index) onBringForward;

  const _HorizontalStackSlide({
    required this.items,
    required this.frontIndex,
    required this.isLight,
    required this.colorScheme,
    required this.cardHeight,
    required this.layerShiftX,
    required this.layerScaleStep,
    required this.maxLayers,
    required this.focus,
    required this.onOpen,
    required this.onBringForward,
  });

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    final layers = n < maxLayers ? n : maxLayers;
    final backInset = layerShiftX * (layers - 1);

    return Padding(
      padding: EdgeInsets.only(right: backInset),
      child: SizedBox(
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            for (int depth = layers - 1; depth >= 1; depth--)
              Positioned(
                left: depth * layerShiftX,
                top: 0,
                right: 0,
                height: cardHeight,
                child: Transform.scale(
                  scale: 1 - depth * layerScaleStep,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: 0.72 + focus * 0.2,
                    child: _QuickActionCard(
                      item: items[(frontIndex + depth) % n],
                      isFront: false,
                      isLight: isLight,
                      colorScheme: colorScheme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onBringForward((frontIndex + depth) % n);
                      },
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: cardHeight,
              child: _QuickActionCard(
                item: items[frontIndex],
                isFront: true,
                isLight: isLight,
                colorScheme: colorScheme,
                onTap: () => onOpen(items[frontIndex].title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickTileData item;
  final bool isFront;
  final bool isLight;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.item,
    required this.isFront,
    required this.isLight,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.gradient.colors.first;
    final gradient = _QuickAccessV3State._surfaceTint(
      colorScheme,
      isLight,
      item.gradient,
    );

    return PressableCard(
      onTap: onTap,
      borderRadius: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: isFront ? 0.28 : 0.14),
          ),
          boxShadow: isFront ? HomePremiumTheme.softCardShadow(isLight) : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isFront ? 14 : 12,
            vertical: isFront ? 14 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: isFront ? 42 : 36,
                height: isFront ? 42 : 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: accent,
                  size: isFront ? 22 : 18,
                ),
              ),
              SizedBox(width: isFront ? 12 : 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: isFront ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isFront ? 14 : 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: HomePremiumTheme.primaryText(isLight).withValues(
                      alpha: isFront ? 1.0 : 0.78,
                    ),
                  ),
                ),
              ),
              if (isFront)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: HomePremiumTheme.secondaryText(isLight),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
