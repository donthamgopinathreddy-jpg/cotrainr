import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/common/pressable_card.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final String _username = 'John Doe';
  final String _handle = '@fitness_john';
  final String _role = 'client';
  final String _bio =
      'Fitness enthusiast on a journey to better health and strength.';
  final bool _isSubscribed = false;
  final String? _coverImageUrl = null;
  final String? _avatarUrl = null;
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
                  coverImageUrl: _coverImageUrl,
                  avatarUrl: _avatarUrl,
                  role: _role,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _IdentityRow(
                    username: _username,
                    handle: _handle,
                  ),
                ),
                const SizedBox(height: 8),
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

  const _ProfileCoverHeader({
    required this.coverImageUrl,
    required this.avatarUrl,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 220;
    const double avatarSize = 96;
    const double badgeOverlap = 12;
    final colorScheme = Theme.of(context).colorScheme;
    final Color bgColor = Theme.of(context).colorScheme.background;

    // Badge: below avatar, overlapping its bottom edge
    final String label = role == 'trainer'
        ? 'TRAINER'
        : role == 'nutritionist'
            ? 'NUTRITIONIST'
            : 'CLIENT';
    final Color bgColorBadge = role == 'trainer'
        ? colorScheme.primary.withValues(alpha: 0.2)
        : role == 'nutritionist'
            ? AppColors.green.withValues(alpha: 0.2)
            : colorScheme.surfaceVariant;
    final Color textColorBadge = role == 'trainer'
        ? colorScheme.primary
        : role == 'nutritionist'
            ? AppColors.green
            : colorScheme.onSurface.withValues(alpha: 0.9);

    final double avatarBottom = coverHeight - avatarSize / 2 + avatarSize;
    final double badgeTop = avatarBottom - badgeOverlap;

    return SizedBox(
      height: coverHeight + avatarSize / 2 + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: coverHeight,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
              ),
              child: Stack(
                children: [
                  if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Image(
                          image: NetworkImage(coverImageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  // Smooth blend into content below (shared with home)
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.coverBlendGradient(bgColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: coverHeight - avatarSize / 2,
            child: Container(
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
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: avatarUrl == null || avatarUrl!.isEmpty
                    ? colorScheme.surface
                    : null,
              ),
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? Icon(Icons.person,
                      size: 36, color: colorScheme.onSurface)
                  : null,
            ),
          ),
          // Badge below profile picture, overlapping bottom
          Positioned(
            left: 16,
            top: badgeTop,
            child: SizedBox(
              width: avatarSize,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColorBadge,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.surface.withValues(alpha: 0.9),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: textColorBadge,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  final String username;
  final String handle;

  const _IdentityRow({
    required this.username,
    required this.handle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          username,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          handle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
      ],
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
