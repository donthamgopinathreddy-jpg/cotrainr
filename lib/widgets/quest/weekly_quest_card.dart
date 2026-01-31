import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../models/quest_models.dart';

class WeeklyQuestCard extends StatefulWidget {
  final WeeklyQuest quest;
  final VoidCallback? onTap;

  const WeeklyQuestCard({
    super.key,
    required this.quest,
    this.onTap,
  });

  @override
  State<WeeklyQuestCard> createState() => _WeeklyQuestCardState();
}

class _WeeklyQuestCardState extends State<WeeklyQuestCard>
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

  @override
  Widget build(BuildContext context) {
    final progress = widget.quest.progress / widget.quest.maxProgress;
    final isCompleted = progress >= 1.0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              decoration: BoxDecoration(
                gradient: isCompleted
                    ? DesignTokens.successGradient
                    : DesignTokens.secondaryGradient,
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                boxShadow: DesignTokens.cardShadowOf(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.quest.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing12),

                  // Title
                  Text(
                    widget.quest.title,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DesignTokens.spacing6),

                  // Description
                  Text(
                    widget.quest.description,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeMeta,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),

                  // Progress Bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                    duration: DesignTokens.animationMedium,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: value,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: DesignTokens.spacing10),

                  // Reward XP + Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.quest.rewardXP} XP',
                            style: const TextStyle(
                              fontSize: DesignTokens.fontSizeMeta,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
