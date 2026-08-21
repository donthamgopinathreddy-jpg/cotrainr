import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Samsung Health–style progress ring with layered overlap above 100%.
class MetricProgressRing extends StatefulWidget {
  final double progressPercent;
  final Color color;
  final LinearGradient? gradient;
  final IconData icon;
  final double size;
  final double strokeWidth;
  final Color trackColor;

  const MetricProgressRing({
    super.key,
    required this.progressPercent,
    required this.color,
    this.gradient,
    required this.icon,
    required this.size,
    this.strokeWidth = 9,
    required this.trackColor,
  });

  @override
  State<MetricProgressRing> createState() => _MetricProgressRingState();
}

class _MetricProgressRingState extends State<MetricProgressRing>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 400);
  static const _overlapCap = 0.25;
  static const _minJunctionCover = 0.045;
  static const _basePhasePortion = 0.58;

  late AnimationController _controller;
  late Animation<double> _curve;

  double _fromPercent = 0;
  double _toPercent = 0;

  /// ~22% thinner than the value passed by the parent, clamped to 8–10 px.
  double get _effectiveStroke =>
      (widget.strokeWidth * 0.78).clamp(8.0, 10.0);

  static double _sanitize(double value) {
    if (!value.isFinite) return 0;
    return value.clamp(0, 400);
  }

  @override
  void initState() {
    super.initState();
    _toPercent = _sanitize(widget.progressPercent);
    _fromPercent = _toPercent;
    _controller = AnimationController(vsync: this, duration: _duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant MetricProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _sanitize(widget.progressPercent);
    if (_sanitize(oldWidget.progressPercent) != next) {
      _fromPercent =
          _fromPercent + (_toPercent - _fromPercent) * _controller.value;
      _toPercent = next;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _overlapRatioFor(double percent) {
    if (percent < 100) return 0;
    final beyond = (percent - 100) / 100;
    return math.min(_overlapCap, _minJunctionCover + beyond);
  }

  ({double basePercent, double overlapRatio}) _frameAt(double t) {
    final from = _fromPercent;
    final to = _toPercent;

    if (to < 100) {
      final current = from + (to - from) * t;
      return (basePercent: current.clamp(0.0, 100.0), overlapRatio: 0.0);
    }

    if (t <= _basePhasePortion) {
      final phaseT = t / _basePhasePortion;
      final fromBase = from.clamp(0.0, 100.0);
      final base = fromBase + (100.0 - fromBase) * phaseT;
      return (basePercent: base, overlapRatio: 0.0);
    }

    final phaseT = (t - _basePhasePortion) / (1.0 - _basePhasePortion);
    final targetOverlap = _overlapRatioFor(to);
    final fromOverlap = _overlapRatioFor(from);
    final overlap = fromOverlap + (targetOverlap - fromOverlap) * phaseT;
    return (basePercent: 100.0, overlapRatio: overlap);
  }

  @override
  Widget build(BuildContext context) {
    const iconSize = 40.0;
    final stroke = _effectiveStroke;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final frame = _frameAt(_curve.value);
        final t = _curve.value;
        final iconScale = 0.88 + (0.12 * t);
        final iconOpacity = t.clamp(0.0, 1.0);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _MetricProgressRingPainter(
                  basePercent: frame.basePercent,
                  overlapRatio: frame.overlapRatio,
                  color: widget.color,
                  gradient: widget.gradient,
                  trackColor: widget.trackColor,
                  strokeWidth: stroke,
                ),
              ),
              Opacity(
                opacity: iconOpacity,
                child: Transform.scale(
                  scale: iconScale,
                  child: Icon(
                    widget.icon,
                    size: iconSize,
                    color: widget.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricProgressRingPainter extends CustomPainter {
  final double basePercent;
  final double overlapRatio;
  final Color color;
  final LinearGradient? gradient;
  final Color trackColor;
  final double strokeWidth;

  static const _startAngle = -math.pi / 2;

  _MetricProgressRingPainter({
    required this.basePercent,
    required this.overlapRatio,
    required this.color,
    required this.gradient,
    required this.trackColor,
    required this.strokeWidth,
  });

  double _radius(Rect rect) => rect.width / 2;

  /// Single shared arc rect — base and overlap use the identical path.
  Rect _arcRect(Size size) {
    final inset = strokeWidth / 2;
    return Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
  }

  Paint _ringPaint(
    Rect rect, {
    Color? tint,
    StrokeCap cap = StrokeCap.round,
  }) {
    return Paint()
      ..shader = gradient?.createShader(rect)
      ..color = tint ?? color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = cap;
  }

  Offset _pointOnCircle(Rect rect, double angle) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final r = _radius(rect);
    return Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
  }

  Path _arcPath(Rect rect, double start, double sweep) {
    final path = Path();
    path.addArc(rect, start, sweep);
    return path;
  }

  /// Flat shadow placed directly beneath the overlap tip on the ring path.
  void _drawEndpointShadow(Canvas canvas, Rect rect, double tipAngle) {
    final tip = _pointOnCircle(rect, tipAngle);
    final cx = rect.center.dx;
    final cy = rect.center.dy;

    // Inward normal — shadow sits on the ring directly under the tip cap.
    final nx = cx - tip.dx;
    final ny = cy - tip.dy;
    final nLen = math.sqrt(nx * nx + ny * ny);
    if (nLen <= 0) return;

    final inx = nx / nLen;
    final iny = ny / nLen;
    final shadowCenter = Offset(
      tip.dx + inx * (strokeWidth * 0.18),
      tip.dy + iny * (strokeWidth * 0.18),
    );

    canvas.save();
    canvas.translate(shadowCenter.dx, shadowCenter.dy);
    canvas.rotate(tipAngle + math.pi / 2);

    // Elongated ellipse — less round, aligned with the arc tangent.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: strokeWidth * 1.05,
        height: strokeWidth * 0.32,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.36)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.4),
    );
    canvas.restore();
  }

  /// Overlap sits on top of the closed base ring, covering the 12 o'clock junction.
  void _drawOverlapArc(Canvas canvas, Rect rect, double sweep) {
    if (sweep <= 0.001) return;

    final tipAngle = _startAngle + sweep;
    final brighter = Color.lerp(color, Colors.white, 0.12)!;
    final overlapPaint = _ringPaint(rect, tint: brighter, cap: StrokeCap.round);

    // Darken the base segment beneath the overlap ribbon.
    final underPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.16)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, _startAngle, sweep, false, underPaint);

    // Soft shadow along the overlap body.
    canvas.drawShadow(
      _arcPath(rect, _startAngle, sweep),
      Colors.black.withValues(alpha: 0.16),
      1.2,
      false,
    );

    // Endpoint shadow — directly under the tip, not offset diagonally.
    _drawEndpointShadow(canvas, rect, tipAngle);

    // Overlap ribbon on top — round start covers the base ring junction at 12 o'clock.
    canvas.drawArc(rect, _startAngle, sweep, false, overlapPaint);
  }

  void _drawSeamlessBaseRing(Canvas canvas, Rect rect) {
    const fullSweep = math.pi * 2;
    canvas.drawArc(
      rect,
      _startAngle,
      fullSweep,
      false,
      _ringPaint(rect, cap: StrokeCap.butt),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _arcRect(size);
    const fullSweep = math.pi * 2;

    // 1 — Background track (seamless loop).
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, _startAngle, fullSweep, false, track);

    if (basePercent <= 0 && overlapRatio <= 0) return;

    // 2 — Base progress ring.
    if (basePercent < 100) {
      // Partial arc: round caps at 12 o'clock start and progress tip.
      canvas.drawArc(
        rect,
        _startAngle,
        fullSweep * (basePercent / 100),
        false,
        _ringPaint(rect),
      );
    } else {
      // Completed ring: seamless closed circle, no visible start/end.
      _drawSeamlessBaseRing(canvas, rect);
    }

    // 3 — Single overlap segment: one visible round tip, seamless base beneath.
    if (overlapRatio > 0) {
      _drawOverlapArc(canvas, rect, fullSweep * overlapRatio);
    }
  }

  @override
  bool shouldRepaint(covariant _MetricProgressRingPainter oldDelegate) {
    return oldDelegate.basePercent != basePercent ||
        oldDelegate.overlapRatio != overlapRatio ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor;
  }
}
