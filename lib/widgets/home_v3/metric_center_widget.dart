import 'dart:math' as math;
import 'dart:ui' show BlurStyle, MaskFilter, PathMetric;

import 'package:flutter/material.dart';
import 'home_premium_theme.dart';

/// Premium carousel metric capsule: animated border fill, inner ring, subtle glow.
class MetricCenterWidget extends StatefulWidget {
  final int metricIndex;
  final IconData icon;
  final double progress;
  final String label;
  final String mainValue;
  final String subValue;
  final bool selected;

  const MetricCenterWidget({
    super.key,
    required this.metricIndex,
    required this.icon,
    required this.progress,
    required this.label,
    required this.mainValue,
    required this.subValue,
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

  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

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

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ringAnim = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _ringCtrl,
      curve: Curves.easeOutCubic,
    ));

    _progressCtrl.forward();
    _ringCtrl.forward();

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

      final ringFrom = _ringAnim.value;
      _ringAnim = Tween<double>(
        begin: ringFrom,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: Curves.easeOutCubic,
      ));
      _ringCtrl.forward(from: 0);
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
    _ringCtrl.dispose();
    _breathCtrl?.dispose();
    _shimmerCtrl?.dispose();
    _particleCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = HomePremiumTheme.metricPalette(widget.metricIndex, isLight);

    final barWidth = widget.selected ? 156.0 : 126.0;
    final barHeight = widget.selected ? 70.0 : 56.0;
    final radius = widget.selected ? 14.0 : 12.0;

    final breathScale = widget.selected && _breathAnim != null
        ? 1.0 + (_breathAnim!.value * 0.01)
        : 1.0;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _progressAnim,
        _ringAnim,
        if (_breathCtrl != null) _breathCtrl!,
        if (_shimmerCtrl != null) _shimmerCtrl!,
        if (_particleCtrl != null) _particleCtrl!,
      ]),
      builder: (context, child) {
        final fill = _progressAnim.value.clamp(0.0, 1.0);
        final ringFill = _ringAnim.value.clamp(0.0, 1.0);
        final shimmer = _shimmerCtrl?.value ?? 0;
        final particle = _particleCtrl?.value ?? 0;

        final interiorColor = isLight
            ? Colors.white.withValues(alpha: 0.55)
            : HomePremiumTheme.darkCard.withValues(alpha: 0.65);

        final trackBorder = isLight
            ? HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.12);

        final labelColor = HomePremiumTheme.secondaryText(isLight);
        final valueColor = HomePremiumTheme.primaryText(isLight);
        final subColor = HomePremiumTheme.secondaryText(isLight).withValues(
              alpha: isLight ? 0.9 : 0.85,
            );

        return Transform.scale(
          scale: breathScale,
          alignment: Alignment.center,
          child: SizedBox(
            width: barWidth,
            height: barHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: ColoredBox(color: interiorColor),
                ),
                CustomPaint(
                  painter: _PremiumBorderPainter(
                    progress: fill,
                    gradient: palette.ringGradient,
                    accent: palette.accent,
                    trackColor: trackBorder,
                    strokeWidth: widget.selected ? 2.2 : 1.8,
                    cornerRadius: radius,
                    shimmerPhase: shimmer,
                    particlePhase: particle,
                    glowEnabled: widget.selected,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.selected ? 12 : 10,
                    vertical: widget.selected ? 8 : 7,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: widget.selected ? 40 : 34,
                        height: widget.selected ? 40 : 34,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.accent.withValues(
                                      alpha: widget.selected ? 0.28 : 0.16,
                                    ),
                                    blurRadius: widget.selected ? 14 : 10,
                                  ),
                                ],
                              ),
                              child: const SizedBox(width: 1, height: 1),
                            ),
                            CustomPaint(
                              size: Size.square(widget.selected ? 40 : 34),
                              painter: _InnerRingPainter(
                                progress: ringFill,
                                gradient: palette.ringGradient,
                                trackColor: trackBorder,
                                strokeWidth: widget.selected ? 3.0 : 2.5,
                              ),
                            ),
                            Icon(
                              widget.icon,
                              size: widget.selected ? 22 : 18,
                              color: palette.accent,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: widget.selected ? 10 : 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: widget.selected ? 9 : 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: labelColor,
                              ),
                            ),
                            SizedBox(height: widget.selected ? 3 : 2),
                            Text(
                              widget.mainValue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: widget.selected ? 17 : 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                                color: valueColor,
                              ),
                            ),
                            Text(
                              widget.subValue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: widget.selected ? 9 : 8,
                                fontWeight: FontWeight.w600,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumBorderPainter extends CustomPainter {
  final double progress;
  final LinearGradient gradient;
  final Color accent;
  final Color trackColor;
  final double strokeWidth;
  final double cornerRadius;
  final double shimmerPhase;
  final double particlePhase;
  final bool glowEnabled;

  _PremiumBorderPainter({
    required this.progress,
    required this.gradient,
    required this.accent,
    required this.trackColor,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.shimmerPhase,
    required this.particlePhase,
    required this.glowEnabled,
  });

  Path _roundedPath(Size size) {
    final stroke = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        stroke / 2,
        stroke / 2,
        size.width - stroke,
        size.height - stroke,
      ),
      Radius.circular(cornerRadius - stroke / 2),
    );
    return Path()..addRRect(rrect);
  }

  void _drawProgressSegment(
    Canvas canvas,
    PathMetric metric,
    double total,
    double start,
    double drawLen,
    Paint paint,
  ) {
    if (drawLen <= 0) return;
    if (start + drawLen <= total) {
      canvas.drawPath(metric.extractPath(start, start + drawLen), paint);
    } else {
      final combined = Path()
        ..addPath(metric.extractPath(start, total), Offset.zero)
        ..addPath(metric.extractPath(0, start + drawLen - total), Offset.zero);
      canvas.drawPath(combined, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedPath(size);
    final stroke = strokeWidth;
    final rrect = (path.getBounds());

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, trackPaint);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final metrics = path.computeMetrics();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    final start = total * 0.5;
    final drawLen = total * p;

    if (glowEnabled) {
      for (final w in [stroke + 5, stroke + 2.5]) {
        final glowPaint = Paint()
          ..color = accent.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        _drawProgressSegment(canvas, metric, total, start, drawLen, glowPaint);
      }
    }

    final progressPaint = Paint()
      ..shader = gradient.createShader(rrect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawProgressSegment(canvas, metric, total, start, drawLen, progressPaint);

    // Shimmer highlight on active edge
    final shimmerLen = total * 0.08;
    final shimmerStart = (start + drawLen - shimmerLen + shimmerPhase * total) % total;
    final shimmerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 0.5
      ..strokeCap = StrokeCap.round;
    _drawProgressSegment(
      canvas,
      metric,
      total,
      shimmerStart,
      shimmerLen,
      shimmerPaint,
    );

    // Traveling particle on border
    final particleDist = (start + drawLen * particlePhase) % total;
    final tangent = metric.getTangentForOffset(particleDist);
    if (tangent != null) {
      final particlePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(tangent.position, 2.8, particlePaint);
      canvas.drawCircle(
        tangent.position,
        1.2,
        Paint()..color = accent.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shimmerPhase != shimmerPhase ||
        oldDelegate.particlePhase != particlePhase ||
        oldDelegate.glowEnabled != glowEnabled;
  }
}

class _InnerRingPainter extends CustomPainter {
  final double progress;
  final LinearGradient gradient;
  final Color trackColor;
  final double strokeWidth;

  _InnerRingPainter({
    required this.progress,
    required this.gradient,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokeWidth;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final arc = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _InnerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
