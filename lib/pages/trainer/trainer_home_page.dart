import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_images_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/steps_card_v3.dart';
import '../../widgets/home_v3/macro_row_v3.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../../widgets/home_v3/quick_access_v3.dart';
import '../insights/insights_detail_page.dart';

class TrainerHomePage extends ConsumerStatefulWidget {
  const TrainerHomePage({super.key});

  @override
  ConsumerState<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends ConsumerState<TrainerHomePage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Mock data - in real app, fetch from Supabase
  final String _trainerName = 'Trainer Name';
  int _notificationCount = 0;
  final int _streakDays = 0; // Trainers don't have streaks, but keeping for consistency
  final int _totalClients = 12;
  final int _activeClients = 8;
  final int _upcomingSessions = 5;
  final int _todaySessions = 2;
  
  // Health metrics data
  final int _currentSteps = 8234;
  final int _goalSteps = 10000;
  final int _currentCalories = 1856;
  final double _currentWater = 1.5;
  final double _goalWater = 2.5;
  final double _currentDistance = 4.6;
  final double _bmi = 22.4;
  final String _bmiStatus = 'Normal';

  final List<double> _stepsWeeklyData = [6.2, 7.1, 8.3, 7.8, 8.5, 8.2, 8.0];
  final List<double> _caloriesWeeklyData = [1.8, 2.0, 1.9, 2.1, 1.7, 1.9, 1.8];
  final List<double> _waterWeeklyData = [1.2, 1.5, 1.8, 1.6, 1.4, 1.7, 1.5];
  final List<double> _distanceWeeklyData = [3.8, 4.2, 4.0, 4.5, 4.6, 4.1, 4.4];

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
    _loadNotificationsCount();
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final notificationsRepo = NotificationsRepository();
      final profileRepo = ProfileRepository();
      final prefs = await profileRepo.fetchNotificationPreferences();
      final count = await notificationsRepo.fetchUnreadCount(
        community: prefs['community'] ?? true,
        reminders: prefs['reminders'] ?? true,
        achievements: prefs['achievements'] ?? true,
      );
      if (mounted) setState(() => _notificationCount = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Widget _safeSection(BuildContext context, Widget child) {
    final cs = Theme.of(context).colorScheme;
    try {
      return child;
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: DesignTokens.cardShadowOf(context),
        ),
        child: Text(
          'Section failed to render',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
  }

  Widget _animated(Widget child, int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Transform.scale(
              scale: 0.99 + 0.01 * value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? Colors.grey.shade200 : DesignTokens.backgroundOf(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero Header with Cover Image, Profile Image, and Notification Bell
            SliverToBoxAdapter(
              child: HeroHeaderV3(
                username: _trainerName,
                notificationCount: _notificationCount,
                coverImageUrl: ref.watch(profileImagesProvider).coverImagePath,
                avatarUrl: ref.watch(profileImagesProvider).profileImagePath,
                streakDays: _streakDays,
                onNotificationTap: () async {
                  await context.push('/notifications');
                  if (mounted) _loadNotificationsCount();
                },
              ),
            ),
            
            // Spacing for floating avatar
            const SliverToBoxAdapter(child: SizedBox(height: 44)),

            // Steps Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: _safeSection(
                      context,
                      StepsCardV3(
                        steps: _currentSteps,
                        goal: _goalSteps,
                        sparkline: _stepsWeeklyData,
                        heroTag: 'tile_steps_trainer',
                        onTap: () => context.push(
                          '/insights/steps',
                          extra: InsightArgs(
                            MetricType.steps,
                            _stepsWeeklyData,
                            goal: _goalSteps.toDouble(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  100,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Calories, Water, Distance Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(
                  _safeSection(
                    context,
                    MacroRowV3(
                      calories: _currentCalories,
                      water: _currentWater,
                      waterGoal: _goalWater,
                      caloriesSpark: _caloriesWeeklyData,
                      distanceKm: _currentDistance,
                      caloriesHeroTag: 'tile_calories_trainer',
                      waterHeroTag: 'tile_water_trainer',
                      distanceHeroTag: 'tile_distance_trainer',
                      onCaloriesTap: () => context.push(
                        '/insights/calories',
                        extra: InsightArgs(
                          MetricType.calories,
                          _caloriesWeeklyData,
                        ),
                      ),
                      onWaterTap: () => context.push(
                        '/insights/water',
                        extra: InsightArgs(
                          MetricType.water,
                          _waterWeeklyData,
                          goal: _goalWater,
                        ),
                      ),
                      onDistanceTap: () => context.push(
                        '/insights/distance',
                        extra: InsightArgs(
                          MetricType.distance,
                          _distanceWeeklyData,
                        ),
                      ),
                    ),
                  ),
                  140,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // BMI Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(
                  _safeSection(context, BmiCardV3(bmi: _bmi, status: _bmiStatus)),
                  180,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Quick Access
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(_safeSection(context, const QuickAccessV3()), 220),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Stats Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Clients',
                        _totalClients.toString(),
                        Icons.people,
                        DesignTokens.accentOrange,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),
                    Expanded(
                      child: _buildStatCard(
                        'Active',
                        _activeClients.toString(),
                        Icons.check_circle,
                        DesignTokens.accentGreen,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing20),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Upcoming',
                        _upcomingSessions.toString(),
                        Icons.calendar_today,
                        DesignTokens.accentBlue,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),
                    Expanded(
                      child: _buildStatCard(
                        'Today',
                        _todaySessions.toString(),
                        Icons.today,
                        DesignTokens.accentAmber,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

            // Recent Activity
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: DesignTokens.fontSizeH3,
                    fontWeight: DesignTokens.fontWeightBold,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing12),
            ),

            // Recent activity list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildActivityItem(
                        'New client request from John Doe',
                        '2 hours ago',
                        Icons.person_add,
                        textPrimary,
                        textSecondary,
                      ),
                      const Divider(height: 24),
                      _buildActivityItem(
                        'Session completed with Jane Smith',
                        '5 hours ago',
                        Icons.check_circle,
                        textPrimary,
                        textSecondary,
                      ),
                      const Divider(height: 24),
                      _buildActivityItem(
                        'Upcoming session in 30 minutes',
                        'Just now',
                        Icons.access_time,
                        DesignTokens.accentOrange,
                        textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spacing32)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: DesignTokens.spacing12),
          Text(
            value,
            style: TextStyle(
              color: DesignTokens.textPrimaryOf(context),
              fontSize: DesignTokens.fontSizeH1,
              fontWeight: DesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: DesignTokens.fontSizeBodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color titleColor,
    Color timeColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignTokens.spacing8),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          ),
          child: Icon(icon, size: 20, color: titleColor),
        ),
        const SizedBox(width: DesignTokens.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: DesignTokens.fontWeightMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: timeColor,
                  fontSize: DesignTokens.fontSizeBodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
