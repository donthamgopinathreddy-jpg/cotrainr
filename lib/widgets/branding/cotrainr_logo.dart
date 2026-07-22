import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/branding_assets.dart';
import '../../theme/design_tokens.dart';

/// Official Cotrainr mark rendered from the master SVG.
///
/// Never upscale a PNG logo — always use [BrandingAssets.logoSvg] /
/// [BrandingAssets.logoWhiteSvg].
class CotrainrLogo extends StatelessWidget {
  const CotrainrLogo({
    super.key,
    this.width,
    this.height,
    this.variant = CotrainrLogoVariant.color,
    this.semanticsLabel = 'Cotrainr',
  });

  final double? width;
  final double? height;
  final CotrainrLogoVariant variant;
  final String semanticsLabel;

  String get _asset => switch (variant) {
        CotrainrLogoVariant.color => BrandingAssets.logoSvg,
        CotrainrLogoVariant.white => BrandingAssets.logoWhiteSvg,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SvgPicture.asset(
        _asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    );
  }
}

enum CotrainrLogoVariant {
  /// White symbol + orange blade (master).
  color,

  /// All-white symbol (orange / photographic backgrounds).
  white,
}

/// Symbol + COTRAINR wordmark + optional tagline for splash / welcome.
class CotrainrBrandLockup extends StatelessWidget {
  const CotrainrBrandLockup({
    super.key,
    this.logoWidth = 120,
    this.showTagline = true,
    this.variant = CotrainrLogoVariant.color,
    this.wordmarkColor = Colors.white,
  });

  final double logoWidth;
  final bool showTagline;
  final CotrainrLogoVariant variant;
  final Color wordmarkColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CotrainrLogo(width: logoWidth, variant: variant),
        SizedBox(height: logoWidth * 0.14),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: (logoWidth * 0.22).clamp(18.0, 34.0),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              fontStyle: FontStyle.italic,
              height: 1.0,
              color: wordmarkColor,
            ),
            children: const [
              TextSpan(text: 'COTRAIN'),
              TextSpan(
                text: 'R',
                style: TextStyle(color: DesignTokens.accentOrange),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: logoWidth * 0.10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: (logoWidth * 0.072).clamp(9.0, 13.0),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
                color: wordmarkColor.withValues(alpha: 0.92),
              ),
              children: const [
                TextSpan(text: 'FIND. CONNECT. TRAIN. '),
                TextSpan(
                  text: 'TRANSFORM.',
                  style: TextStyle(color: DesignTokens.accentOrange),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
