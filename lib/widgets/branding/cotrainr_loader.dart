import 'package:flutter/material.dart';

import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';
import '../auth/auth_screen_background.dart';
import 'cotrainr_logo.dart';

enum CotrainrLoaderSize { fullscreen, compact, inline }

/// Branded Cotrainr loader: logo pieces assemble into the official mark.
class CotrainrLoader extends StatelessWidget {
  const CotrainrLoader.fullscreen({
    super.key,
    this.message,
    this.slowHint = false,
    this.error,
    this.onRetry,
  }) : size = CotrainrLoaderSize.fullscreen;

  const CotrainrLoader.compact({
    super.key,
    this.message,
    this.slowHint = false,
  })  : size = CotrainrLoaderSize.compact,
        error = null,
        onRetry = null;

  const CotrainrLoader.inline({
    super.key,
    this.message,
  })  : size = CotrainrLoaderSize.inline,
        slowHint = false,
        error = null,
        onRetry = null;

  /// Alias used by tests / compact call sites.
  const CotrainrLoader.standard({
    super.key,
    this.message,
    this.slowHint = false,
  })  : size = CotrainrLoaderSize.compact,
        error = null,
        onRetry = null;

  final CotrainrLoaderSize size;
  final String? message;
  final bool slowHint;
  final String? error;
  final VoidCallback? onRetry;

  String get _copy {
    if (error != null && error!.isNotEmpty) return error!;
    if (slowHint) return 'Taking a little longer…';
    return message ?? 'Getting you ready…';
  }

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case CotrainrLoaderSize.fullscreen:
        return _FullscreenLoader(
          copy: _copy,
          error: error,
          onRetry: onRetry,
        );
      case CotrainrLoaderSize.compact:
        return Semantics(
          label: 'Loading Cotrainr',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoAssemblyMark(size: 72),
              const SizedBox(height: 12),
              Text(
                _copy,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AuthTheme.secondaryText(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case CotrainrLoaderSize.inline:
        return Semantics(
          label: 'Loading Cotrainr',
          child: const SizedBox(
            width: 36,
            height: 36,
            child: LogoAssemblyMark(size: 36),
          ),
        );
    }
  }
}

class _FullscreenLoader extends StatelessWidget {
  const _FullscreenLoader({
    required this.copy,
    this.error,
    this.onRetry,
  });

  final String copy;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final fg = AuthTheme.secondaryText(context);

    return Semantics(
      label: 'Loading Cotrainr',
      liveRegion: true,
      child: AuthScreenBackground.loading(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoAssemblyMark(size: 108),
                  const SizedBox(height: 28),
                  Text(
                    copy,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (error != null && onRetry != null) ...[
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.accentOrange,
                        foregroundColor: DesignTokens.darkTextPrimary,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Official mark assembled from two short-travel pieces.
class LogoAssemblyMark extends StatefulWidget {
  const LogoAssemblyMark({super.key, this.size = 96});

  final double size;

  @override
  State<LogoAssemblyMark> createState() => _LogoAssemblyMarkState();
}

class _LogoAssemblyMarkState extends State<LogoAssemblyMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _ctrl.stop();
      _ctrl.value = 0.72;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final s = widget.size;

    if (reduce) {
      return SizedBox(
        width: s,
        height: s,
        child: CotrainrLogo(width: s, variant: CotrainrLogoVariant.color),
      );
    }

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          // 0–0.18 appear, 0.18–0.42 assemble, 0.42–0.58 illuminate/hold,
          // 0.58–0.78 hold official mark, 0.78–1.0 gentle deconstruct.
          final assemble = Curves.easeOutCubic.transform(
            ((t - 0.18) / 0.24).clamp(0.0, 1.0),
          );
          final hold = ((t - 0.42) / 0.16).clamp(0.0, 1.0);
          final deconstruct = t < 0.78
              ? 0.0
              : Curves.easeIn.transform(((t - 0.78) / 0.22).clamp(0.0, 1.0));
          final travel = 16.0 * (1 - assemble) + 10.0 * deconstruct;
          final pieceOpacity =
              (t / 0.18).clamp(0.0, 1.0) * (1 - deconstruct * 0.85);
          final officialOpacity =
              (hold * (1 - deconstruct)).clamp(0.0, 1.0);
          final orangeGlow = 0.35 + hold * 0.65;

          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: pieceOpacity * (1 - officialOpacity),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(-travel, -travel * 0.35),
                      child: CustomPaint(
                        size: Size(s, s),
                        painter: const _LogoPiecePainter(kind: _LogoPiece.white),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(travel, travel * 0.45),
                      child: Opacity(
                        opacity: orangeGlow.clamp(0.35, 1.0),
                        child: CustomPaint(
                          size: Size(s, s),
                          painter:
                              const _LogoPiecePainter(kind: _LogoPiece.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: officialOpacity,
                child: CotrainrLogo(
                  width: s,
                  variant: CotrainrLogoVariant.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _LogoPiece { white, orange }

class _LogoPiecePainter extends CustomPainter {
  const _LogoPiecePainter({required this.kind});

  final _LogoPiece kind;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = kind == _LogoPiece.orange
          ? const Color(0xFFFF8A00)
          : Colors.white;
    canvas.drawPath(_path(kind), paint);
  }

  Path _path(_LogoPiece kind) {
    if (kind == _LogoPiece.white) {
      return Path()
        ..moveTo(714, 665)
        ..lineTo(691, 663)
        ..lineTo(631, 654)
        ..lineTo(545, 643)
        ..lineTo(491, 636)
        ..lineTo(406, 625)
        ..lineTo(366, 620)
        ..lineTo(309, 614)
        ..lineTo(276, 608)
        ..lineTo(277, 604)
        ..lineTo(339, 513)
        ..lineTo(406, 419)
        ..lineTo(455, 453)
        ..lineTo(548, 463)
        ..lineTo(653, 473)
        ..lineTo(559, 402)
        ..lineTo(398, 287)
        ..lineTo(256, 505)
        ..lineTo(209, 580)
        ..lineTo(146, 680)
        ..lineTo(111, 734)
        ..lineTo(219, 725)
        ..lineTo(303, 715)
        ..lineTo(389, 705)
        ..lineTo(483, 693)
        ..lineTo(650, 674)
        ..lineTo(714, 667)
        ..close();
    }
    return Path()
      ..moveTo(507, 485)
      ..lineTo(529, 500)
      ..lineTo(548, 512)
      ..lineTo(577, 532)
      ..lineTo(637, 569)
      ..lineTo(665, 588)
      ..lineTo(591, 615)
      ..lineTo(837, 670)
      ..lineTo(907, 683)
      ..lineTo(826, 611)
      ..lineTo(686, 497)
      ..lineTo(537, 486)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _LogoPiecePainter oldDelegate) =>
      oldDelegate.kind != kind;
}
