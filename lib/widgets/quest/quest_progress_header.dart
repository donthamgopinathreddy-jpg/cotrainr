import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../common/stat_ring.dart';

class QuestProgressHeader extends StatefulWidget {
  final int currentXP;
  final int xpToNextLevel;
  final int currentLevel;
  final String levelTitle;
  final String? consistencyBadge;

  const QuestProgressHeader({
    super.key,
    required this.currentXP,
    required this.xpToNextLevel,
    required this.currentLevel,
    required this.levelTitle,
    this.consistencyBadge,
  });

  @override
  State<QuestProgressHeader> createState() => _QuestProgressHeaderState();
}

class _QuestProgressHeaderState extends State<QuestProgressHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalXP = widget.currentXP + widget.xpToNextLevel;
    final progress = widget.currentXP / totalXP;

    return Container(
      margin: const EdgeInsets.only(
        left: DesignTokens.spacing16,
        right: DesignTokens.spacing16,
        top: DesignTokens.spacing16,
        bottom: DesignTokens.spacing12,
      ),
      padding: const EdgeInsets.all(DesignTokens.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.accentOrange,
            DesignTokens.accentOrange.withValues(alpha: 230),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: Row(
        children: [
          // Left: Circular Progress Ring with Level
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
            duration: DesignTokens.animationMedium,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return StatRing(
                progress: value,
                size: 80,
                strokeWidth: 8,
                color: Colors.white,
                centerChild: Text(
                  '${widget.currentLevel}',
                  style: const TextStyle(
                    fontSize: DesignTokens.fontSizeH3,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: DesignTokens.spacing16),

          // Center: XP Count and Next Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.currentXP} XP',
                  style: const TextStyle(
                    fontSize: DesignTokens.fontSizeH2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing4),
                Text(
                  '${widget.xpToNextLevel} XP to next level',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodySmall,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 230),
                  ),
                ),
              ],
            ),
          ),

          // Right: Consistency Badge
          if (widget.consistencyBadge != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing12,
                vertical: DesignTokens.spacing6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                widget.consistencyBadge!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: DesignTokens.fontSizeCaption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
