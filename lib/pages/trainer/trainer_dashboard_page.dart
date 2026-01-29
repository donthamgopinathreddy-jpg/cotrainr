import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import 'trainer_home_page.dart';
import 'trainer_my_clients_page.dart';
import 'trainer_quest_page.dart';
import 'trainer_cocircle_page.dart';
import 'trainer_profile_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: '/trainer/dashboard',
      gradient: LinearGradient(
        colors: [DesignTokens.accentOrange, DesignTokens.accentAmber],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.person_add_outlined,
      activeIcon: Icons.person_add,
      label: 'My Clients',
      route: '/trainer/clients',
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
      route: '/trainer/quest',
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
      route: '/trainer/cocircle',
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
      route: '/trainer/profile',
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: _navigationItems.length,
        itemBuilder: (context, index) {
          final pages = [
            const TrainerHomePage(),
            const TrainerMyClientsPage(),
            const TrainerQuestPage(),
            TrainerCocirclePage(),
            const TrainerProfilePage(),
          ];
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
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
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: isActive ? item.gradient : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive
                  ? Colors.white
                  : colorScheme.onSurface.withOpacity(0.6),
              size: 26,
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
