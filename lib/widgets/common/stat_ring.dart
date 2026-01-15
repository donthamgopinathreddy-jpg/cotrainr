import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class StatRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color color;
  final Widget? centerChild;

  const StatRing({
    super.key,
    required this.progress,
    this.size = 80.0,
    this.strokeWidth = 10.0,
    this.color = DesignTokens.accentOrange,
    this.centerChild,
  });

  @override
  State<StatRing> createState() => _StatRingState();
}

class _StatRingState extends State<StatRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CircularProgressIndicator(
            value: widget.progress * _animation.value,
            strokeWidth: widget.strokeWidth,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            strokeCap: StrokeCap.round,
          );
        },
        child: widget.centerChild != null
            ? Center(child: widget.centerChild)
            : null,
      ),
    );
  }
}



