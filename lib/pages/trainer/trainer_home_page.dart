import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
import '../../providers/profile_images_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/metrics_repository.dart';
import '../../services/leads_service.dart';
import '../../services/leads_models.dart' show Lead;
import '../../services/user_goals_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/streak_pill_v3.dart';
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

  String _trainerName = 'Trainer';
  int _notificationCount = 0;
  int _streakDays = 0;
  int _totalClients = 0;
  int _activeClients = 0;
  int _upcomingSessions = 0;
  int _todaySessions = 0;

  int _currentSteps = 0;
  int _goalSteps = 10000;
  int _currentCalories = 0;
  double _currentWater = 0;
  double _goalWater = 2.5;
  double _currentDistance = 0;
  double _bmi = 0;
  String _bmiStatus = '—';
  double? _heightCm;
  double? _weightKg;

  List<double> _stepsWeeklyData = [0, 0, 0, 0, 0, 0, 0];
  List<double> _caloriesWeeklyData = [0, 0, 0, 0, 0, 0, 0];
  List<double> _waterWeeklyData = [0, 0, 0, 0, 0, 0, 0];
  List<double> _distanceWeeklyData = [0, 0, 0, 0, 0, 0, 0];

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
    _loadData();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await StreakService.updateStreakOnLogin();
      if (mounted) setState(() => _streakDays = streak);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final profileRepo = ProfileRepository();
      final metricsRepo = MetricsRepository();
      final leadsService = LeadsService();
      final goalsService = UserGoalsService();

      final profile = await profileRepo.fetchMyProfile();
      final todayMetrics = await metricsRepo.getTodayMetrics();
      final weeklyMetrics = await metricsRepo.getWeeklyMetrics();
      final leads = await leadsService.getMyLeads();
      final stepsGoal = await goalsService.getStepsGoal();
      final waterGoal = await goalsService.getWaterGoal();

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final myLeads = currentUserId != null
          ? leads.where((l) => l.providerId == currentUserId && l.providerType == 'trainer').toList()
          : <Lead>[];
      final accepted = myLeads.where((l) => l.status == 'accepted').length;

      if (mounted) {
        setState(() {
          _trainerName = profile?['full_name'] as String? ?? profile?['username'] as String? ?? 'Trainer';
          _totalClients = accepted;
          _activeClients = accepted;
          _currentSteps = (todayMetrics?['steps'] as num?)?.toInt() ?? 0;
          _goalSteps = stepsGoal;
          _currentCalories = ((todayMetrics?['calories_burned'] as num?)?.toDouble() ?? 0.0).round();
          _currentWater = (todayMetrics?['water_intake_liters'] as num?)?.toDouble() ?? 0;
          _goalWater = waterGoal;
          _currentDistance = (todayMetrics?['distance_km'] as num?)?.toDouble() ?? 0;
          _stepsWeeklyData = weeklyMetrics.map((m) => ((m['steps'] as num?) ?? 0).toDouble()).toList();
          while (_stepsWeeklyData.length < 7) _stepsWeeklyData.insert(0, 0);
          _stepsWeeklyData = _stepsWeeklyData.take(7).toList();
          _caloriesWeeklyData = weeklyMetrics.map((m) => ((m['calories_burned'] as num?) ?? 0).toDouble()).toList();
          while (_caloriesWeeklyData.length < 7) _caloriesWeeklyData.insert(0, 0);
          _caloriesWeeklyData = _caloriesWeeklyData.take(7).toList();
          _waterWeeklyData = weeklyMetrics.map((m) => ((m['water_intake_liters'] as num?) ?? 0).toDouble()).toList();
          while (_waterWeeklyData.length < 7) _waterWeeklyData.insert(0, 0);
          _waterWeeklyData = _waterWeeklyData.take(7).toList();
          _distanceWeeklyData = weeklyMetrics.map((m) => ((m['distance_km'] as num?) ?? 0).toDouble()).toList();
          while (_distanceWeeklyData.length < 7) _distanceWeeklyData.insert(0, 0);
          _distanceWeeklyData = _distanceWeeklyData.take(7).toList();
          final bmiVal = profile?['bmi'] as num?;
          _bmi = bmiVal?.toDouble() ?? 0;
          _bmiStatus = _bmi > 0 ? (profile?['bmi_status'] as String? ?? '—') : '—';
          _heightCm = (profile?['height_cm'] as num?)?.toDouble();
          _weightKg = (profile?['weight_kg'] as num?)?.toDouble();
          if (_bmi <= 0 && _heightCm != null && _weightKg != null && _heightCm! > 0 && _weightKg! > 0) {
            _bmi = ProfileRepository.calculateBMI(_heightCm!, _weightKg!);
            _bmiStatus = ProfileRepository.getBMIStatus(_bmi);
          }
        });
      }
    } catch (_) {}
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

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await Future.wait([
      _loadData(),
      _loadNotificationsCount(),
      _loadStreak(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? Colors.white : cs.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.orange,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Hero Header (matches client)
              SliverToBoxAdapter(
                child: _animated(
                  HeroHeaderV3(
                    username: _trainerName,
                    notificationCount: _notificationCount,
                    coverImageUrl: ref.watch(profileImagesProvider).coverImagePath,
                    avatarUrl: ref.watch(profileImagesProvider).profileImagePath,
                    streakDays: 0,
                    onNotificationTap: () async {
                      await context.push('/notifications');
                      if (mounted) _loadNotificationsCount();
                    },
                  ),
                  0,
                ),
              ),
              // Streak pill - Transform.translate to overlap header (matches client)
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _animated(
                      _safeSection(context, StreakPillV3(streakDays: _streakDays)),
                      50,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // Steps Card
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _animated(
                      _safeSection(
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
                      100,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // Calories, Water, Distance Row
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
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
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // BMI Card
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _animated(
                      _safeSection(
                        context,
                        BmiCardV3(
                          bmi: _bmi,
                          status: _bmiStatus,
                          heightCm: _heightCm,
                          weightKg: _weightKg,
                        ),
                      ),
                      180,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // Quick Access
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(_safeSection(context, const QuickAccessV3()), 220),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Recent Activity
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Recent activity list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
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
