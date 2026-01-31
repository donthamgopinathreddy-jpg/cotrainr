import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../models/quest_models.dart';

class DailyQuestCard extends StatefulWidget {
  final DailyQuest quest;
  final VoidCallback? onTap;

  const DailyQuestCard({
    super.key,
    required this.quest,
    this.onTap,
  });

  @override
  State<DailyQuestCard> createState() => _DailyQuestCardState();
}

class _DailyQuestCardState extends State<DailyQuestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    if (widget.quest.iconColor != null) {
      return widget.quest.iconColor!;
    }
    switch (widget.quest.status) {
      case QuestStatus.completed:
        return DesignTokens.accentGreen;
      case QuestStatus.missed:
        return Colors.grey;
      case QuestStatus.inProgress:
        return DesignTokens.accentOrange;
    }
  }

  String _formatProgress() {
    if (widget.quest.maxProgress >= 100) {
      // Integer progress (like steps)
      return '${widget.quest.progress.toInt()} / ${widget.quest.maxProgress.toInt()}';
    } else {
      // Decimal progress (like liters)
      return '${widget.quest.progress.toStringAsFixed(2)}L / ${widget.quest.maxProgress.toStringAsFixed(0)}L';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.quest.progress / widget.quest.maxProgress;
    final isMissed = widget.quest.status == QuestStatus.missed;
    final statusColor = _getStatusColor();

    return Opacity(
      opacity: isMissed ? 0.5 : 1.0,
      child: GestureDetector(
        onTapDown: (_) {
          if (!isMissed) {
            _controller.forward();
          }
        },
        onTapUp: (_) {
          _controller.reverse();
          if (!isMissed) {
            HapticFeedback.lightImpact();
            widget.onTap?.call();
          }
        },
        onTapCancel: () {
          _controller.reverse();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceOf(context),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  boxShadow: DesignTokens.cardShadowOf(context),
                ),
                child: Row(
                  children: [
                    // Left: Quest Icon in Colored Circle
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.quest.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing16),

                    // Center: Title, Progress Text, Progress Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.quest.title,
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeBody,
                              fontWeight: FontWeight.w700,
                              color: DesignTokens.textPrimaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: DesignTokens.spacing6),
                          Text(
                            _formatProgress(),
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeBodySmall,
                              color: DesignTokens.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing8),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                            duration: DesignTokens.animationMedium,
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: value,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),

                    // Right: XP Reward
                    Text(
                      '+${widget.quest.rewardXP} XP',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBodySmall,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
