import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';
import '../common/mini_sparkline.dart';
import '../common/stat_ring.dart';

class StepsCardV2 extends StatelessWidget {
  final int currentSteps;
  final int goalSteps;
  final List<double> weeklyData;

  const StepsCardV2({
    super.key,
    required this.currentSteps,
    required this.goalSteps,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentSteps / goalSteps;
    final formattedSteps = _formatNumber(currentSteps);
    final formattedGoal = _formatNumber(goalSteps);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
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
          context.push('/home/weekly-insights?tab=steps');
        },
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: GlassCard(
            margin: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
            padding: EdgeInsets.all(DesignTokens.spacing16),
            onTap: null,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DesignTokens.accentOrange.withValues(alpha: 0.1),
                    DesignTokens.accentAmber.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Stack(
                children: [
                  // Top row: Steps label + chevron
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_walk_rounded,
                              size: DesignTokens.iconSizeTile,
                              color: DesignTokens.textSecondaryOf(context),
                            ),
                            SizedBox(width: DesignTokens.spacing8),
                            Text(
                              'Steps',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeBody,
                                color: DesignTokens.textSecondaryOf(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: DesignTokens.iconSizeTile,
                          color: DesignTokens.textSecondaryOf(context),
                        ),
                      ],
                    ),
                  ),
                  // Main: 8.2k/10k (H1 semi)
                  Positioned(
                    top: 32,
                    left: 0,
                    child: Text(
                      '$formattedSteps / $formattedGoal',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeH1,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  // Right: Ring progress (animate) with % center
                  Positioned(
                    top: 0,
                    right: 0,
                    child: StatRing(
                      progress: progress,
                      size: 80,
                      strokeWidth: 10,
                      color: DesignTokens.accentOrange,
                      centerChild: Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeMeta,
                          fontWeight: FontWeight.w600,
                          color: DesignTokens.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ),
                  // Bottom: Sparkline daily trend (7 points) glow stroke
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: MiniSparkline(
                      data: weeklyData,
                      color: DesignTokens.accentOrange,
                      height: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}



