import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class DiscoverTabIndicator extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int>? onTabChanged;

  const DiscoverTabIndicator({
    super.key,
    required this.controller,
    this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTabChanged,
        indicator: BoxDecoration(
          gradient: DesignTokens.primaryGradient,
          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: DesignTokens.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: DesignTokens.fontSizeBody,
        ),
        tabs: const [
          Tab(text: 'Trainers'),
          Tab(text: 'Nutritionists'),
          Tab(text: 'Centers'),
        ],
      ),
    );
  }
}

