import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';
import '../common/gradient_icon_blob.dart';

class StreakCardV2 extends StatefulWidget {
  final int streakDays;

  const StreakCardV2({
    super.key,
    required this.streakDays,
  });

  @override
  State<StreakCardV2> createState() => _StreakCardV2State();
}

class _StreakCardV2State extends State<StreakCardV2>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/home/quest');
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        // TODO: Open streak history
      },
      child: GlassCard(
        margin: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
        padding: EdgeInsets.all(DesignTokens.spacing16),
        onTap: null,
        child: Row(
          children: [
            // Left: Fire icon duotone + animated pulse
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: GradientIconBlob(
                    icon: Icons.local_fire_department,
                    gradient: DesignTokens.primaryGradient,
                    size: 40,
                    iconSize: 24,
                  ),
                );
              },
            ),
            SizedBox(width: DesignTokens.spacing16),
            // Center: Daily Streak (meta) + 7 Days (H2 bold) + Keep it up (meta)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Daily Streak',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeMeta,
                      color: DesignTokens.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.streakDays} Days',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeH2,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep it up!',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeMeta,
                      color: DesignTokens.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Right: Mini bars spark (7 bars) animated rise
            SizedBox(
              width: 40,
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  7,
                  (index) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    builder: (context, value, child) {
                      final height = index < widget.streakDays
                          ? 16.0 * value
                          : 8.0;
                      return Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          gradient: index < widget.streakDays
                              ? DesignTokens.primaryGradient
                              : null,
                          color: index < widget.streakDays
                              ? null
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



