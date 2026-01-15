import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';

class HeroHeaderWidget extends StatelessWidget {
  final String? coverImageUrl;
  final String? avatarUrl;
  final String username;
  final int notificationCount;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationTap;

  const HeroHeaderWidget({
    super.key,
    this.coverImageUrl,
    this.avatarUrl,
    required this.username,
    this.notificationCount = 0,
    this.onAvatarTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover Image or Gradient
          Positioned.fill(
            child: coverImageUrl != null && coverImageUrl!.isNotEmpty
                ? Image.network(
                    coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildGradientFallback(),
                  )
                : _buildGradientFallback(),
          ),

          // Overlay: top clear → bottom dark fade
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Blur behind text
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: DesignTokens.glassBlur, sigmaY: DesignTokens.glassBlur),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        DesignTokens.darkBackground.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Left: Avatar with ring (glow gradient)
          Positioned(
            left: DesignTokens.spacing16,
            bottom: -28,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAvatarTap?.call();
                context.push('/home/profile');
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: DesignTokens.glowShadowOf(context),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildAvatarPlaceholder(),
                        )
                      : _buildAvatarPlaceholder(),
                ),
              ),
            ),
          ),

          // Text: Welcome back (meta) + Username (H1 bold)
          Positioned(
            left: DesignTokens.spacing16,
            right: 80,
            bottom: DesignTokens.spacing16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeMeta,
                    color: DesignTokens.textSecondaryOf(context),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeH1,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right: Notification glass button with dot badge
          Positioned(
            top: MediaQuery.of(context).padding.top + DesignTokens.spacing16,
            right: DesignTokens.spacing16,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onNotificationTap?.call();
                context.push('/home/notifications');
              },
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                borderRadius: BorderRadius.circular(22),
                onTap: null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: DesignTokens.textPrimaryOf(context),
                      size: DesignTokens.iconSizeNavBar,
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: DesignTokens.primaryGradient,
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: DesignTokens.primaryGradient,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}



