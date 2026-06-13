import 'dart:math' as math;

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

/// Quick actions — stacked deck carousel with layered depth and infinite loop.
class QuickAccessV3 extends ConsumerStatefulWidget {
  const QuickAccessV3({super.key});

  @override
  ConsumerState<QuickAccessV3> createState() => _QuickAccessV3State();
}

class _QuickAccessV3State extends ConsumerState<QuickAccessV3> {
  static const int _kLoopLength = 40000;
  static const int _kInitialPage = 20000;

  static const double _cardRadius = 24;
  static const double _activeCardHeight = 136;
  static const Duration _snapDuration = Duration(milliseconds: 300);

  late final PageController _pageController;
  int _lastSnappedPage = _kInitialPage;
  double? _lastPageValue;
  int _swipeDirection = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _kInitialPage);
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (_pageController.hasClients) {
      final p = _pageController.page!;
      if (_lastPageValue != null) {
        if (p > _lastPageValue! + 0.0001) {
          _swipeDirection = 1;
        } else if (p < _lastPageValue! - 0.0001) {
          _swipeDirection = -1;
        }
      }
      _lastPageValue = p;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  String get _role =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['role']
          ?.toString()
          .toLowerCase() ??
      'client';

  static int _mod(int value, int length) {
    if (length == 0) return 0;
    return ((value % length) + length) % length;
  }

  static LinearGradient _cardGradient(
    ColorScheme cs,
    bool isLight,
    LinearGradient source,
  ) {
    final blend = isLight ? 0.48 : 0.4;
    final surface = isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(surface, source.colors.first, blend)!,
        Color.lerp(surface, source.colors.last, blend)!,
      ],
    );
  }

  List<_QuickTileData> _itemsForRole(String userRole) {
    final exclude = <String>[];
    final isTrainer = userRole == 'trainer';
    final isNutritionist = userRole == 'nutritionist';
    if (isTrainer || isNutritionist) {
      exclude.addAll([
        'BECOME A TRAINER',
        'SUBSCRIPTION',
        'AI PLANNER',
        'Coach Notes',
      ]);
    }
    return [
      if (isTrainer)
        _QuickTileData(
          title: 'Client Notes',
          icon: Icons.edit_note_rounded,
          accent: const Color(0xFFE53935),
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFF8A80)],
          ),
          description: 'Capture session notes and progress for each client.',
        ),
      if (!isTrainer && !isNutritionist)
        _QuickTileData(
          title: 'Coach Notes',
          icon: Icons.note_rounded,
          accent: const Color(0xFFE53935),
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFF8A80)],
          ),
          description: 'Review guidance and notes from your coach.',
        ),
      _QuickTileData(
        title: 'Video Sessions',
        icon: Icons.videocam_rounded,
        accent: const Color(0xFF7C6AE6),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6AE6), Color(0xFFB4A7FF)],
        ),
        description: 'Join or schedule live coaching sessions.',
      ),
      _QuickTileData(
        title: 'Nutrition Goals',
        icon: Icons.track_changes_rounded,
        accent: const Color(0xFF2EBD85),
        gradient: const LinearGradient(
          colors: [Color(0xFF2EBD85), Color(0xFF65E6B3)],
        ),
        description:
            'Calculate calories, protein, carbs and fats based on your goal.',
      ),
      if (!exclude.contains('AI PLANNER'))
        _QuickTileData(
          title: 'AI Planner',
          icon: Icons.auto_awesome_rounded,
          accent: const Color(0xFFFF9500),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9500), Color(0xFFFFD54F)],
          ),
          description: 'Build smart workout plans tailored to your goals.',
        ),
      if (!exclude.contains('BECOME A TRAINER'))
        _QuickTileData(
          title: 'Become a Trainer',
          icon: Icons.school_rounded,
          accent: AppColors.becomeTrainerAccent,
          gradient: AppColors.becomeTrainerGradient,
          description: 'Apply to coach clients and grow your practice.',
        ),
      if (!exclude.contains('SUBSCRIPTION'))
        _QuickTileData(
          title: 'Subscription',
          icon: Icons.card_membership_rounded,
          accent: const Color(0xFFE91E8C),
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E8C), Color(0xFFFF6BB5)],
          ),
          description: 'Manage your plan and unlock premium features.',
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

  void _realignLoopIfNeeded(int page) {
    const margin = 800;
    if (page >= margin && page < _kLoopLength - margin) return;
    final items = _itemsForRole(_role);
    if (items.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final n = items.length;
      final logical = _mod(page, n);
      final mid = _kLoopLength ~/ 2;
      final aligned = mid - (mid % n) + logical;
      _pageController.jumpToPage(aligned);
      _lastSnappedPage = aligned;
    });
  }

  void _goToLogical(int logicalIndex) {
    if (!_pageController.hasClients) return;
    final items = _itemsForRole(_role);
    final n = items.length;
    if (n == 0) return;

    final pos = _pageController.page ?? _kInitialPage.toDouble();
    final p = pos.round();
    final at = _mod(p, n);
    final target = p - at + logicalIndex;
    _pageController.animateToPage(
      target,
      duration: _snapDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageSnapped(int page) {
    final items = _itemsForRole(_role);
    if (items.isEmpty) return;
    final n = items.length;
    final logical = _mod(page, n);
    final lastLogical = _mod(_lastSnappedPage, n);
    if (logical != lastLogical) {
      HapticFeedback.lightImpact();
    }
    _lastSnappedPage = page;
    _realignLoopIfNeeded(page);
    setState(() {});
  }

  double _logicalPageFraction(List<_QuickTileData> items) {
    if (items.isEmpty) return 0;
    final n = items.length;
    final page = _pageController.hasClients
        ? (_pageController.page ?? _kInitialPage.toDouble())
        : _kInitialPage.toDouble();
    final mod = page % n;
    return mod < 0 ? mod + n : mod;
  }

  int _logicalIndex(List<_QuickTileData> items) {
    if (items.isEmpty) return 0;
    return _mod(_logicalPageFraction(items).round(), items.length);
  }

  /// Room for stacked layers without bottom clip/overflow.
  double get _deckHeight => _activeCardHeight + 20 + 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final items = _itemsForRole(_role);

    if (items.isEmpty) return const SizedBox.shrink();

    final pageFraction = _logicalPageFraction(items);
    final activeIndex = _logicalIndex(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
          height: _deckHeight,
          child: items.length == 1
              ? _DeckCard(
                  item: items[0],
                  isLight: isLight,
                  colorScheme: cs,
                  isActive: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _routeFor(context, items[0].title)?.call();
                  },
                )
              : ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, _) {
                          final page = _pageController.hasClients
                              ? (_pageController.page ?? _kInitialPage.toDouble())
                              : _kInitialPage.toDouble();
                          return _StackedDeck(
                            page: page,
                            swipeDirection: _swipeDirection,
                            items: items,
                            isLight: isLight,
                            colorScheme: cs,
                            cardHeight: _activeCardHeight,
                            onActiveTap: (item) {
                              HapticFeedback.lightImpact();
                              _routeFor(context, item.title)?.call();
                            },
                          );
                        },
                      ),
                      PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(
                          parent: PageScrollPhysics(),
                        ),
                        itemCount: _kLoopLength,
                        onPageChanged: _onPageSnapped,
                        itemBuilder: (context, index) {
                          final logical = _mod(index, items.length);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final current = _logicalIndex(items);
                              if (current == logical) {
                                HapticFeedback.lightImpact();
                                _routeFor(context, items[logical].title)?.call();
                              } else {
                                _goToLogical(logical);
                              }
                            },
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 10),
          _AnimatedDotIndicator(
            count: items.length,
            pageFraction: pageFraction,
            activeIndex: activeIndex,
            accent: items[activeIndex].accent,
            isLight: isLight,
            onDotTap: _goToLogical,
          ),
        ],
      ],
    );
  }
}

class _StackLayerStyle {
  final double scale;
  final double opacity;
  final double offsetY;
  final double elevation;

  const _StackLayerStyle({
    required this.scale,
    required this.opacity,
    required this.offsetY,
    required this.elevation,
  });

  static const rest0 = _StackLayerStyle(
    scale: 1.0,
    opacity: 1.0,
    offsetY: 0,
    elevation: 12,
  );
  static const rest1 = _StackLayerStyle(
    scale: 0.94,
    opacity: 0.8,
    offsetY: 12,
    elevation: 6,
  );
  static const rest2 = _StackLayerStyle(
    scale: 0.88,
    opacity: 0.6,
    offsetY: 24,
    elevation: 2,
  );

  _StackLayerStyle lerp(_StackLayerStyle other, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return _StackLayerStyle(
      scale: scale + (other.scale - scale) * clamped,
      opacity: opacity + (other.opacity - opacity) * clamped,
      offsetY: offsetY + (other.offsetY - offsetY) * clamped,
      elevation: elevation + (other.elevation - elevation) * clamped,
    );
  }
}

class _StackedDeck extends StatelessWidget {
  final double page;
  final int swipeDirection;
  final List<_QuickTileData> items;
  final bool isLight;
  final ColorScheme colorScheme;
  final double cardHeight;
  final ValueChanged<_QuickTileData> onActiveTap;

  const _StackedDeck({
    required this.page,
    required this.swipeDirection,
    required this.items,
    required this.isLight,
    required this.colorScheme,
    required this.cardHeight,
    required this.onActiveTap,
  });

  int _mod(int value) => _QuickAccessV3State._mod(value, items.length);

  double get _logicalPage {
    final n = items.length;
    final mod = page % n;
    return mod < 0 ? mod + n : mod;
  }

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    final lp = _logicalPage;
    final base = lp.floor();
    final frac = lp - base;
    final width = MediaQuery.sizeOf(context).width;

    // At rest — show a stable three-layer stack.
    if (frac < 0.002 || frac > 0.998) {
      final focus = frac > 0.998 ? _mod(base + 1) : _mod(base);
      return _restStack(context, focus, width);
    }

    final forward = swipeDirection >= 0;
    final raw = forward ? frac : 1 - frac;
    final slide = Curves.easeOutCubic.transform(raw);

    final outgoing = forward ? _mod(base) : _mod(base + 1);
    final incoming = forward ? _mod(base + 1) : _mod(base);
    final deepest = forward ? _mod(base + 2) : _mod(base - 1);

    final layers = <Widget>[];

    if (n > 2) {
      layers.add(
        _positionedCard(
          item: items[deepest],
          style: _StackLayerStyle.rest2.lerp(_StackLayerStyle.rest1, slide),
          isActive: false,
          width: width,
        ),
      );
    }

    layers.add(
      _positionedCard(
        item: items[incoming],
        style: _StackLayerStyle.rest1.lerp(_StackLayerStyle.rest0, slide),
        isActive: slide > 0.18,
        width: width,
        onTap: slide > 0.55 ? () => onActiveTap(items[incoming]) : null,
      ),
    );

    layers.add(
      _positionedCard(
        item: items[outgoing],
        style: _StackLayerStyle.rest0,
        isActive: slide < 0.35,
        width: width,
        slideX: (forward ? -1 : 1) * slide * width * 0.42,
        opacityOverride: (1 - slide).clamp(0.0, 1.0),
        scaleOverride: 1 - slide * 0.045,
        onTap: slide < 0.25 ? () => onActiveTap(items[outgoing]) : null,
      ),
    );

    return Stack(
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.topCenter,
      children: layers,
    );
  }

  Widget _restStack(BuildContext context, int focusIndex, double width) {
    final layers = <Widget>[];

    if (items.length > 2) {
      layers.add(
        _positionedCard(
          item: items[_mod(focusIndex + 2)],
          style: _StackLayerStyle.rest2,
          isActive: false,
          width: width,
        ),
      );
    }

    if (items.length > 1) {
      layers.add(
        _positionedCard(
          item: items[_mod(focusIndex + 1)],
          style: _StackLayerStyle.rest1,
          isActive: false,
          width: width,
        ),
      );
    }

    layers.add(
      _positionedCard(
        item: items[focusIndex],
        style: _StackLayerStyle.rest0,
        isActive: true,
        width: width,
        onTap: () => onActiveTap(items[focusIndex]),
      ),
    );

    return Stack(
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.topCenter,
      children: layers,
    );
  }

  Widget _positionedCard({
    required _QuickTileData item,
    required _StackLayerStyle style,
    required bool isActive,
    required double width,
    double slideX = 0,
    double? opacityOverride,
    double? scaleOverride,
    VoidCallback? onTap,
  }) {
    final opacity = opacityOverride ?? style.opacity;
    final scale = scaleOverride ?? style.scale;

    return Positioned(
      top: style.offsetY,
      left: 0,
      right: 0,
      child: Transform.translate(
        offset: Offset(slideX, 0),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: _DeckCard(
              item: item,
              isLight: isLight,
              colorScheme: colorScheme,
              isActive: isActive,
              elevation: style.elevation,
              height: cardHeight,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  final _QuickTileData item;
  final bool isLight;
  final ColorScheme colorScheme;
  final bool isActive;
  final double elevation;
  final double height;
  final VoidCallback? onTap;

  const _DeckCard({
    required this.item,
    required this.isLight,
    required this.colorScheme,
    required this.isActive,
    this.elevation = 12,
    this.height = 136,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = _QuickAccessV3State._cardGradient(
      colorScheme,
      isLight,
      item.gradient,
    );
    final accent = item.accent;

    return PressableCard(
      onTap: onTap,
      borderRadius: _QuickAccessV3State._cardRadius,
      enableHaptic: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: fill,
          borderRadius: BorderRadius.circular(_QuickAccessV3State._cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.07 : 0.28),
              blurRadius: elevation,
              offset: Offset(0, elevation / 3),
            ),
          ],
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: isActive ? _activeContent(accent) : _compactContent(accent),
          ),
        ),
      ),
    );
  }

  Widget _activeContent(Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isLight ? 0.2 : 0.26),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomePremiumTheme.primaryText(isLight),
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  color: HomePremiumTheme.secondaryText(isLight),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            item.icon,
            size: 40,
            color: accent.withValues(alpha: isLight ? 0.32 : 0.42),
          ),
        ),
      ],
    );
  }

  Widget _compactContent(Color accent) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isLight ? 0.2 : 0.26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: HomePremiumTheme.primaryText(isLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDotIndicator extends StatelessWidget {
  final int count;
  final double pageFraction;
  final int activeIndex;
  final Color accent;
  final bool isLight;
  final ValueChanged<int> onDotTap;

  const _AnimatedDotIndicator({
    required this.count,
    required this.pageFraction,
    required this.activeIndex,
    required this.accent,
    required this.isLight,
    required this.onDotTap,
  });

  double _focusForDot(int index) {
    final delta = (pageFraction - index).abs();
    final wrapped = math.min(delta, count - delta);
    return (1 - wrapped).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final muted = HomePremiumTheme.secondaryText(isLight).withValues(alpha: 0.28);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final focus = _focusForDot(i);
        final width = 6 + focus * 12;
        final height = 6.0;
        final color = Color.lerp(muted, accent, focus)!;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onDotTap(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: color,
              boxShadow: focus > 0.6
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _QuickTileData {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final LinearGradient gradient;

  const _QuickTileData({
    required this.title,
    required this.icon,
    required this.accent,
    required this.gradient,
    required this.description,
  });
}
