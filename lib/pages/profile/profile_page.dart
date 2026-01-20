import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/common/cover_with_blur_bridge.dart';
import '../../providers/profile_images_provider.dart';
import 'settings_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  final String _username = 'John Doe';
  final String _handle = '@fitness_john';
  final String _role = 'client';
  final String _bio =
      'Fitness enthusiast on a journey to better health and strength.';
  final bool _isSubscribed = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileCoverHeader(
                  coverImageUrl: ref.watch(profileImagesProvider).coverImagePath,
                  avatarUrl: ref.watch(profileImagesProvider).profileImagePath,
                  role: _role,
                  username: _username,
                  handle: _handle,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _bio,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FullLengthButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        PageTransitions.slideRoute(
                          const SettingsPage(),
                          beginOffset: const Offset(0, 0.05),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FullLengthButton(
                    label: 'Refer a Friend',
                    icon: Icons.person_add_rounded,
                    iconGradient: const LinearGradient(
                      colors: [AppColors.green, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => HapticFeedback.lightImpact(),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FullLengthButton(
                    label: _isSubscribed ? 'My Subscription' : 'Subscription',
                    icon: Icons.star_rounded,
                    iconGradient: AppColors.stepsGradient,
                    onTap: () => HapticFeedback.lightImpact(),
                  ),
                ),
                if (_role == 'client') ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _FullLengthButton(
                      label: 'Become a Trainer',
                      icon: Icons.school_rounded,
                      iconGradient: AppColors.distanceGradient,
                      onTap: () => HapticFeedback.lightImpact(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
        ),
    );
  }
}

class _ProfileCoverHeader extends StatelessWidget {
  final String? coverImageUrl;
  final String? avatarUrl;
  final String role;
  final String username;
  final String handle;

  const _ProfileCoverHeader({
    required this.coverImageUrl,
    required this.avatarUrl,
    required this.role,
    required this.username,
    required this.handle,
  });

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 220;
    const double avatarSize = 96;
    final colorScheme = Theme.of(context).colorScheme;

    // Badge: below avatar, overlapping its bottom edge
    final String label = role == 'trainer'
        ? 'TRAINER'
        : role == 'nutritionist'
            ? 'NUTRITIONIST'
            : 'CLIENT';
    final LinearGradient badgeGradient = role == 'trainer'
        ? AppColors.stepsGradient
        : role == 'nutritionist'
            ? const LinearGradient(
                colors: [AppColors.green, AppColors.cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.distanceGradient;

    // Cover image widget
    Widget coverWidget = Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: coverImageUrl != null && coverImageUrl!.isNotEmpty
          ? Image(
              image: coverImageUrl!.startsWith('http')
                  ? NetworkImage(coverImageUrl!)
                  : FileImage(File(coverImageUrl!)) as ImageProvider,
              fit: BoxFit.cover,
            )
          : null,
    );

    // Overlay content (avatar on left, name/user ID/badge/level on right)
    Widget overlayContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile picture on the left
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            image: avatarUrl != null && avatarUrl!.isNotEmpty
                ? DecorationImage(
                    image: avatarUrl!.startsWith('http')
                        ? NetworkImage(avatarUrl!)
                        : FileImage(File(avatarUrl!)) as ImageProvider,
                    fit: BoxFit.cover,
                  )
                : null,
            color: avatarUrl == null || avatarUrl!.isEmpty
                ? colorScheme.surface
                : null,
          ),
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? Icon(Icons.person, size: 36, color: colorScheme.onSurface)
              : null,
        ),
        const SizedBox(width: 12),
        // Name, user ID, badge and level on the right
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              Text(
                username,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              // User ID below name
              Text(
                handle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              // Badge and level horizontal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: badgeGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'LVL 1 Beginner',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return SizedBox(
      height: coverHeight + avatarSize / 2 + 8,
      child: Stack(
        children: [
          CoverWithBlurBridge(
            height: coverHeight,
            cover: coverWidget,
            overlayContent: overlayContent,
            overlayBottom: 60, // Lower position - between cover and next section
          ),
        ],
      ),
    );
  }
}


class _FullLengthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? iconGradient;

  const _FullLengthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconGradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget iconWidget = Icon(
      icon,
      size: 20,
      color: iconGradient == null
          ? colorScheme.onSurface.withOpacity(0.8)
          : Colors.white,
    );
    if (iconGradient != null) {
      iconWidget = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => iconGradient!.createShader(bounds),
        child: iconWidget,
      );
    }

    return PressableCard(
      onTap: onTap,
      borderRadius: 24,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.5), size: 22),
          ],
        ),
      ),
    );
  }
}
