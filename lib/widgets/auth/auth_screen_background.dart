import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';

/// Atmosphere intensity for the shared auth environment.
enum AuthBackgroundIntensity {
  /// Login / Welcome — most alive, still predominantly black.
  hero,

  /// Onboarding forms — quieter so content leads.
  onboarding,

  /// Full-screen loader — glow concentrated behind the logo.
  loader,

  /// All Set — subtle central completion glow.
  success,
}

/// Shared Cotrainr auth backdrop: studio-black with soft fitness lighting.
///
/// One system for Welcome, Login, onboarding, and auth loaders.
/// No photos, no full-screen orange, no corner blobs.
class AuthScreenBackground extends StatefulWidget {
  const AuthScreenBackground({
    super.key,
    this.child,
    this.scrimStrength,
    this.intensity = AuthBackgroundIntensity.hero,
    this.showEnergyMotif = true,
  });

  const AuthScreenBackground.login({
    super.key,
    this.child,
    this.scrimStrength,
    this.showEnergyMotif = true,
  }) : intensity = AuthBackgroundIntensity.hero;

  const AuthScreenBackground.onboarding({
    super.key,
    this.child,
    this.scrimStrength,
    this.showEnergyMotif = true,
  }) : intensity = AuthBackgroundIntensity.onboarding;

  const AuthScreenBackground.loading({
    super.key,
    this.child,
    this.scrimStrength,
    this.showEnergyMotif = false,
  }) : intensity = AuthBackgroundIntensity.loader;

  const AuthScreenBackground.success({
    super.key,
    this.child,
    this.scrimStrength,
    this.showEnergyMotif = true,
  }) : intensity = AuthBackgroundIntensity.success;

  final Widget? child;

  /// Extra bottom dim for form readability (0–1). Null uses [intensity] default.
  final double? scrimStrength;

  final AuthBackgroundIntensity intensity;

  /// Kept for API compatibility. Lighting is now fully painted.
  final bool showEnergyMotif;

  @override
  State<AuthScreenBackground> createState() => _AuthScreenBackgroundState();
}

class _AuthScreenBackgroundState extends State<AuthScreenBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  double get _scrim =>
      widget.scrimStrength ??
      switch (widget.intensity) {
        AuthBackgroundIntensity.hero => 0.16,
        AuthBackgroundIntensity.onboarding => 0.20,
        AuthBackgroundIntensity.loader => 0.12,
        AuthBackgroundIntensity.success => 0.18,
      };

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduce) {
      _breathe.stop();
      _breathe.value = 1;
    } else if (!_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, child) {
        final live = 0.86 + (_breathe.value * 0.14);
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AuthTheme.background(context),
            ),
            CustomPaint(
              painter: _AuthAtmospherePainter(
                isLight: isLight,
                intensity: widget.intensity,
                scrim: _scrim,
                live: live,
              ),
            ),
            const IgnorePointer(child: _GrainOverlay()),
            ?child,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _AuthAtmospherePainter extends CustomPainter {
  _AuthAtmospherePainter({
    required this.isLight,
    required this.intensity,
    required this.scrim,
    required this.live,
  });

  final bool isLight;
  final AuthBackgroundIntensity intensity;
  final double scrim;
  final double live;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = switch (intensity) {
      AuthBackgroundIntensity.hero => 1.0,
      AuthBackgroundIntensity.onboarding => 0.82,
      AuthBackgroundIntensity.loader => 0.90,
      AuthBackgroundIntensity.success => 0.78,
    };
    final k = live * strength;

    _paintTemperature(canvas, size, k);
    _paintStudioLights(canvas, size, k);
    _paintStage(canvas, size, k);
    _paintReadableFloor(canvas, size);
    _paintVignette(canvas, size);
  }

  /// Warm night sky into true black — no hard bands.
  void _paintTemperature(Canvas canvas, Size size, double k) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? [
                const Color(0xFFFFF6EC),
                const Color(0xFFF6F1EA),
                const Color(0xFFF3EEE8),
              ]
            : [
                Color.lerp(
                  const Color(0xFF140C08),
                  const Color(0xFF050505),
                  1 - (0.55 * k),
                )!,
                const Color(0xFF070707),
                const Color(0xFF000000),
              ],
        stops: isLight ? const [0.0, 0.42, 1.0] : const [0.0, 0.42, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintStudioLights(Canvas canvas, Size size, double k) {
    final centered = intensity == AuthBackgroundIntensity.loader ||
        intensity == AuthBackgroundIntensity.success;

    final keyCenter = centered
        ? Offset(size.width * 0.50, size.height * 0.34)
        : Offset(size.width * 0.58, size.height * 0.02);
    final keyRadius =
        centered ? size.shortestSide * 0.78 : size.height * 0.78;

    // Key light — huge, slow falloff, Discover orange at low opacity.
    _radial(
      canvas,
      size,
      center: keyCenter,
      radius: keyRadius,
      colors: [
        DesignTokens.discoverOrange.withValues(alpha: (isLight ? 0.10 : 0.18) * k),
        DesignTokens.discoverOrangeDeep.withValues(alpha: (isLight ? 0.045 : 0.08) * k),
        Colors.transparent,
      ],
      stops: const [0.0, 0.38, 1.0],
    );

    // Fill light — opposite side, cooler-warm so it feels dimensional.
    if (!centered) {
      _radial(
        canvas,
        size,
        center: Offset(size.width * -0.05, size.height * 0.52),
        radius: size.width * 0.95,
        colors: [
          const Color(0xFF3A2414).withValues(alpha: (isLight ? 0.06 : 0.22) * k),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      );
    }

    // Floor bounce — keeps the bottom from feeling like a void.
    _radial(
      canvas,
      size,
      center: Offset(size.width * 0.50, size.height * 1.08),
      radius: size.width * 0.95,
      colors: [
        DesignTokens.discoverOrangeDeep.withValues(alpha: (isLight ? 0.035 : 0.06) * k),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    );
  }

  /// Soft lift behind the form / logo — studio spotlight, not a blob.
  void _paintStage(Canvas canvas, Size size, double k) {
    final y = switch (intensity) {
      AuthBackgroundIntensity.loader => 0.38,
      AuthBackgroundIntensity.success => 0.36,
      AuthBackgroundIntensity.hero => 0.40,
      AuthBackgroundIntensity.onboarding => 0.36,
    };
    _radial(
      canvas,
      size,
      center: Offset(size.width * 0.50, size.height * y),
      radius: size.shortestSide * 0.72,
      colors: [
        Colors.white.withValues(alpha: (isLight ? 0.28 : 0.035) * k),
        DesignTokens.discoverOrange.withValues(alpha: (isLight ? 0.04 : 0.045) * k),
        Colors.transparent,
      ],
      stops: const [0.0, 0.42, 1.0],
    );
  }

  void _paintReadableFloor(Canvas canvas, Size size) {
    final base = isLight ? const Color(0xFFF6F1EA) : const Color(0xFF000000);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          base.withValues(alpha: scrim * 0.12),
          base.withValues(alpha: 0.22 + scrim * 0.35),
        ],
        stops: const [0.38, 0.68, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintVignette(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: isLight ? 0.03 : 0.42),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _radial(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required List<Color> colors,
    required List<double> stops,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _AuthAtmospherePainter oldDelegate) =>
      oldDelegate.isLight != isLight ||
      oldDelegate.intensity != intensity ||
      oldDelegate.scrim != scrim ||
      oldDelegate.live != live;
}

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _GrainPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    final count = (size.width * size.height / 5200).clamp(40, 90).toInt();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      paint.color = Colors.white.withValues(alpha: 0.012 + rng.nextDouble() * 0.01);
      canvas.drawCircle(Offset(x, y), 0.45, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}
