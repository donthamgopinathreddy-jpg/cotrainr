import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';
import '../common/mini_sparkline.dart';

class CaloriesWaterRowV2 extends StatelessWidget {
  final int currentCalories;
  final List<double> caloriesWeeklyData;
  final double currentWater;
  final double goalWater;
  final List<double> waterWeeklyData;

  const CaloriesWaterRowV2({
    super.key,
    required this.currentCalories,
    required this.caloriesWeeklyData,
    required this.currentWater,
    required this.goalWater,
    required this.waterWeeklyData,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
      child: Row(
        children: [
          // Calories Card
          Expanded(
            child: _CaloriesCard(
              currentCalories: currentCalories,
              weeklyData: caloriesWeeklyData,
            ),
          ),
          SizedBox(width: DesignTokens.spacing8),
          // Water Card
          Expanded(
            child: _WaterCard(
              currentWater: currentWater,
              goalWater: goalWater,
              weeklyData: waterWeeklyData,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  final int currentCalories;
  final List<double> weeklyData;

  const _CaloriesCard({
    required this.currentCalories,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          // TODO: Navigate to calories insights
        },
        child: GlassCard(
          padding: EdgeInsets.all(DesignTokens.spacing16),
          onTap: null,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.withValues(alpha: 0.15),
                  Colors.pink.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      size: DesignTokens.iconSizeTile,
                      color: DesignTokens.textSecondaryOf(context),
                    ),
                    SizedBox(width: DesignTokens.spacing8),
                    Text(
                      'Calories',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeMeta,
                        color: DesignTokens.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DesignTokens.spacing8),
                Text(
                  '${currentCalories}kcal',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeH2,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: DesignTokens.spacing8),
                Expanded(
                  child: MiniSparkline(
                    data: weeklyData,
                    color: Colors.red,
                    height: 20,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing4),
                Text(
                  'Goal left',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeMeta,
                    color: DesignTokens.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  final double currentWater;
  final double goalWater;
  final List<double> weeklyData;

  const _WaterCard({
    required this.currentWater,
    required this.goalWater,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          // TODO: Navigate to water insights
        },
        child: GlassCard(
          padding: EdgeInsets.all(DesignTokens.spacing16),
          onTap: null,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DesignTokens.accentBlue.withValues(alpha: 0.15),
                  Colors.cyan.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.water_drop_rounded,
                      size: DesignTokens.iconSizeTile,
                      color: DesignTokens.textSecondaryOf(context),
                    ),
                    SizedBox(width: DesignTokens.spacing8),
                    Text(
                      'Water',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeMeta,
                        color: DesignTokens.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DesignTokens.spacing8),
                Text(
                  '${currentWater.toStringAsFixed(1)}L / ${goalWater.toStringAsFixed(1)}L',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeH2,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: DesignTokens.spacing8),
                Expanded(
                  child: MiniSparkline(
                    data: weeklyData,
                    color: DesignTokens.accentBlue,
                    height: 20,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing4),
                // Add button: +250ml pill inside card - clickable
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // TODO: Add 250ml water to daily metrics
                    // This should trigger a callback or state update
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: DesignTokens.primaryGradient,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                    ),
                    child: Text(
                      '+250ml',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeMeta,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

