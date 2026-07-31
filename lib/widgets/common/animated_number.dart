import 'package:flutter/material.dart';

/// Smoothly animates a numeric value into formatted text.
/// Keeps existing typography — pass [style] from the call site.
class AnimatedNumber extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final String Function(double value) format;
  final Duration duration;
  final Curve curve;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> {
  late double _begin;
  late double _end;

  @override
  void initState() {
    super.initState();
    _begin = widget.value;
    _end = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _begin = oldWidget.value;
      _end = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_end),
      tween: Tween<double>(begin: _begin, end: _end),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, animated, _) {
        return Text(
          widget.format(animated),
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          textAlign: widget.textAlign,
        );
      },
    );
  }
}
