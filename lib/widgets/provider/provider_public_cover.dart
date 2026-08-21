import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../utils/provider_cover_url.dart';
import '../branding/cotrainr_logo.dart';

/// Public trainer/nutritionist cover. Real `cover_url` when valid; otherwise
/// a branded Cotrainr mark — never avatar, never “no cover” copy.
class ProviderPublicCover extends StatelessWidget {
  final String? coverUrl;
  final String? avatarUrl;

  const ProviderPublicCover({
    super.key,
    this.coverUrl,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolveProviderCoverUrl(
      coverUrl: coverUrl,
      avatarUrl: avatarUrl,
    );
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => const ProviderCoverFallback(),
        errorWidget: (_, _, _) => const ProviderCoverFallback(),
      );
    }
    return const ProviderCoverFallback();
  }
}

class ProviderCoverFallback extends StatelessWidget {
  const ProviderCoverFallback({super.key});

  static const double _logoHeight = 88;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final logo = const CotrainrLogo(
      height: _logoHeight,
      variant: CotrainrLogoVariant.white,
    );
    return ColoredBox(
      color: isLight
          ? DesignTokens.lightMutedCardBackground
          : DesignTokens.darkBackground,
      child: Center(
        child: Opacity(
          opacity: isLight ? 0.5 : 0.88,
          child: isLight
              ? ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                  child: logo,
                )
              : logo,
        ),
      ),
    );
  }
}
