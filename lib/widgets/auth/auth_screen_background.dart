import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Premium animated auth backdrop — black / charcoal / orange only.
/// No photos, illustrations, or distracting shapes.
class AuthScreenBackground extends StatefulWidget {
  const AuthScreenBackground({
    super.key,
    this.child,
    this.scrimStrength = 0.55,
  });

  final Widget? child;

  /// Extra bottom dim for form readability (0–1).
  final double scrimStrength;

  @override
  State<AuthScreenBackground> createState() => _AuthScreenBackgroundState();
}

class _AuthScreenBackgroundState extends State<AuthScreenBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: isLight
              ? DesignTokens.lightBackground
              : DesignTokens.darkBackground,
        ),
        if (reduceMotion)
          _StaticLayers(isLight: isLight, scrim: widget.scrimStrength)
        else
          AnimatedBuilder(
            animation: _breath,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_breath.value);
              return _AnimatedLayers(
                t: t,
                isLight: isLight,
                scrim: widget.scrimStrength,
              );
            },
          ),
        // Soft vignette
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [
                Colors.transparent,
                (isLight ? Colors.black : Colors.black)
                    .withValues(alpha: isLight ? 0.04 : 0.42),
              ],
              stops: const [0.55, 1.0],
            ),
          ),
        ),
        // Tiny noise (very subtle)
        const IgnorePointer(child: _NoiseOverlay(opacity: 0.035)),
        ?widget.child,
      ],
    );
  }
}

class _StaticLayers extends StatelessWidget {
  const _StaticLayers({required this.isLight, required this.scrim});

  final bool isLight;
  final double scrim;

  @override
  Widget build(BuildContext context) {
    return _AnimatedLayers(t: 0.45, isLight: isLight, scrim: scrim);
  }
}

class _AnimatedLayers extends StatelessWidget {
  const _AnimatedLayers({
    required this.t,
    required this.isLight,
    required this.scrim,
  });

  final double t;
  final bool isLight;
  final double scrim;

  @override
  Widget build(BuildContext context) {
    final glowAlpha = isLight ? (0.10 + t * 0.06) : (0.22 + t * 0.10);
    final meshAlpha = isLight ? 0.06 : 0.14;
    final charcoal = isLight
        ? DesignTokens.lightMutedCardBackground
        : DesignTokens.darkSurfaceElevated;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft charcoal mesh
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8 + t * 0.15, -1),
              end: Alignment(0.9 - t * 0.1, 1.1),
              colors: [
                charcoal.withValues(alpha: meshAlpha),
                Colors.transparent,
                charcoal.withValues(alpha: meshAlpha * 0.7),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // Large blurred orange glow — slow drift
        Align(
          alignment: Alignment(-0.55 + t * 0.18, -0.72 + t * 0.08),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
            child: Container(
              width: 280 + t * 36,
              height: 280 + t * 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.accentOrange.withValues(alpha: glowAlpha),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment(0.75 - t * 0.12, 0.55 - t * 0.06),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              width: 220 + t * 24,
              height: 220 + t * 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.accentAmber
                    .withValues(alpha: glowAlpha * 0.45),
              ),
            ),
          ),
        ),
        // Bottom readability scrim
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? [
                      DesignTokens.lightBackground.withValues(alpha: 0.15),
                      DesignTokens.lightBackground.withValues(alpha: 0.55),
                      DesignTokens.lightBackground
                          .withValues(alpha: 0.75 + scrim * 0.2),
                    ]
                  : [
                      Colors.transparent,
                      DesignTokens.darkBackground
                          .withValues(alpha: scrim * 0.35),
                      DesignTokens.darkBackground
                          .withValues(alpha: 0.55 + scrim * 0.35),
                    ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoiseOverlay extends StatelessWidget {
  const _NoiseOverlay({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NoisePainter(opacity: opacity),
      child: const SizedBox.expand(),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    // Sparse deterministic dots — cheap “film grain”
    final count = (size.width * size.height / 2800).clamp(80, 220).toInt();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      paint.color = Colors.white.withValues(
        alpha: opacity * (0.4 + rng.nextDouble() * 0.6),
      );
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
