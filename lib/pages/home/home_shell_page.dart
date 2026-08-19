import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/post_auth_destination.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_role_provider.dart';
import 'home_page_v3.dart';
import '../trainer/trainer_home_page.dart';
import '../nutritionist/nutritionist_home_page.dart';
import '../discover/discover_page.dart';
import '../messaging/messaging_page.dart';
import '../meal_tracker/meal_tracker_page_v2.dart';
import '../profile/profile_page.dart';
import '../trainer/trainer_my_clients_page.dart';
import '../nutritionist/nutritionist_my_clients_page.dart';
import '../../providers/unread_messages_count_provider.dart';
import '../../providers/unread_notifications_count_provider.dart';
import '../../providers/unread_video_session_notifications_provider.dart';
import '../../services/video_session_pending_navigation.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  final bool showWelcome;
  final int initialTabIndex;

  const HomeShellPage({
    super.key,
    this.showWelcome = false,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _navBarRadius = 20;

  int _currentIndex = 0;
  final Set<int> _visitedTabIndexes = {0};
  final List<Widget?> _pageCache = List.filled(5, null);
  late final AnimationController _welcomeController;
  late final Animation<double> _welcomeFade;
  late final Animation<Offset> _welcomeSlide;
  bool _showWelcomeBubble = false;
  RealtimeChannel? _badgeChannel;

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
        gradient: DesignTokens.discoverGradient,
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
    WidgetsBinding.instance.addObserver(this);
    final tab = widget.initialTabIndex;
    if (tab > 0 && tab < 5) {
      _currentIndex = tab;
      _visitedTabIndexes.add(tab);
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _subscribeBadgeRealtime();
      unawaited(_applyPendingVideoSessionAction());
    });
    unawaited(_guardIncompleteOnboarding());
  }

  Future<void> _applyPendingVideoSessionAction() async {
    final route = await VideoSessionPendingNavigation.peek();
    if (route == null || !mounted) return;
    await VideoSessionPendingNavigation.consume();
    if (!mounted) return;
    context.go(route);
  }

  Future<void> _guardIncompleteOnboarding() async {
    try {
      final incomplete = await PostAuthDestination.isProfileIncomplete()
          .timeout(PostAuthDestination.networkTimeout);
      if (!mounted) return;
      if (incomplete) context.go('/auth/complete-profile');
    } catch (_) {
      // Lookup failure: do not bounce a possibly-complete user.
    }
  }

  void _subscribeBadgeRealtime() {
    _badgeChannel?.unsubscribe();
    _badgeChannel = Supabase.instance.client
        .channel('home-shell-badges')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) ref.invalidate(unreadMessagesCountProvider);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) ref.invalidate(unreadMessagesCountProvider);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (_) {
            if (mounted) {
              ref.invalidate(unreadNotificationsCountProvider);
              ref.invalidate(unreadVideoSessionNotificationsProvider);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          callback: (_) {
            if (mounted) {
              ref.invalidate(unreadNotificationsCountProvider);
              ref.invalidate(unreadVideoSessionNotificationsProvider);
            }
          },
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(unreadMessagesCountProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      ref.invalidate(unreadVideoSessionNotificationsProvider);
    }
  }

  @override
  void didUpdateWidget(covariant HomeShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tab = widget.initialTabIndex;
    if (tab != oldWidget.initialTabIndex && tab >= 0 && tab < 5) {
      _goToTab(tab);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _badgeChannel?.unsubscribe();
    _welcomeController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _visitedTabIndexes.add(index);
    });
  }

  Widget _buildPage(int index, CurrentUser user) {
    final isTrainer = user.isTrainer;
    final isNutritionist = user.isNutritionist;

    switch (index) {
      case 0:
        if (isTrainer) {
          return TrainerHomePage(
            onNavigateToMessagesTab: () => _goToTab(2),
            onNavigateToMealsTab: () => _goToTab(3),
            onNavigateToClientsTab: () => _goToTab(1),
          );
        }
        if (isNutritionist) {
          return NutritionistHomePage(
            onNavigateToMessagesTab: () => _goToTab(2),
            onNavigateToMealsTab: () => _goToTab(3),
            onNavigateToClientsTab: () => _goToTab(1),
          );
        }
        return HomePageV3(
          onNavigateToMessagesTab: () => _goToTab(2),
          onNavigateToMealsTab: () => _goToTab(3),
        );
      case 1:
        return isTrainer
            ? const TrainerMyClientsPage()
            : isNutritionist
                ? const NutritionistMyClientsPage()
                : const DiscoverPage();
      case 2:
        return const MessagingPage();
      case 3:
        return const MealTrackerPageV2();
      case 4:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pageFor(int index, CurrentUser user) {
    return _pageCache[index] ??= _buildPage(index, user);
  }

  Widget _roleLoadingScaffold() {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _roleErrorScaffold({required VoidCallback onRetry}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Couldn’t load your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Check your connection and try again. We won’t guess your role.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: (isLight ? Colors.black87 : Colors.white)
                      .withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.accentOrange,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.asData?.value;
    final isLight = Theme.of(context).brightness == Brightness.light;

    ref.listen(currentUserProvider, (prev, next) {
      final prevRole = prev?.asData?.value?.role;
      final nextRole = next.asData?.value?.role;
      if (prevRole != nextRole && mounted) {
        setState(() {
          for (var i = 0; i < _pageCache.length; i++) {
            _pageCache[i] = null;
          }
        });
      }
    });

    // Neutral loading — never default to Client while role is unknown.
    if (user == null) {
      if (userAsync.isLoading) {
        return _roleLoadingScaffold();
      }
      return _roleErrorScaffold(
        onRetry: () {
          for (var i = 0; i < _pageCache.length; i++) {
            _pageCache[i] = null;
          }
          ref.invalidate(currentUserProvider);
        },
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              sizing: StackFit.expand,
              children: List.generate(
                _navigationItems.length,
                (index) {
                  if (!_visitedTabIndexes.contains(index)) {
                    return const SizedBox.shrink();
                  }
                  return _pageFor(index, user);
                },
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
            child: Container(
              decoration: BoxDecoration(
                color: isLight ? Colors.white : DesignTokens.darkNavSurface,
                borderRadius: BorderRadius.circular(_navBarRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
                child: Row(
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
    final selectedColor =
        isLight ? DesignTokens.lightTextPrimary : DesignTokens.darkTextPrimary;
    final unselectedColor = isLight
        ? DesignTokens.lightTextSecondary
        : colorScheme.onSurface.withValues(alpha: 0.5);

    final badge = index == 2 ? ref.watch(unreadMessagesCountProvider) : null;
    final showUnreadDot = badge != null && badge.maybeWhen(data: (c) => c > 0, orElse: () => false);

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          _goToTab(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? selectedColor : unselectedColor,
                size: 28,
              ),
              if (showUnreadDot)
                Positioned(
                  top: -2,
                  right: -6,
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
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: isActive ? 4 : 0,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? selectedColor : null,
              borderRadius: BorderRadius.circular(2),
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
