import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'home_premium_theme.dart';

/// Circular progress ring with icon only (no text inside).
class MetricCenterWidget extends StatefulWidget {
  final int metricIndex;
  final IconData icon;
  final double progress;
  final bool selected;

  const MetricCenterWidget({
    super.key,
    required this.metricIndex,
    required this.icon,
    required this.progress,
    required this.selected,
  });

  @override
  State<MetricCenterWidget> createState() => _MetricCenterWidgetState();
}

class _MetricCenterWidgetState extends State<MetricCenterWidget>
    with TickerProviderStateMixin {
  static const _progressDuration = Duration(milliseconds: 1200);

  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  AnimationController? _breathCtrl;
  Animation<double>? _breathAnim;

  AnimationController? _shimmerCtrl;
  AnimationController? _particleCtrl;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _progressDuration);
    _progressAnim = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeOutCubic,
    ));
    _progressCtrl.forward();

    if (widget.selected) {
      _startAmbientAnimations();
    }
  }

  void _startAmbientAnimations() {
    _breathCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _breathCtrl!, curve: Curves.easeInOut),
    );

    _shimmerCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    _particleCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  void _stopAmbientAnimations() {
    _breathCtrl?.dispose();
    _breathCtrl = null;
    _breathAnim = null;
    _shimmerCtrl?.dispose();
    _shimmerCtrl = null;
    _particleCtrl?.dispose();
    _particleCtrl = null;
  }

  @override
  void didUpdateWidget(covariant MetricCenterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final from = _progressAnim.value;
      _progressAnim = Tween<double>(
        begin: from,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _progressCtrl,
        curve: Curves.easeOutCubic,
      ));
      _progressCtrl.forward(from: 0);
    }

    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _startAmbientAnimations();
      } else {
        _stopAmbientAnimations();
      }
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _breathCtrl?.dispose();
    _shimmerCtrl?.dispose();
    _particleCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = HomePremiumTheme.metricPalette(widget.metricIndex, isLight);

    final ringSize = widget.selected ? 92.0 : 72.0;
    final stroke = widget.selected ? 3.6 : 2.8;

    final breathScale = widget.selected && _breathAnim != null
        ? 1.0 + (_breathAnim!.value * 0.012)
        : 1.0;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _progressAnim,
        ?_breathCtrl,
        ?_shimmerCtrl,
        ?_particleCtrl,
      ]),
      builder: (context, child) {
        final fill = _progressAnim.value.clamp(0.0, 1.0);
        final shimmer = _shimmerCtrl?.value ?? 0;
        final particle = _particleCtrl?.value ?? 0;

        final trackColor = isLight
            ? HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.12);

        return Transform.scale(
          scale: breathScale,
          alignment: Alignment.center,
          child: SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(ringSize),
                  painter: _MetricRingPainter(
                    progress: fill,
                    gradient: palette.ringGradient,
                    accent: palette.accent,
                    trackColor: trackColor,
                    strokeWidth: stroke,
                    shimmerPhase: shimmer,
                    particlePhase: particle,
                    glowEnabled: widget.selected,
                  ),
                ),
                Icon(
                  widget.icon,
                  size: widget.selected ? 32 : 26,
                  color: palette.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricRingPainter extends CustomPainter {
  final double progress;
  final LinearGradient gradient;
  final Color accent;
  final Color trackColor;
  final double strokeWidth;
  final double shimmerPhase;
  final double particlePhase;
  final bool glowEnabled;

  _MetricRingPainter({
    required this.progress,
    required this.gradient,
    required this.accent,
    required this.trackColor,
    required this.strokeWidth,
    required this.shimmerPhase,
    required this.particlePhase,
    required this.glowEnabled,
  });

  Rect _arcRect(Size size) {
    final stroke = strokeWidth;
    return Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _arcRect(size);
    final stroke = strokeWidth;
    const startAngle = -math.pi / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final sweep = math.pi * 2 * p;

    if (glowEnabled) {
      for (final w in [stroke + 5, stroke + 2.5]) {
        final glow = Paint()
          ..color = accent.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawArc(rect, startAngle, sweep, false, glow);
      }
    }

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, progressPaint);

    final headAngle = startAngle + sweep;
    final shimmerSweep = math.pi * 2 * 0.06;
    final shimmerStart =
        headAngle - shimmerSweep + shimmerPhase * math.pi * 2 * 0.15;
    final shimmerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 0.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, shimmerStart, shimmerSweep, false, shimmerPaint);

    final particleAngle = startAngle + sweep * particlePhase;
    final cx = rect.center.dx + rect.width / 2 * math.cos(particleAngle);
    final cy = rect.center.dy + rect.height / 2 * math.sin(particleAngle);
    final particlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx, cy), 2.6, particlePaint);
    canvas.drawCircle(
      Offset(cx, cy),
      1.1,
      Paint()..color = accent.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _MetricRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shimmerPhase != shimmerPhase ||
        oldDelegate.particlePhase != particlePhase ||
        oldDelegate.glowEnabled != glowEnabled ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
