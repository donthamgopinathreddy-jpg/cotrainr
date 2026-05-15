import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile/appearance_toggle.dart';
import '../../repositories/profile_repository.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/common/pressable_card.dart';
import '../../providers/profile_images_provider.dart';
import '../../pages/trainer/become_trainer_page.dart';
import '../../pages/trainer/verification_submission_page.dart';
import '../../pages/refer/refer_friend_page.dart';
import 'settings_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  final ProfileRepository _profileRepo = ProfileRepository();

  String _username = 'Loading...';
  String _handle = '@loading';
  final bool _isSubscribed = false;
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;

  // Check verification status - in real app, fetch from Supabase
  String? get _verificationStatus {
    if (_role == 'trainer' || _role == 'nutritionist') {
      // Check if verified from providers table
      final verified = _profile?['verified'] as bool?;
      if (verified == true) return 'verified';
      return 'pending';
    }
    return null;
  }

  bool get _isPending {
    return _verificationStatus == 'pending';
  }

  bool get _needsVerification {
    if (_role == 'trainer' || _role == 'nutritionist') {
      // Show verification card if not verified
      return _verificationStatus != 'verified';
    }
    return false;
  }
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
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (profile != null) {
        setState(() {
          _profile = profile;
          _username = profile['full_name'] as String? ?? 
                      profile['username'] as String? ?? 
                      'User';
          final username = profile['username'] as String? ?? '';
          _handle = '@$username';
        });
      }

    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }
  
  String get _role {
    return _profile?['role'] as String? ?? 'client';
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
      backgroundColor: colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top),
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppearanceThemeIconButton(),
                    ],
                  ),
                ),
                _ProfileIdentitySection(
                  avatarUrl: _profile?['avatar_url'] as String? ??
                      ref.watch(profileImagesProvider).profileImagePath,
                  role: _role,
                  username: _username,
                  handle: _handle,
                  isLoading: _isLoadingProfile,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      const SizedBox(height: 20),
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
                                const SettingsPage(),
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

class _ProfileIdentitySection extends StatelessWidget {
  final String? avatarUrl;
  final String role;
  final String username;
  final String handle;
  final bool isLoading;

  const _ProfileIdentitySection({
    required this.avatarUrl,
    required this.role,
    required this.username,
    required this.handle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 108;
    const double avatarRadius = 36;
    final colorScheme = Theme.of(context).colorScheme;

    final String label = role == 'trainer'
        ? 'TRAINER'
        : role == 'nutritionist'
            ? 'NUTRITIONIST'
            : 'USER';
    final LinearGradient badgeGradient = role == 'trainer'
        ? AppColors.stepsGradient
        : role == 'nutritionist'
            ? const LinearGradient(
                colors: [AppColors.green, AppColors.cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.distanceGradient;

    Widget avatar = Material(
      color: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(avatarRadius),
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(avatarRadius),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.25),
            width: 2,
          ),
          color: colorScheme.surfaceContainerHighest,
          image: !isLoading &&
                  avatarUrl != null &&
                  avatarUrl!.isNotEmpty
              ? DecorationImage(
                  image: avatarUrl!.startsWith('http')
                      ? NetworkImage(avatarUrl!)
                      : FileImage(File(avatarUrl!)) as ImageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                )
              : (avatarUrl == null || avatarUrl!.isEmpty
                  ? Icon(Icons.person_rounded,
                      size: 44, color: colorScheme.onSurfaceVariant)
                  : null),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(child: avatar),
          const SizedBox(height: 20),
          Text(
            username,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            handle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: badgeGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
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
