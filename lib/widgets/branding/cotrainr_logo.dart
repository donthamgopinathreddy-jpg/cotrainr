import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/branding_assets.dart';
import '../../theme/design_tokens.dart';

/// Official Cotrainr mark from master SVG (never upscale a PNG logo).
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
  color,
  white,
}

/// Official transparent wordmark asset (not a system font).
class CotrainrWordmark extends StatelessWidget {
  const CotrainrWordmark({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandingAssets.wordmarkOfficial,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        BrandingAssets.wordmark,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Tagline as Flutter text (not baked into artwork).
class CotrainrTagline extends StatelessWidget {
  const CotrainrTagline({
    super.key,
    this.fontSize = 11,
  });

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
          color: Colors.white.withValues(alpha: 0.92),
        ),
        children: const [
          TextSpan(text: 'FIND. CONNECT. TRAIN. '),
          TextSpan(
            text: 'TRANSFORM.',
            style: TextStyle(color: DesignTokens.accentOrange),
          ),
        ],
      ),
    );
  }
}

/// Symbol + official wordmark + optional tagline.
class CotrainrBrandLockup extends StatelessWidget {
  const CotrainrBrandLockup({
    super.key,
    this.logoWidth = 120,
    this.showTagline = true,
    this.showWordmark = true,
    this.variant = CotrainrLogoVariant.color,
  });

  final double logoWidth;
  final bool showTagline;
  final bool showWordmark;
  final CotrainrLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CotrainrLogo(width: logoWidth, variant: variant),
        if (showWordmark) ...[
          SizedBox(height: logoWidth * 0.12),
          CotrainrWordmark(width: logoWidth * 1.55),
        ],
        if (showTagline) ...[
          SizedBox(height: logoWidth * 0.10),
          CotrainrTagline(
            fontSize: (logoWidth * 0.072).clamp(9.0, 13.0),
          ),
        ],
      ],
    );
  }
}
