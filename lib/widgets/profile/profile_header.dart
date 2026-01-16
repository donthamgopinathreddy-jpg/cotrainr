import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';
import '../common/pill_chip.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String handle;
  final int level;
  final String bio;
  final String? coverImageUrl;
  final String? avatarUrl;
  final VoidCallback? onEditProfile;
  final VoidCallback? onSettings;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.handle,
    required this.level,
    required this.bio,
    this.coverImageUrl,
    this.avatarUrl,
    this.onEditProfile,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: Column(
        children: [
          // Cover Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusCard),
            ),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: coverImageUrl == null
                    ? LinearGradient(
                        colors: [DesignTokens.accentRed, DesignTokens.accentRed.withValues(alpha: 204)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: Border.all(
                  color: DesignTokens.surfaceOf(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  if (coverImageUrl != null)
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Image(
                          image: CachedNetworkImageProvider(coverImageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar & Info
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            child: Column(
              children: [
                // Avatar (floating)
                Transform.translate(
                  offset: const Offset(0, -60),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: avatarUrl == null
                          ? LinearGradient(
                              colors: [DesignTokens.accentRed, DesignTokens.accentRed.withValues(alpha: 204)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      image: avatarUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: DesignTokens.surfaceOf(context),
                        width: 4,
                      ),
                      boxShadow: DesignTokens.cardShadowOf(context),
                    ),
                    child: avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 60,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: -40),

                // Username & Handle
                Text(
                  username,
                  style: AppTextStyles.h1(context),
                ),
                const SizedBox(height: DesignTokens.spacing4),
                Text(
                  handle,
                  style: AppTextStyles.secondary(context),
                ),
                const SizedBox(height: DesignTokens.spacing12),

                // Level Badge
                PillChip(
                  label: 'Level $level',
                  icon: Icons.star,
                  gradient: LinearGradient(
                    colors: [DesignTokens.accentRed, DesignTokens.accentRed.withValues(alpha: 204)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing16),

                // Bio
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(context),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      color: DesignTokens.textSecondary,
                      onPressed: onEditProfile,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacing16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onEditProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.surface,
                          foregroundColor: DesignTokens.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            vertical: DesignTokens.spacing12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                            side: BorderSide(
                              color: DesignTokens.borderColor,
                            ),
                          ),
                        ),
                        child: const Text('Edit Profile'),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),
                    ElevatedButton(
                      onPressed: onSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.surface,
                        foregroundColor: DesignTokens.textPrimary,
                        padding: const EdgeInsets.all(DesignTokens.spacing12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                          side: BorderSide(
                            color: DesignTokens.borderColor,
                          ),
                        ),
                      ),
                      child: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

