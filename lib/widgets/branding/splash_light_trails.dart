import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Subtle animated orange speed trails for splash / welcome (not baked into photo).
class SplashLightTrails extends StatelessWidget {
  const SplashLightTrails({
    super.key,
    required this.progress,
    this.opacity = 1,
  });

  /// 0–1 animation driver (opacity + slight drift).
  final double progress;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: (opacity * progress.clamp(0.0, 1.0)).clamp(0.0, 1.0),
        child: CustomPaint(
          painter: _LightTrailsPainter(t: progress),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LightTrailsPainter extends CustomPainter {
  _LightTrailsPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(t * math.pi * 2) * 4;
    final orange = DesignTokens.accentOrange;

    // Vertical speed streaks (upper half).
    final vertPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final xs = <double>[0.18, 0.28, 0.38, 0.48, 0.58, 0.68, 0.78, 0.88];
    for (var i = 0; i < xs.length; i++) {
      final x = size.width * xs[i] + drift * (i.isEven ? 1 : -0.6);
      final top = size.height * (0.02 + (i % 3) * 0.01);
      final bottom = size.height * (0.42 + (i % 4) * 0.03);
      vertPaint
        ..strokeWidth = (1.2 + (i % 3) * 0.9)
        ..shader = ui.Gradient.linear(
          Offset(x, top),
          Offset(x, bottom),
          [
            orange.withValues(alpha: 0.0),
            orange.withValues(alpha: 0.55),
            orange.withValues(alpha: 0.12),
            orange.withValues(alpha: 0.0),
          ],
          const [0.0, 0.25, 0.7, 1.0],
        );
      canvas.drawLine(Offset(x, top), Offset(x, bottom), vertPaint);
    }

    // Perspective ground rays (mid band).
    final origin = Offset(size.width * 0.5, size.height * 0.52);
    final groundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final angles = <double>[-0.95, -0.7, -0.45, -0.22, 0.22, 0.45, 0.7, 0.95];
    for (var i = 0; i < angles.length; i++) {
      final a = angles[i];
      final len = size.height * (0.22 + (i % 3) * 0.03);
      final end = origin + Offset(math.sin(a) * len * 1.6, math.cos(a) * len * 0.55);
      groundPaint
        ..strokeWidth = 1.5 + (i % 2) * 0.8
        ..shader = ui.Gradient.linear(
          origin,
          end,
          [
            orange.withValues(alpha: 0.5),
            orange.withValues(alpha: 0.08),
            orange.withValues(alpha: 0.0),
          ],
        );
      canvas.drawLine(origin, end, groundPaint);
    }

    // Soft center glow behind athlete.
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.32),
        size.width * 0.42,
        [
          orange.withValues(alpha: 0.22),
          orange.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.32),
      size.width * 0.42,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _LightTrailsPainter oldDelegate) =>
      oldDelegate.t != t;
}
