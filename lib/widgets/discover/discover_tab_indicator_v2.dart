import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class DiscoverTabIndicatorV2 extends StatelessWidget {
  final TabController controller;
  final int selectedIndex;
  final ValueChanged<int>? onTabChanged;

  const DiscoverTabIndicatorV2({
    super.key,
    required this.controller,
    required this.selectedIndex,
    this.onTabChanged,
  });

  LinearGradient _getActiveGradient(int index) {
    switch (index) {
      case 0: // Trainers
        return DesignTokens.primaryGradient; // Orange
      case 1: // Nutritionists
        return LinearGradient(
          colors: [DesignTokens.accentGreen, DesignTokens.accentGreen],
        );
      case 2: // Centers
        return DesignTokens.secondaryGradient; // Blue-Purple
      default:
        return DesignTokens.primaryGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTabChanged,
        indicator: BoxDecoration(
          gradient: _getActiveGradient(selectedIndex),
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          boxShadow: [
            BoxShadow(
              color: (selectedIndex == 0
                      ? DesignTokens.accentOrange
                      : selectedIndex == 1
                          ? DesignTokens.accentGreen
                          : DesignTokens.accentBlue)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: DesignTokens.textSecondaryOf(context),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: DesignTokens.fontSizeBodySmall,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: DesignTokens.fontSizeBodySmall,
          color: DesignTokens.textSecondaryOf(context),
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.fitness_center_rounded, size: 18),
            text: 'Trainers',
          ),
          Tab(
            icon: Icon(Icons.restaurant_menu_rounded, size: 18),
            text: 'Nutritionists',
          ),
          Tab(
            icon: Icon(Icons.location_city_rounded, size: 18),
            text: 'Centers',
          ),
        ],
      ),
    );
  }
}
