import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class QuestCardV2 extends StatefulWidget {
  final dynamic quest; // QuestItem
  final VoidCallback? onClaim;

  const QuestCardV2({
    super.key,
    required this.quest,
    this.onClaim,
  });

  @override
  State<QuestCardV2> createState() => _QuestCardV2State();
}

class _QuestCardV2State extends State<QuestCardV2>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.quest.isCompleted && !widget.quest.isLocked) {
      _pulseController.repeat(reverse: true);
    }
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  LinearGradient _getCategoryGradient() {
    switch (widget.quest.category) {
      case 'Daily':
        return DesignTokens.primaryGradient;
      case 'Weekly':
        return DesignTokens.secondaryGradient;
      case 'Community':
        return LinearGradient(
          colors: [DesignTokens.accentPurple, DesignTokens.accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return DesignTokens.primaryGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.quest.progress / widget.quest.maxProgress;
    final isCompleted = widget.quest.isCompleted;
    final isLocked = widget.quest.isLocked;
    final progressPercent = (progress * 100).clamp(0.0, 100.0);

    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: GestureDetector(
        onTapDown: (_) {
          if (!isLocked) {
            setState(() => _isPressed = true);
            _controller.forward();
          }
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _controller.reverse();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _controller.reverse();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _pulseController]),
          builder: (context, child) {
            final pulseScale = widget.quest.isCompleted && !widget.quest.isLocked
                ? 1.0 + (_pulseController.value * 0.02)
                : 1.0;
            return Transform.scale(
              scale: _scaleAnimation.value * pulseScale,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: DesignTokens.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(
                    color: _isPressed
                        ? DesignTokens.accentOrange.withValues(alpha: 0.5)
                        : isCompleted
                            ? DesignTokens.accentGreen.withValues(alpha: 0.3)
                            : DesignTokens.borderColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.2 + (_elevationAnimation.value * 0.05),
                      ),
                      blurRadius: 25 + (_elevationAnimation.value * 3),
                      offset: Offset(0, 12 + _elevationAnimation.value),
                    ),
                    if (isCompleted)
                      BoxShadow(
                        color: DesignTokens.accentGreen.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        // Category Icon with Gradient
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: _getCategoryGradient(),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: DesignTokens.accentOrange
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.quest.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spacing16),

                        // Title & Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.quest.title,
                                      style: TextStyle(
                                        fontSize: DesignTokens.fontSizeH2,
                                        fontWeight: FontWeight.w800,
                                        color: DesignTokens.textPrimary,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            DesignTokens.accentGreen,
                                            DesignTokens.accentGreen
                                                .withValues(alpha: 0.7),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: DesignTokens.accentGreen
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: DesignTokens.spacing4),
                              Text(
                                widget.quest.description,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeBody,
                                  fontWeight: FontWeight.w500,
                                  color: DesignTokens.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: DesignTokens.spacing16),

                    // Progress Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress Bar with Gradient
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: DesignTokens.surface,
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusChip,
                            ),
                            border: Border.all(
                              color: DesignTokens.borderColor,
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Background
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusChip,
                                  ),
                                ),
                              ),
                              // Progress Fill
                              FractionallySizedBox(
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: isCompleted
                                        ? LinearGradient(
                                            colors: [
                                              DesignTokens.accentGreen,
                                              DesignTokens.accentGreen
                                                  .withValues(alpha: 0.8),
                                            ],
                                          )
                                        : _getCategoryGradient(),
                                    borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusChip,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isCompleted
                                                ? DesignTokens.accentGreen
                                                : DesignTokens.accentOrange)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spacing8),

                        // Progress Text & Rewards
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Progress Percentage
                            Row(
                              children: [
                                Icon(
                                  Icons.track_changes_rounded,
                                  size: 14,
                                  color: DesignTokens.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${progressPercent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeMeta,
                                    fontWeight: FontWeight.w700,
                                    color: DesignTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: DesignTokens.spacing8),
                                Text(
                                  '${widget.quest.progress.toStringAsFixed(0)} / ${widget.quest.maxProgress.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeMeta,
                                    color: DesignTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            // Rewards
                            Row(
                              children: [
                                // XP Reward Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DesignTokens.spacing12,
                                    vertical: DesignTokens.spacing8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        DesignTokens.accentPurple,
                                        DesignTokens.accentPurple
                                            .withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusChip,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DesignTokens.accentPurple
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${widget.quest.rewardXP}',
                                        style: const TextStyle(
                                          fontSize: DesignTokens.fontSizeMeta,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: DesignTokens.spacing8),
                                // Coins Reward Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DesignTokens.spacing12,
                                    vertical: DesignTokens.spacing8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        DesignTokens.accentAmber,
                                        DesignTokens.accentAmber
                                            .withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusChip,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DesignTokens.accentAmber
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${widget.quest.rewardCoins}',
                                        style: const TextStyle(
                                          fontSize: DesignTokens.fontSizeMeta,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                              scale: 1.0 + (_pulseController.value * 0.03),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      DesignTokens.accentGreen,
                                      DesignTokens.accentGreen
                                          .withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusButton,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DesignTokens.accentGreen
                                          .withValues(alpha: 0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      widget.onClaim?.call();
                                    },
                                    borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusButton,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: DesignTokens.spacing16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.celebration_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: DesignTokens.spacing8,
                                          ),
                                          const Text(
                                            'Claim Reward',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: DesignTokens.fontSizeBody,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
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
          },
        ),
      ),
    );
  }
}

