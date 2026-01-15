import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import 'home_page_v3.dart';
import '../discover/discover_page.dart';
import '../quest/quest_page.dart';
import '../cocircle/cocircle_page.dart';
import '../profile/profile_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _currentIndex = 0;

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
      gradient: LinearGradient(
        colors: [DesignTokens.accentGreen, DesignTokens.accentGreen.withValues(alpha: 204)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      label: 'Quest',
      route: '/home/quest',
      gradient: LinearGradient(
        colors: [DesignTokens.accentYellow, DesignTokens.accentYellow.withValues(alpha: 204)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Cocircle',
      route: '/home/cocircle',
      gradient: LinearGradient(
        colors: [DesignTokens.accentBlue, DesignTokens.accentBlueLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      route: '/home/profile',
      gradient: LinearGradient(
        colors: [DesignTokens.accentRed, DesignTokens.accentRed.withValues(alpha: 204)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomePageV3(),
          DiscoverPage(),
          QuestPage(),
          CocirclePage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: DesignTokens.darkBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
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
    final item = _navigationItems[index];
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
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
                  : Colors.white.withOpacity(0.6),
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
