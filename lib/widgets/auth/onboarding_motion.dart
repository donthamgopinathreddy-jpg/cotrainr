import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap → 0.97 → 1.02 → 1.0. Decorative only; reduced-motion skips springs.
class SelectionSpring extends StatefulWidget {
  const SelectionSpring({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.semanticLabel,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<SelectionSpring> createState() => _SelectionSpringState();
}

class _SelectionSpringState extends State<SelectionSpring>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.02), weight: 36),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 36),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    HapticFeedback.selectionClick();
    if (!reduce) {
      _ctrl.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: _handleTap,
        child: reduce
            ? widget.child
            : AnimatedBuilder(
                animation: _scale,
                builder: (context, child) {
                  return Transform.scale(scale: _scale.value, child: child);
                },
                child: widget.child,
              ),
      ),
    );
  }
}