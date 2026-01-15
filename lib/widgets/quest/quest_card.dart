import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../common/gradient_icon_blob.dart';

class QuestCard extends StatefulWidget {
  final dynamic quest; // QuestItem
  final VoidCallback? onClaim;

  const QuestCard({
    super.key,
    required this.quest,
    this.onClaim,
  });

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.quest.progress / widget.quest.maxProgress;
    final isCompleted = widget.quest.isCompleted;
    final isLocked = widget.quest.isLocked;

    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          boxShadow: DesignTokens.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                GradientIconBlob(
                  icon: widget.quest.icon,
                  gradient: DesignTokens.primaryGradient,
                  size: 48,
                ),
                const SizedBox(width: DesignTokens.spacing16),

                // Title & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.quest.title,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeH2,
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spacing4),
                      Text(
                        widget.quest.description,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeBody,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacing16),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: DesignTokens.surface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? DesignTokens.accentGreen : DesignTokens.accentOrange,
                ),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: DesignTokens.spacing8),

            // Progress Text & Rewards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.quest.progress.toStringAsFixed(0)} / ${widget.quest.maxProgress.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeMeta,
                    color: DesignTokens.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    // XP Reward
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing8,
                        vertical: DesignTokens.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.accentPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: DesignTokens.accentPurple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.quest.rewardXP} XP',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeMeta,
                              color: DesignTokens.accentPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    // Coins Reward
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing8,
                        vertical: DesignTokens.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.accentAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 14,
                            color: DesignTokens.accentAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.quest.rewardCoins}',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeMeta,
                              color: DesignTokens.accentAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Claim Button
            if (isCompleted && !isLocked)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.spacing16),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.05),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            widget.onClaim?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.accentGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: DesignTokens.spacing12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                            ),
                          ),
                          child: const Text(
                            'Claim Reward',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

