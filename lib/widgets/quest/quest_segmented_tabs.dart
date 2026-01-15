import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class QuestSegmentedTabs extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const QuestSegmentedTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  State<QuestSegmentedTabs> createState() => _QuestSegmentedTabsState();
}

class _QuestSegmentedTabsState extends State<QuestSegmentedTabs>
    with SingleTickerProviderStateMixin {
  late AnimationController _indicatorController;
  late Animation<double> _indicatorAnimation;

  final List<String> _tabs = ['Daily', 'Challenges', 'Leaderboard', 'Achiever'];

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      duration: DesignTokens.animationMedium,
      vsync: this,
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOutCubic,
    );
    _indicatorController.value = widget.selectedIndex / (_tabs.length - 1);
  }

  @override
  void didUpdateWidget(QuestSegmentedTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _indicatorController.animateTo(widget.selectedIndex / (_tabs.length - 1));
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing16,
        vertical: DesignTokens.spacing10,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceOf(context),
          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
          boxShadow: DesignTokens.cardShadowOf(context),
        ),
        child: Stack(
          children: [
            // Animated Indicator
            AnimatedBuilder(
              animation: _indicatorAnimation,
              builder: (context, child) {
                final tabWidth = (MediaQuery.of(context).size.width - 32) / _tabs.length;
                return Positioned(
                  left: _indicatorAnimation.value * tabWidth + 3,
                  top: 3,
                  bottom: 3,
                  width: tabWidth - 6,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DesignTokens.accentOrange,
                          DesignTokens.accentOrange.withValues(alpha: 230),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                      boxShadow: [
                        BoxShadow(
                          color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Tabs
            Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = widget.selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTabChanged(index);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeBodySmall,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : DesignTokens.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
