import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../repositories/profile_repository.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/common/cover_with_blur_bridge.dart';
import '../../providers/profile_images_provider.dart';
import '../../pages/insights/insights_detail_page.dart';
import '../../pages/trainer/become_trainer_page.dart';
import '../../pages/trainer/verification_submission_page.dart';
import '../../pages/refer/refer_friend_page.dart';
import '../profile/settings_page.dart';
import '../../widgets/profile/appearance_toggle.dart';

class TrainerProfilePage extends ConsumerStatefulWidget {
  const TrainerProfilePage({super.key});

  @override
  ConsumerState<TrainerProfilePage> createState() => _TrainerProfilePageState();
}

class _TrainerProfilePageState extends ConsumerState<TrainerProfilePage>
    with SingleTickerProviderStateMixin {
  String _username = 'Trainer';
  String _handle = '@user';
  final bool _isSubscribed = false;
  bool? _verified;

  String get _role => 'trainer';

  bool get _isPending => _verified == false;

  bool get _needsVerification => _role == 'trainer' && _verified != true;
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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profileRepo = ProfileRepository();
      final profile = await profileRepo.fetchMyProfile();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      bool? verified;
      if (userId != null) {
        try {
          final prov = await Supabase.instance.client
              .from('providers')
              .select('verified')
              .eq('user_id', userId)
              .maybeSingle();
          verified = prov?['verified'] as bool?;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _username = profile?['full_name'] as String? ?? profile?['username'] as String? ?? 'Trainer';
          _handle = profile?['username'] != null ? '@${profile!['username']}' : '@user';
          _verified = verified;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? Colors.grey.shade200 : colorScheme.background,
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
                Transform.translate(
                  offset: const Offset(0, -56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ProfileStatsStrip(
                      avgSteps: 7.2,
                      streakDays: 12,
                      level: 8,
                      xp: 1240,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const AppearanceToggle(),
                      ),
                      const SizedBox(height: 10),
                      // Verification Card for Trainers/Nutritionists
                      if ((_role == 'trainer' || _role == 'nutritionist') && _needsVerification) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _VerificationCard(
                            isPending: _isPending,
                            role: _role,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                PageTransitions.slideRoute(
                                  const VerificationSubmissionPage(),
                                  beginOffset: const Offset(0, 0.05),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                          SettingsPage(),
                          beginOffset: const Offset(0, 0.05),
                        ),
                      );
                    },
                        ),
                      ),
                      const SizedBox(height: 10),
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        PageTransitions.slideRoute(
                          const ReferFriendPage(),
                          beginOffset: const Offset(0, 0.05),
                        ),
                      );
                    },
                        ),
                      ),
                      // Show My Clients button for trainers and nutritionists
                      if (_role == 'trainer' || _role == 'nutritionist') ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _FullLengthButton(
                            label: 'My Clients',
                            icon: Icons.people_rounded,
                      iconGradient: const LinearGradient(
                        colors: [AppColors.blue, AppColors.cyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/my-clients');
                      },
                    ),
                        ),
                      ],
                      // Only show subscription button for clients
                      if (_role == 'client') ...[
                        const SizedBox(height: 10),
                        Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _FullLengthButton(
                            label: _isSubscribed ? 'My Subscription' : 'Subscription',
                            icon: Icons.star_rounded,
                      iconGradient: AppColors.stepsGradient,
                      onTap: () => HapticFeedback.lightImpact(),
                    ),
                        ),
                      ],
                      if (_role == 'client') ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _FullLengthButton(
                            label: 'Become a Trainer',
                            icon: Icons.school_rounded,
                            iconGradient: AppColors.becomeTrainerGradient,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        PageTransitions.slideRoute(
                          const BecomeTrainerPage(),
                          beginOffset: const Offset(0, 0.05),
                        ),
                      );
                    },
                  ),
                        ),
                      ],
                    ],
                  ),
                ),
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
    const double coverHeight = 280; // Increased from 220 to show more image
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Profile picture on the left
        Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: const CircleBorder(),
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1.5,
              ),
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
            overlayBottom: 28, // Increased from 22 to give breathing room
          ),
        ],
      ),
    );
  }
}


class _ProfileStatsStrip extends StatelessWidget {
  final double avgSteps;
  final int streakDays;
  final int level;
  final int xp;

  const _ProfileStatsStrip({
    required this.avgSteps,
    required this.streakDays,
    required this.level,
    required this.xp,
  });

  String _formatSteps(double steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toStringAsFixed(0);
  }

  String _formatXP(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    }
    return xp.toString();
  }

  @override
  Widget build(BuildContext context) {
    const profileNavGradient = LinearGradient(
      colors: [Color(0xFFFF5A5A), Color(0xFFFF8A7A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: profileNavGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.directions_walk_rounded,
            label: 'Avg Steps',
            value: _formatSteps(avgSteps),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              HapticFeedback.lightImpact();
              // Navigate to steps insights
              context.push(
                '/insights/steps',
                extra: InsightArgs(
                  MetricType.steps,
                  const [6, 7, 8, 7, 9, 8, 7],
                  goal: 10000,
                ),
              );
            },
          ),
          _StatItem(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '$streakDays days',
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: null, // No action for streak
          ),
          _StatItem(
            icon: Icons.emoji_events_rounded,
            label: 'Level',
            value: level.toString(),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              HapticFeedback.lightImpact();
              // Navigate to quest page
              context.push('/quest');
            },
          ),
          _StatItem(
            icon: Icons.star_rounded,
            label: 'XP',
            value: _formatXP(xp),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              HapticFeedback.lightImpact();
              // Navigate to quest page
              context.push('/quest');
            },
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final VoidCallback? onTap;
  final Color? textColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueColor = textColor ?? colorScheme.onSurface;
    final labelColor = textColor != null
        ? textColor!.withOpacity(0.9)
        : colorScheme.onSurface.withOpacity(0.6);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return Expanded(child: content);
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

class _VerificationCard extends StatelessWidget {
  final bool isPending;
  final String role;
  final VoidCallback onTap;

  const _VerificationCard({
    required this.isPending,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleLabel = role == 'nutritionist' ? 'Nutritionist' : 'Trainer';

    return PressableCard(
      onTap: onTap,
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isPending
              ? LinearGradient(
                  colors: [
                    AppColors.orange.withOpacity(0.1),
                    AppColors.orange.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppColors.orange.withOpacity(0.15),
                    AppColors.orange.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPending
                ? AppColors.orange.withOpacity(0.3)
                : AppColors.orange.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isPending
                    ? LinearGradient(
                        colors: [
                          AppColors.orange.withOpacity(0.2),
                          AppColors.orange.withOpacity(0.1),
                        ],
                      )
                    : AppColors.stepsGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPending ? Icons.hourglass_empty : Icons.verified_user_outlined,
                color: isPending ? AppColors.orange : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPending
                        ? 'Verification Pending'
                        : 'Verify Your $roleLabel Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPending
                        ? 'Documents submitted. Please wait up to 24 hours for verification.'
                        : 'Submit documents to verify your $roleLabel account and unlock all features.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withOpacity(0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
