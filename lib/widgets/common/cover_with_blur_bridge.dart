import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class CoverWithBlurBridge extends StatelessWidget {
  final Widget cover;
  final double height;
  final Widget overlayContent;
  final Color? pageBg;
  final double? overlayBottom;
  final double? overlayTop;

  const CoverWithBlurBridge({
    super.key,
    required this.cover,
    required this.overlayContent,
    this.height = 320,
    this.pageBg,
    this.overlayBottom,
    this.overlayTop,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        pageBg ??
        (Theme.of(context).brightness == Brightness.dark
            ? DesignTokens.darkBackground
            : DesignTokens.lightBackground);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          cover,

          // Light dark scrim (helps blend + text readability)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.18),
                  Colors.black.withOpacity(0.55),
                ],
              ),
            ),
          ),

          // Blur feather band (overlapping upwards)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BlurFeather(pageBg: bgColor),
          ),

          // Header content floating inside the band
          overlayTop != null
              ? Positioned(left: 16, top: overlayTop, child: overlayContent)
              : Positioned(
                  left: 16,
                  right: 16,
                  bottom: overlayBottom ?? 22,
                  child: overlayContent,
                ),
        ],
      ),
    );
  }
}

class _BlurFeather extends StatelessWidget {
  final Color pageBg;

  const _BlurFeather({required this.pageBg});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35, 0.75, 1.0],
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.35),
            Colors.white.withOpacity(0.85),
            Colors.white,
          ],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blur what's behind (MUST have a painted child)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Feather fade (into page bg)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    pageBg.withOpacity(0.00),
                    pageBg.withOpacity(0.30),
                    pageBg.withOpacity(0.75),
                    pageBg,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
