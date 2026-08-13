import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'auth_screen_background.dart';
import 'auth_ui.dart';

/// Shown only after onboarding persistence succeeds.
class OnboardingAllSetView extends StatefulWidget {
  const OnboardingAllSetView({
    super.key,
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  State<OnboardingAllSetView> createState() => _OnboardingAllSetViewState();
}

class _OnboardingAllSetViewState extends State<OnboardingAllSetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);

    Widget timed(double start, Widget child) {
      if (reduce) return child;
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final p = ((_ctrl.value - start) / 0.18).clamp(0.0, 1.0);
          return Opacity(
            opacity: p,
            child: Transform.translate(
              offset: Offset(0, (1 - p) * 8),
              child: child,
            ),
          );
        },
      );
    }

    return AuthScreenBackground.success(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _CompletionMark(controller: _ctrl),
              const SizedBox(height: 28),
              timed(
                0.52,
                Text(
                  "YOU'RE ALL SET",
                  textAlign: TextAlign.center,
                  style: AuthUi.pageTitle(context).copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              timed(
                0.64,
                Text(
                  'Your Cotrainr profile is ready.',
                  textAlign: TextAlign.center,
                  style: AuthUi.pageSubtitle(context).copyWith(fontSize: 16),
                ),
              ),
              const Spacer(flex: 2),
              timed(
                0.76,
                AuthPrimaryButton(
                  label: "Let's get started",
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: widget.onContinue,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionMark extends StatelessWidget {
  const _CompletionMark({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final glow = Curves.easeOut.transform((t / 0.18).clamp(0.0, 1.0));
        final ring = Curves.easeOut.transform(((t - 0.10) / 0.22).clamp(0.0, 1.0));
        final check = Curves.easeOut.transform(((t - 0.28) / 0.22).clamp(0.0, 1.0));
        final settle = 1.0 +
            (t > 0.42 && t < 0.58 ? (0.5 - ((t - 0.42) / 0.16 - 0.5).abs()) * 0.04 : 0);

        return Transform.scale(
          scale: settle,
          child: SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _CompletionPainter(
                glow: glow,
                ring: ring,
                check: check,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompletionPainter extends CustomPainter {
  _CompletionPainter({
    required this.glow,
    required this.ring,
    required this.check,
  });

  final double glow;
  final double ring;
  final double check;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          CotrainrGradients.focus.withValues(alpha: 0.22 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.8));
    canvas.drawCircle(c, r * 1.8, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = CotrainrGradients.focus.withValues(alpha: 0.95 * ring);
    canvas.drawCircle(c, r, ringPaint);

    if (check <= 0) return;
    final path = Path()
      ..moveTo(c.dx - r * 0.38, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.08, c.dy + r * 0.32)
      ..lineTo(c.dx + r * 0.42, c.dy - r * 0.28);
    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * check);
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    canvas.drawPath(extract, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CompletionPainter oldDelegate) =>
      oldDelegate.glow != glow ||
      oldDelegate.ring != ring ||
      oldDelegate.check != check;
}
