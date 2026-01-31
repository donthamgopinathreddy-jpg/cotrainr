import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../models/quest_models.dart';

class ChallengeCard extends StatefulWidget {
  final ChallengeQuest challenge;
  final VoidCallback? onJoin;
  final VoidCallback? onTap;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onJoin,
    this.onTap,
  });

  @override
  State<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<ChallengeCard>
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.challenge.progress / widget.challenge.maxProgress;

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
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [DesignTokens.accentPurple, DesignTokens.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                boxShadow: DesignTokens.cardShadowOf(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.challenge.title,
                              style: const TextStyle(
                                fontSize: DesignTokens.fontSizeBody,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: DesignTokens.spacing4),
                            Text(
                              widget.challenge.description,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeMeta,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Join/Joined Button
                      GestureDetector(
                        onTap: () {
                          if (!widget.challenge.isJoined) {
                            HapticFeedback.mediumImpact();
                            widget.onJoin?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spacing14,
                            vertical: DesignTokens.spacing6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.challenge.isJoined
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusChip,
                            ),
                          ),
                          child: Text(
                            widget.challenge.isJoined ? 'Joined' : 'Join',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeMeta,
                              fontWeight: FontWeight.w700,
                              color: widget.challenge.isJoined
                                  ? Colors.white
                                  : DesignTokens.accentPurple,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spacing12),

                  // Participants & Time
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.challenge.participants} participants',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing12),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.challenge.timeRemaining,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),

                  // Progress (if joined)
                  if (widget.challenge.isJoined) ...[
                    const SizedBox(height: DesignTokens.spacing12),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                      duration: DesignTokens.animationMedium,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusChip,
                            ),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: value,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusChip,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: DesignTokens.spacing6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}% complete',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeCaption,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.challenge.rewardXP} XP',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeCaption,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
