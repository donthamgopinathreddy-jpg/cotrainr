import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/metrics_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/nutrition_goal_calculator.dart';
import '../../services/nutrition_planner_local_storage.dart';
import '../../services/streak_service.dart';
import '../../services/user_goals_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/app_colors.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/profile/appearance_toggle.dart';
import '../../providers/profile_images_provider.dart';
import '../trainer/become_trainer_page.dart';
import '../trainer/verification_submission_page.dart';
import '../refer/refer_friend_page.dart';
import 'goals_preferences_page.dart';
import 'settings/health_devices_page.dart';
import 'settings_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  final ProfileRepository _profileRepo = ProfileRepository();
  final MetricsRepository _metricsRepo = MetricsRepository();
  final UserGoalsService _goalsService = UserGoalsService();
  final NutritionPlannerLocalStorage _plannerStorage =
      NutritionPlannerLocalStorage();

  String _username = 'Loading...';
  String _handle = '@loading';
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;

  double _bmi = 0;
  String _bmiStatus = '';
  double? _weightKg;
  double? _targetWeightKg;
  String _goalTypeLabel = '—';
  int _calorieTarget = 0;
  int _streakDays = 0;
  int _weeklySteps = 0;
  double _waterProgress = 0;
  double? _nutritionProgress;

  late AnimationController _headerCtrl;
  late Animation<double> _headerAnim;

  String? get _verificationStatus {
    if (_role == 'trainer' || _role == 'nutritionist') {
      final verified = _profile?['verified'] as bool?;
      if (verified == true) return 'verified';
      return 'pending';
    }
    return null;
  }

  bool get _isPending => _verificationStatus == 'pending';

  bool get _needsVerification {
    if (_role == 'trainer' || _role == 'nutritionist') {
      return _verificationStatus != 'verified';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic);
    _headerCtrl.forward();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfile(), _loadHubData()]);
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _profile = profile;
          _username = profile['full_name'] as String? ??
              profile['username'] as String? ??
              'User';
          _handle = '@${profile['username'] ?? ''}';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  Future<void> _loadHubData() async {
    try {
      final profile = await _profileRepo.fetchMyProfile();
      final planner = await _plannerStorage.loadSavedState();
      final calories = planner?.goalCalories ??
          await _goalsService.getCaloriesGoal();
      final waterGoal = await _goalsService.getWaterGoal();
      final streak = await StreakService.updateStreakOnLogin();
      final weekly = await _metricsRepo.getWeeklyMetrics();

      var stepsTotal = 0;
      var waterToday = 0.0;
      final today = DateTime.now().toIso8601String().split('T')[0];
      for (final m in weekly) {
        stepsTotal += (m['steps'] as num?)?.toInt() ?? 0;
        final d = m['date'] as String?;
        if (d == today) {
          waterToday = (m['water_intake_liters'] as num?)?.toDouble() ?? 0;
        }
      }

      final heightCm = (profile?['height_cm'] as num?)?.toDouble() ?? 0;
      final weightKg = (profile?['weight_kg'] as num?)?.toDouble();
      double bmi = 0;
      String status = '';
      if (heightCm > 0 && weightKg != null && weightKg > 0) {
        bmi = ProfileRepository.calculateBMI(heightCm, weightKg);
        status = ProfileRepository.getBMIStatus(bmi);
      }

      double? nutritionPct;
      if (planner != null && planner.goalCalories > 0) {
        nutritionPct = 0;
      }

      if (mounted) {
        setState(() {
          _weightKg = weightKg ?? planner?.currentWeightKg;
          _targetWeightKg = planner?.targetWeightKg;
          _goalTypeLabel = planner != null
              ? (NutritionGoalCalculator.goalTypeLabels[planner.goalType] ??
                  planner.goalType)
              : 'Not set';
          _calorieTarget = calories;
          _bmi = bmi;
          _bmiStatus = status;
          _streakDays = streak;
          _weeklySteps = stepsTotal;
          _waterProgress =
              waterGoal > 0 ? (waterToday / waterGoal).clamp(0.0, 1.0) : 0;
          _nutritionProgress = nutritionPct;
        });
      }
    } catch (_) {}
  }

  String get _role => _profile?['role'] as String? ?? 'client';

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _headerAnim,
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
                      children: const [AppearanceThemeIconButton()],
                    ),
                  ),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(_headerAnim),
                    child: _ProfileIdentitySection(
                      avatarUrl: _profile?['avatar_url'] as String? ??
                          ref.watch(profileImagesProvider).profileImagePath,
                      role: _role,
                      username: _username,
                      handle: _handle,
                      isLoading: _isLoadingProfile,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AccountHubTheme.horizontalMargin),
                    child: HubSectionCard(
                      title: 'My Goals',
                      animationDelayMs: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            children: [
                              HubCompactStat(
                                label: 'Goal',
                                value: _goalTypeLabel,
                              ),
                              HubCompactStat(
                                label: 'Weight',
                                value: _weightKg != null
                                    ? _weightKg!.toStringAsFixed(1)
                                    : '—',
                                unit: 'kg',
                              ),
                              HubCompactStat(
                                label: 'Target',
                                value: _targetWeightKg != null
                                    ? _targetWeightKg!.toStringAsFixed(1)
                                    : '—',
                                unit: 'kg',
                              ),
                              HubCompactStat(
                                label: 'BMI',
                                value: _bmi > 0
                                    ? '${_bmi.toStringAsFixed(1)} ($_bmiStatus)'
                                    : '—',
                              ),
                              HubCompactStat(
                                label: 'Calories',
                                value: _calorieTarget > 0
                                    ? '$_calorieTarget'
                                    : '—',
                                unit: 'kcal',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          HubCtaButton(
                            label: 'Manage Goals',
                            color: AccountHubTheme.goalsGreen,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                PageTransitions.slideRoute(
                                  const GoalsPreferencesPage(),
                                ),
                              ).then((_) => _loadHubData());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AccountHubTheme.horizontalMargin),
                    child: HubSectionCard(
                      title: 'Progress Snapshot',
                      animationDelayMs: 80,
                      child: Column(
                        children: [
                          _ProgressLine(
                            label: 'Streak',
                            value: '$_streakDays days',
                            progress: (_streakDays / 7).clamp(0.0, 1.0),
                            color: AccountHubTheme.subscriptionAmber,
                          ),
                          const SizedBox(height: 10),
                          _ProgressLine(
                            label: 'Weekly steps',
                            value: '$_weeklySteps',
                            progress: (_weeklySteps / 70000).clamp(0.0, 1.0),
                            color: AccountHubTheme.messagesBlue,
                          ),
                          const SizedBox(height: 10),
                          _ProgressLine(
                            label: 'Water today',
                            value: '${(_waterProgress * 100).round()}%',
                            progress: _waterProgress,
                            color: const Color(0xFF2FC8FF),
                          ),
                          if (_nutritionProgress != null) ...[
                            const SizedBox(height: 10),
                            _ProgressLine(
                              label: 'Nutrition goals',
                              value: 'Set in planner',
                              progress: 0,
                              color: AccountHubTheme.goalsGreen,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if ((_role == 'trainer' || _role == 'nutritionist') &&
                      _needsVerification) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AccountHubTheme.horizontalMargin),
                      child: _VerificationCard(
                        isPending: _isPending,
                        role: _role,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageTransitions.slideRoute(
                              const VerificationSubmissionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AccountHubTheme.horizontalMargin),
                    child: Column(
                      children: [
                        if (_role == 'client')
                          _ProfileActionRow(
                            label: 'Subscription',
                            icon: Icons.star_rounded,
                            iconColor: AccountHubTheme.subscriptionAmber,
                            delayMs: 120,
                            trailing: const ComingSoonBadge(),
                            onTap: () => showHubSnackBar(
                              context,
                              'Subscription management coming soon',
                            ),
                          ),
                        _ProfileActionRow(
                          label: 'Goals & Preferences',
                          icon: Icons.flag_outlined,
                          iconColor: AccountHubTheme.goalsGreen,
                          delayMs: 160,
                          onTap: () => Navigator.push(
                            context,
                            PageTransitions.slideRoute(
                              const GoalsPreferencesPage(),
                            ),
                          ),
                        ),
                        _ProfileActionRow(
                          label: Platform.isIOS ? 'Apple Health' : 'Health Connect',
                          icon: Icons.favorite_outline_rounded,
                          iconColor: AccountHubTheme.goalsGreen,
                          delayMs: 200,
                          onTap: () => Navigator.push(
                            context,
                            PageTransitions.slideRoute(
                              const HealthDevicesPage(),
                            ),
                          ),
                        ),
                        _ProfileActionRow(
                          label: 'Settings',
                          icon: Icons.settings_rounded,
                          delayMs: 240,
                          onTap: () => Navigator.push(
                            context,
                            PageTransitions.slideRoute(const SettingsPage()),
                          ),
                        ),
                        _ProfileActionRow(
                          label: 'Refer a Friend',
                          icon: Icons.person_add_rounded,
                          delayMs: 280,
                          onTap: () => Navigator.push(
                            context,
                            PageTransitions.slideRoute(
                              const ReferFriendPage(),
                            ),
                          ),
                        ),
                        if (_role == 'client')
                          _ProfileActionRow(
                            label: 'Become a Trainer',
                            icon: Icons.school_rounded,
                            delayMs: 320,
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRoute(
                                const BecomeTrainerPage(),
                              ),
                            ),
                          ),
                        if (_role == 'trainer' || _role == 'nutritionist')
                          _ProfileActionRow(
                            label: 'My Clients',
                            icon: Icons.people_rounded,
                            delayMs: 320,
                            onTap: () => context.push('/my-clients'),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 90 + MediaQuery.paddingOf(context).bottom,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _ProgressLine({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: AccountHubTheme.rowSubtitle(context)),
                ),
                Text(value, style: AccountHubTheme.rowTitle(context).copyWith(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: t,
                minHeight: 6,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final int delayMs;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ProfileActionRow({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.delayMs,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableCard(
        onTap: onTap,
        borderRadius: AccountHubTheme.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AccountHubTheme.cardBg(context),
            borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
            boxShadow: AccountHubTheme.cardShadow(context),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 260 + delayMs),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor ??
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: AccountHubTheme.rowTitle(context)),
                ),
                if (trailing != null) trailing!,
                if (trailing == null)
                  Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
              ],
            ),
          ),
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
    const avatarSize = 96.0;
    const avatarRadius = 32.0;
    final colorScheme = Theme.of(context).colorScheme;

    final label = role == 'trainer'
        ? 'TRAINER'
        : role == 'nutritionist'
            ? 'NUTRITIONIST'
            : 'USER';
    final badgeGradient = role == 'trainer'
        ? AppColors.stepsGradient
        : role == 'nutritionist'
            ? const LinearGradient(
                colors: [AppColors.green, AppColors.cyan],
              )
            : AppColors.distanceGradient;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Column(
        children: [
          Material(
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(avatarRadius),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(avatarRadius),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 2,
                ),
                color: colorScheme.surfaceContainerHighest,
                image: !isLoading && avatarUrl != null && avatarUrl!.isNotEmpty
                    ? DecorationImage(
                        image: avatarUrl!.startsWith('http')
                            ? NetworkImage(avatarUrl!)
                            : FileImage(File(avatarUrl!)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.primary,
                      ),
                    )
                  : (avatarUrl == null || avatarUrl!.isEmpty
                      ? Icon(Icons.person_rounded,
                          size: 40, color: colorScheme.onSurfaceVariant)
                      : null),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            username,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(handle, style: AccountHubTheme.rowSubtitle(context)),
          const SizedBox(height: 12),
          PulsingRoleBadge(label: label, gradient: badgeGradient),
        ],
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
    final roleLabel = role == 'nutritionist' ? 'Nutritionist' : 'Trainer';
    return PressableCard(
      onTap: onTap,
      borderRadius: AccountHubTheme.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AccountHubTheme.cardBg(context),
          borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
          border: Border.all(
            color: AccountHubTheme.subscriptionAmber.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPending ? Icons.hourglass_top_rounded : Icons.verified_user_outlined,
              color: AccountHubTheme.subscriptionAmber,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPending
                        ? 'Verification Pending'
                        : 'Verify $roleLabel Account',
                    style: AccountHubTheme.rowTitle(context),
                  ),
                  Text(
                    isPending
                        ? 'Documents submitted — review within 24 hours.'
                        : 'Submit documents to unlock provider features.',
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
