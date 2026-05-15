import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_role_provider.dart';
import 'home_page_v3.dart';
import '../discover/discover_page.dart';
import '../messaging/messaging_page.dart';
import '../meal_tracker/meal_tracker_page_v2.dart';
import '../profile/profile_page.dart';
import '../trainer/trainer_my_clients_page.dart';
import '../nutritionist/nutritionist_my_clients_page.dart';
import '../../providers/unread_messages_count_provider.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  final bool showWelcome;

  const HomeShellPage({
    super.key,
    this.showWelcome = false,
  });

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage>
    with SingleTickerProviderStateMixin {
  /// Matches metrics / BMI / quick-action tile gradients.
  static LinearGradient _surfaceTintGradient(
    ColorScheme cs,
    bool isLight,
    LinearGradient accent,
  ) {
    final top = accent.colors.first;
    final bottom =
        accent.colors.length > 1 ? accent.colors.last : accent.colors.first;
    final a0 = isLight ? 0.48 : 0.54;
    final a1 = isLight ? 0.34 : 0.38;
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

  static const double _navBarRadius = 20;
  static const double _navItemRadius = 10;

  static LinearGradient _navBarWhiteGlassGradient(bool isLight) {
    if (isLight) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.88),
          Colors.white.withValues(alpha: 0.78),
          Colors.white.withValues(alpha: 0.84),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.18),
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.16),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  int _currentIndex = 0;
  late final PageController _pageController;
  late final AnimationController _welcomeController;
  late final Animation<double> _welcomeFade;
  late final Animation<Offset> _welcomeSlide;
  bool _showWelcomeBubble = false;

  /// 0 Home, 1 Discover/My Clients, 2 Messages, 3 Meals, 4 Profile
  List<NavigationItem> get _navigationItems {
    final user = ref.watch(currentUserProvider).value;
    final isProvider = user?.isProvider ?? false;

    return [
      NavigationItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        route: '/home',
        gradient: LinearGradient(
          colors: [DesignTokens.accentOrange, DesignTokens.accentAmber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      NavigationItem(
        icon: isProvider ? Icons.person_add_outlined : Icons.explore_outlined,
        activeIcon: isProvider ? Icons.person_add : Icons.explore,
        label: isProvider ? 'My Clients' : 'Discover',
        route: isProvider ? '/home/clients' : '/home/discover',
        gradient: const LinearGradient(
          colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      NavigationItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_rounded,
        label: 'Messages',
        route: '/home/messages',
        gradient: const LinearGradient(
          colors: [Color(0xFF4DA3FF), Color(0xFF00C9C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      NavigationItem(
        icon: Icons.restaurant_outlined,
        activeIcon: Icons.restaurant_rounded,
        label: 'Meals',
        route: '/home/meals',
        gradient: const LinearGradient(
          colors: [Color(0xFF3ED598), Color(0xFF65E6B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      NavigationItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        route: '/home/profile',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5A5A), Color(0xFFFF8A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _welcomeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.showWelcome) {
      _showWelcomeBubble = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _welcomeController.forward();
        }
      });
      Future.delayed(const Duration(milliseconds: 3300), () {
        if (mounted && _showWelcomeBubble) {
          _welcomeController.reverse().then((_) {
            if (mounted) {
              setState(() => _showWelcomeBubble = false);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _welcomeController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final user = ref.watch(currentUserProvider).value;
                final isTrainer = user?.isTrainer ?? false;
                final isNutritionist = user?.isNutritionist ?? false;

                final pages = [
                  HomePageV3(
                    onNavigateToMessagesTab: () => _goToTab(2),
                    onNavigateToMealsTab: () => _goToTab(3),
                  ),
                  isTrainer
                      ? const TrainerMyClientsPage()
                      : isNutritionist
                          ? const NutritionistMyClientsPage()
                          : const DiscoverPage(),
                  const MessagingPage(),
                  const MealTrackerPageV2(),
                  const ProfilePage(),
                ];
                return KeyedSubtree(
                  key: ValueKey<int>(index),
                  child: pages[index],
                );
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_navBarRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_navBarRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _navBarWhiteGlassGradient(isLight),
                      borderRadius: BorderRadius.circular(_navBarRadius),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isLight ? 0.65 : 0.28,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(
                          _navigationItems.length,
                          (index) => Expanded(
                            child: _buildNavItem(index),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showWelcomeBubble)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: SlideTransition(
                position: _welcomeSlide,
                child: FadeTransition(
                  opacity: _welcomeFade,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing20,
                        vertical: DesignTokens.spacing16,
                      ),
                      decoration: BoxDecoration(
                        gradient: DesignTokens.primaryGradient,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: DesignTokens.spacing12),
                          Expanded(
                            child: Text(
                              'Welcome back!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: DesignTokens.fontSizeBody,
                                fontWeight: DesignTokens.fontWeightSemiBold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _welcomeController.reverse().then((_) {
                                if (mounted) {
                                  setState(() => _showWelcomeBubble = false);
                                }
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
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

  Widget _buildNavItem(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final item = _navigationItems[index];
    final isActive = _currentIndex == index;
    final homeAmber = const LinearGradient(
      colors: [DesignTokens.accentOrange, DesignTokens.accentAmber],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final activeGradient =
        isActive && index == 0 ? homeAmber : item.gradient;
    final accent = activeGradient.colors.first;

    final badge = index == 2 ? ref.watch(unreadMessagesCountProvider) : null;
    final showUnreadDot = badge != null && badge.maybeWhen(data: (c) => c > 0, orElse: () => false);

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
          _pageController.jumpToPage(index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          gradient: isActive
              ? _surfaceTintGradient(colorScheme, isLight, activeGradient)
              : null,
          borderRadius: BorderRadius.circular(_navItemRadius),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: isLight ? 0.2 : 0.28),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive
                  ? accent
                  : (isLight
                      ? const Color(0xFF6B7280)
                      : colorScheme.onSurface.withValues(alpha: 0.5)),
              size: 24,
            ),
            if (showUnreadDot)
              Positioned(
                top: -2,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final LinearGradient gradient;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.gradient,
  });
}
