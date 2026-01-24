import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

/// Wraps [child] with:
/// - Material + InkResponse for ripple/splash on tap
/// - AnimatedScale on press (visual feedback)
/// - HapticFeedback on tap
///
/// Use for cards, tiles, and list items. When [onTap] is null, [child] is
/// returned as-is (no tap handling).
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double pressScale;
  final bool enableHaptic;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.pressScale = DesignTokens.interactionPressScale,
    this.enableHaptic = true,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          if (widget.enableHaptic) HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        borderRadius: BorderRadius.circular(widget.borderRadius),
        containedInkWell: true,
        child: AnimatedScale(
          scale: _pressed ? widget.pressScale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
