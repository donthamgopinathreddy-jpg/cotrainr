import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/branding_assets.dart';

/// Soft SVG atmosphere layers for splash / startup screens.
///
/// Photographic assets stay PNG; decorative geometry is vector.
class SplashVectorLayers extends StatelessWidget {
  const SplashVectorLayers({
    super.key,
    this.opacity = 1,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SvgPicture.asset(
              BrandingAssets.orangeGradientSvg,
              fit: BoxFit.cover,
            ),
            SvgPicture.asset(
              BrandingAssets.orangeSmokeSvg,
              fit: BoxFit.cover,
            ),
            Align(
              alignment: const Alignment(0, -0.35),
              child: FractionallySizedBox(
                widthFactor: 0.85,
                heightFactor: 0.45,
                child: SvgPicture.asset(
                  BrandingAssets.lightGlowSvg,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SvgPicture.asset(
              BrandingAssets.orangeParticlesSvg,
              fit: BoxFit.cover,
            ),
            SvgPicture.asset(
              BrandingAssets.abstractLinesSvg,
              fit: BoxFit.cover,
            ),
            SvgPicture.asset(
              BrandingAssets.cornerOverlaySvg,
              fit: BoxFit.cover,
            ),
            SvgPicture.asset(
              BrandingAssets.orangeOverlaysSvg,
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),
    );
  }
}
