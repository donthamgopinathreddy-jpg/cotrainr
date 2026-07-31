import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Rounded-square provider avatar used across Discover, profiles, and connected lists.
class ProviderAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final double borderRadius;
  final bool verified;
  final IconData? roleIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ProviderAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 64,
    this.borderRadius = 16,
    this.verified = false,
    this.roleIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  String get _initials {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '';
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.surfaceContainerHighest;
    final fg = foregroundColor ?? cs.onSurfaceVariant.withValues(alpha: 0.75);
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: ColoredBox(
              color: bg,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: url,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 180),
                      placeholder: (_, __) => _Placeholder(
                        size: size,
                        initials: _initials,
                        roleIcon: roleIcon,
                        foreground: fg,
                      ),
                      errorWidget: (_, __, ___) => _Placeholder(
                        size: size,
                        initials: _initials,
                        roleIcon: roleIcon,
                        foreground: fg,
                      ),
                    )
                  : _Placeholder(
                      size: size,
                      initials: _initials,
                      roleIcon: roleIcon,
                      foreground: fg,
                    ),
            ),
          ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    color: DesignTokens.accentOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: size * 0.16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final String initials;
  final IconData? roleIcon;
  final Color foreground;

  const _Placeholder({
    required this.size,
    required this.initials,
    required this.roleIcon,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    if (initials.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        roleIcon ?? Icons.person_rounded,
        size: size * 0.42,
        color: foreground,
      ),
    );
  }
}
