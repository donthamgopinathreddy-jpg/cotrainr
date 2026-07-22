import 'package:flutter/material.dart';

import '../../theme/branding_assets.dart';

/// Full-bleed dark athletic background for Login / Create Account.
class AuthScreenBackground extends StatelessWidget {
  const AuthScreenBackground({
    super.key,
    this.child,
    this.scrimStrength = 0.72,
  });

  final Widget? child;

  /// How strong the bottom readability scrim is (0–1).
  final double scrimStrength;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Image.asset(
          BrandingAssets.authBackground,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: Colors.black),
        ),
        // Soft top vignette + stronger bottom scrim so forms stay readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: scrimStrength * 0.85),
                Colors.black.withValues(alpha: scrimStrength),
              ],
              stops: const [0.0, 0.35, 0.62, 1.0],
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}
