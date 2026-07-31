import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/design_tokens.dart';
import '../common/pressable_card.dart';
import '../home_v3/home_premium_theme.dart';
import 'provider_avatar.dart';

class ConnectedProviderCardData {
  final String providerId;
  final String fullName;
  final String roleLabel;
  final String? avatarUrl;
  final String? headlineOrSpecialty;
  final bool verified;
  final double rating;
  final int reviewCount;
  final int? experienceYears;
  final int? myRating;

  const ConnectedProviderCardData({
    required this.providerId,
    required this.fullName,
    required this.roleLabel,
    this.avatarUrl,
    this.headlineOrSpecialty,
    this.verified = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.experienceYears,
    this.myRating,
  });
}

/// Shared card for connected trainers and nutritionists.
class ConnectedProviderCard extends StatelessWidget {
  final ConnectedProviderCardData data;
  final bool isLight;
  final bool canMessage;
  final bool messagingChecked;
  final VoidCallback onViewProfile;
  final VoidCallback onMessage;
  final VoidCallback onRate;

  const ConnectedProviderCard({
    super.key,
    required this.data,
    required this.isLight,
    required this.canMessage,
    required this.messagingChecked,
    required this.onViewProfile,
    required this.onMessage,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final cardColor =
        isLight ? const Color(0xFFEEF0F3) : HomePremiumTheme.darkCard;

    return PressableCard(
      onTap: onViewProfile,
      borderRadius: 20,
      pressScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: HomePremiumTheme.softCardShadow(isLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProviderAvatar(
                  imageUrl: data.avatarUrl,
                  name: data.fullName,
                  size: 56,
                  borderRadius: 14,
                  verified: data.verified,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.roleLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.accentOrange,
                        ),
                      ),
                      if ((data.headlineOrSpecialty ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          data.headlineOrSpecialty!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2EBD85)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Connected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2EBD85),
                              ),
                            ),
                          ),
                          if (data.reviewCount > 0)
                            Text(
                              '⭐ ${data.rating.toStringAsFixed(1)} (${data.reviewCount})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                              ),
                            ),
                          if (data.experienceYears != null &&
                              data.experienceYears! > 0)
                            Text(
                              '${data.experienceYears}y exp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onViewProfile();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide.none,
                      backgroundColor: isLight
                          ? const Color(0xFFEEEEF0)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (!messagingChecked || !canMessage)
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            onMessage();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          HomePremiumTheme.metricPalette(2, isLight).accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          HomePremiumTheme.metricPalette(2, isLight)
                              .accent
                              .withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text(
                      'Message',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onRate();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      data.myRating != null
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: DesignTokens.accentOrange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.myRating != null
                            ? 'Your rating: ${data.myRating} ★  ·  Edit review'
                            : 'Rate provider',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                    ),
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
