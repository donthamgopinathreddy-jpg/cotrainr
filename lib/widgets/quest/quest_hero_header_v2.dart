import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../common/stat_ring.dart';

class QuestHeroHeaderV2 extends StatelessWidget {
  final int currentXP;
  final int xpToNextLevel;
  final int currentLevel;

  const QuestHeroHeaderV2({
    super.key,
    required this.currentXP,
    required this.xpToNextLevel,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentXP / xpToNextLevel;
    final xpRemaining = xpToNextLevel - currentXP;

    return Container(
      margin: const EdgeInsets.all(DesignTokens.spacing16),
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      decoration: BoxDecoration(
        gradient: DesignTokens.primaryGradient,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.accentOrange.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Level Badge with Trophy Icon
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing16,
              vertical: DesignTokens.spacing8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                Text(
                  'Level $currentLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: DesignTokens.fontSizeBody,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing24),

          // XP Ring with Enhanced Design
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow Ring
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // XP Progress Ring
              StatRing(
                progress: progress,
                size: 130,
                strokeWidth: 14,
                color: Colors.white,
                centerChild: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$currentXP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing16),

          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),

          // Progress Text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                '${xpRemaining} XP to Level ${currentLevel + 1}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

