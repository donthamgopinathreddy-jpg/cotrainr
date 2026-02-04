import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'home_page_v3.dart';
import '../discover/discover_page.dart';
import '../quest/quest_page.dart';
import '../cocircle/cocircle_page.dart';
import '../profile/profile_page.dart';

class HomeShellPage extends StatefulWidget {
  final bool showWelcome;
  
  const HomeShellPage({
    super.key,
    this.showWelcome = false,
  });

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final AnimationController _welcomeController;
  late final Animation<double> _welcomeFade;
  late final Animation<Offset> _welcomeSlide;
  bool _showWelcomeBubble = false;

  final List<NavigationItem> _navigationItems = [
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
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Discover',
      route: '/home/discover',
      gradient: const LinearGradient(
        colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      label: 'Quest',
      route: '/home/quest',
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD93D), Color(0xFFFF5A5A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Cocircle',
      route: '/home/cocircle',
      gradient: const LinearGradient(
        colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
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
      // Start animation after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _welcomeController.forward();
        }
      });
      // Auto-hide after 3 seconds
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe, only allow programmatic navigation
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: _navigationItems.length,
        itemBuilder: (context, index) {
          final pages = [
            HomePageV3(
              onNavigateToCocircle: () {
                _pageController.animateToPage(
                  3, // Cocircle feed is at index 3
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
                setState(() => _currentIndex = 3);
              },
            ),
            const DiscoverPage(),
            const QuestPage(),
            const CocirclePage(),
            const ProfilePage(),
          ];
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              // Sliding transition
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Container(
              key: ValueKey(index),
              child: pages[index],
            ),
          );
        },
      ),
          // Floating welcome bubble
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
    );
  }

  Widget _buildNavItem(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = _navigationItems[index];
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: isActive ? item.gradient : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: Icon(
            isActive ? item.activeIcon : item.icon,
            key: ValueKey('${item.label}_$isActive'),
            color: isActive
                ? Colors.white
                : colorScheme.onSurface.withValues(alpha: 0.6),
            size: 26,
          ),
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
