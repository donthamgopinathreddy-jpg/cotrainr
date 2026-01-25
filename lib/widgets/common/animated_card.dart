import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/motion/motion.dart';
import '../../theme/design_tokens.dart';

/// Animated card with press feedback, haptics, and smooth animations
/// Replaces InkWell with better press animations
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final bool enableHaptic;
  final HapticFeedbackType hapticType;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = DesignTokens.radiusCard,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.boxShadow,
    this.enableHaptic = true,
    this.hapticType = HapticFeedbackType.lightImpact,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  selectionClick,
  heavyImpact,
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _pressed = false;

  void _triggerHaptic() {
    if (!widget.enableHaptic) return;

    switch (widget.hapticType) {
      case HapticFeedbackType.lightImpact:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.mediumImpact:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.selectionClick:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.heavyImpact:
        HapticFeedback.heavyImpact();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: widget.boxShadow ?? DesignTokens.subtleShadowOf(context),
      ),
      child: widget.child,
    );

    if (widget.onTap == null && widget.onLongPress == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _triggerHaptic();
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        onLongPress: widget.onLongPress != null
            ? () {
                _triggerHaptic();
                widget.onLongPress?.call();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? Motion.pressScale : 1.0,
          duration: Motion.pressDuration,
          curve: Motion.pressCurve,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: Motion.pressDuration,
            curve: Motion.pressCurve,
            child: card,
          ),
        ),
      ),
    );
  }
}
