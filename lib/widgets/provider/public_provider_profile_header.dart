import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/design_tokens.dart';
import '../provider/provider_avatar.dart';

const _kStatIconSize = 22.0;
const _kTypeIconSize = 16.0;
const _kWatermarkOpacity = 0.08;
const _kHideWatermarkBelow = 360.0;

/// Public trainer/nutritionist identity: photo, name, username, title pill.
class PublicProviderIdentityHeader extends StatelessWidget {
  final String name;
  final String? username;
  final String professionalTitle;
  final String? avatarUrl;
  final bool verified;
  final bool isNutritionist;

  const PublicProviderIdentityHeader({
    super.key,
    required this.name,
    required this.professionalTitle,
    this.username,
    this.avatarUrl,
    this.verified = false,
    this.isNutritionist = false,
  });

  IconData get _roleIcon => isNutritionist
      ? Icons.restaurant_rounded
      : Icons.fitness_center_rounded;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final handle = (username ?? '').trim();
    final width = MediaQuery.sizeOf(context).width;
    final showWatermark = width >= _kHideWatermarkBelow;
    final watermarkSize = width >= 412 ? 120.0 : width >= 390 ? 108.0 : 92.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (showWatermark)
              Positioned(
                right: -18,
                top: 4,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Icon(
                      _roleIcon,
                      size: watermarkSize,
                      color: DesignTokens.accentOrange.withValues(
                        alpha: _kWatermarkOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProviderAvatar(
                  imageUrl: avatarUrl,
                  name: name,
                  size: 88,
                  borderRadius: 18,
                  verified: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 20,
                                color: DesignTokens.accentOrange,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (handle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          handle.startsWith('@') ? handle : '@$handle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _ProfessionalTitlePill(
                        label: professionalTitle,
                        icon: _roleIcon,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalTitlePill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ProfessionalTitlePill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 140,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: DesignTokens.accentOrange.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: _kTypeIconSize,
              color: DesignTokens.accentOrange,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: DesignTokens.accentOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Experience | Clients | Reviews — equal-width columns, no location.
class PublicProviderHeaderStats extends StatelessWidget {
  final String experienceValue;
  final String clientsValue;
  final String reviewsValue;

  const PublicProviderHeaderStats({
    super.key,
    required this.experienceValue,
    required this.clientsValue,
    required this.reviewsValue,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Row(
        children: [
          _StatColumn(
            icon: Icons.work_rounded,
            value: experienceValue,
            label: 'Experience',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _StatColumn(
            icon: Icons.groups_rounded,
            value: clientsValue,
            label: 'Clients',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _StatColumn(
            icon: Icons.star_rounded,
            value: reviewsValue,
            label: 'Reviews',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color textPrimary;
  final Color textSecondary;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: _kStatIconSize,
                color: DesignTokens.accentOrange,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
