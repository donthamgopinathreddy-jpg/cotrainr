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

/// Quick actions — infinite loop carousel with circular swipe.
class QuickAccessV3 extends ConsumerStatefulWidget {
  const QuickAccessV3({super.key});

  @override
  ConsumerState<QuickAccessV3> createState() => _QuickAccessV3State();
}

class _QuickAccessV3State extends ConsumerState<QuickAccessV3> {
  static const int _kLoopLength = 40000;
  static const int _kInitialPage = 20000;
  static const double _cardHeight = 72.0;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.86,
      initialPage: _kInitialPage,
      keepPage: true,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _logicalIndex {
    if (!_pageController.hasClients) {
      return 0;
    }
    final p = (_pageController.page ?? _kInitialPage.toDouble()).round();
    final items = _itemsForRole(_role);
    if (items.isEmpty) return 0;
    return ((p % items.length) + items.length) % items.length;
  }

  String get _role =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['role']
          ?.toString()
          .toLowerCase() ??
      'client';

  static LinearGradient _cardGradient(
    ColorScheme cs,
    bool isLight,
    LinearGradient source,
  ) {
    final blend = isLight ? 0.52 : 0.44;
    final surface = isLight ? HomePremiumTheme.lightCreamCard : cs.surface;
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
          subtitle: 'Notes for clients',
        ),
      if (!isTrainer && !isNutritionist)
        _QuickTileData(
          title: 'Coach Notes',
          icon: Icons.note_rounded,
          accent: const Color(0xFFE53935),
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFF8A80)],
          ),
        ),
      _QuickTileData(
        title: 'Video Sessions',
        icon: Icons.videocam_rounded,
        accent: const Color(0xFF7C6AE6),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6AE6), Color(0xFFB4A7FF)],
        ),
      ),
      _QuickTileData(
        title: 'Nutrition Goals',
        icon: Icons.track_changes_rounded,
        accent: const Color(0xFF2EBD85),
        gradient: const LinearGradient(
          colors: [Color(0xFF2EBD85), Color(0xFF65E6B3)],
        ),
        subtitle: 'Calculate macros',
      ),
      if (!exclude.contains('AI PLANNER'))
        _QuickTileData(
          title: 'AI Planner',
          icon: Icons.auto_awesome_rounded,
          accent: const Color(0xFFFF9500),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9500), Color(0xFFFFD54F)],
          ),
        ),
      if (!exclude.contains('BECOME A TRAINER'))
        _QuickTileData(
          title: 'Become a Trainer',
          icon: Icons.school_rounded,
          accent: AppColors.becomeTrainerAccent,
          gradient: AppColors.becomeTrainerGradient,
        ),
      if (!exclude.contains('SUBSCRIPTION'))
        _QuickTileData(
          title: 'Subscription',
          icon: Icons.card_membership_rounded,
          accent: const Color(0xFFE91E8C),
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E8C), Color(0xFFFF6BB5)],
          ),
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
      final logical = ((page % n) + n) % n;
      final mid = _kLoopLength ~/ 2;
      final aligned = mid - (mid % n) + logical;
      _pageController.jumpToPage(aligned);
    });
  }

  void _goToLogical(int logicalIndex) {
    if (!_pageController.hasClients) return;
    final items = _itemsForRole(_role);
    final n = items.length;
    if (n == 0) return;

    final pos = _pageController.page ?? _kInitialPage.toDouble();
    final p = pos.round();
    final at = ((p % n) + n) % n;
    final target = p - at + logicalIndex;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Flat carousel transform — scale + fade only (no 3D / vertical stacking).
  static Widget _carouselPageChild({
    required double pageOffset,
    required Widget child,
  }) {
    final focus = (1 - pageOffset.abs()).clamp(0.0, 1.0);
    final scale = 0.86 + focus * 0.14;
    final opacity = 0.38 + focus * 0.62;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final items = _itemsForRole(_role);

    if (items.isEmpty) return const SizedBox.shrink();

    final activeIndex = _logicalIndex;

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
        const SizedBox(height: 10),
        SizedBox(
          height: _cardHeight + 8,
          child: items.length == 1
              ? _QuickActionCard(
                  item: items[0],
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
                  pageSnapping: true,
                  clipBehavior: Clip.hardEdge,
                  physics: const PageScrollPhysics(),
                  itemCount: _kLoopLength,
                  onPageChanged: (i) {
                    setState(() {});
                    _realignLoopIfNeeded(i);
                  },
                  itemBuilder: (context, index) {
                    final logical = index % items.length;
                    final item = items[logical];

                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        final page = _pageController.hasClients
                            ? (_pageController.page ?? index.toDouble()) - index
                            : 0.0;

                        return Align(
                          alignment: Alignment.center,
                          child: _carouselPageChild(
                            pageOffset: page,
                            child: SizedBox(
                              height: _cardHeight,
                              width: double.infinity,
                              child: _QuickActionCard(
                                item: item,
                                isLight: isLight,
                                colorScheme: cs,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (page.abs() < 0.35) {
                                    _routeFor(context, item.title)?.call();
                                  } else {
                                    _goToLogical(logical);
                                  }
                                },
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == activeIndex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _goToLogical(i);
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
                        ? items[i].accent
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
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final LinearGradient gradient;

  const _QuickTileData({
    required this.title,
    required this.icon,
    required this.accent,
    required this.gradient,
    this.subtitle,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickTileData item;
  final bool isLight;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.item,
    required this.isLight,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.accent;
    final fill = _QuickAccessV3State._cardGradient(
      colorScheme,
      isLight,
      item.gradient,
    );

    return PressableCard(
      onTap: onTap,
      borderRadius: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: fill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: HomePremiumTheme.softCardShadow(isLight),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isLight ? 0.22 : 0.28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: HomePremiumTheme.primaryText(isLight),
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: HomePremiumTheme.secondaryText(isLight),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
