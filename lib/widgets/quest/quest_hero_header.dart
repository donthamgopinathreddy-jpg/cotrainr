import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../common/stat_ring.dart';

class QuestHeroHeader extends StatelessWidget {
  final int currentXP;
  final int xpToNextLevel;
  final int currentLevel;

  const QuestHeroHeader({
    super.key,
    required this.currentXP,
    required this.xpToNextLevel,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentXP / xpToNextLevel;

    return Container(
      margin: const EdgeInsets.all(DesignTokens.spacing16),
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      decoration: BoxDecoration(
        gradient: DesignTokens.primaryGradient,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        boxShadow: DesignTokens.cardShadow,
      ),
      child: Column(
        children: [
          // Level Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing16,
              vertical: DesignTokens.spacing8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
            ),
            child: Text(
              'Level $currentLevel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.fontSizeBody,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing24),

          // XP Ring
          StatRing(
            progress: progress,
            size: 120,
            strokeWidth: 12,
            centerChild: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$currentXP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: DesignTokens.fontSizeH1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'XP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: DesignTokens.fontSizeBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),

          // Progress Text
          Text(
            '${(progress * 100).toStringAsFixed(0)}% to Level ${currentLevel + 1}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
        ],
      ),
    );
  }
}

