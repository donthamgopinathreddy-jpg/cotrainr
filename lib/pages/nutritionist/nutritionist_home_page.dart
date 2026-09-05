import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_images_provider.dart';
import '../../providers/health_tracking_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/unread_notifications_count_provider.dart';
import '../../providers/provider_practice_provider.dart';
import '../../providers/video_sessions_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/metrics_repository.dart';
import '../../services/user_goals_service.dart';
import '../../services/streak_service.dart';
import '../../services/metrics_sync_service.dart';
import '../../services/water_intake_service.dart';
import '../../utils/health_metric_display.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/home_community_event_card.dart';
import '../../widgets/home_v3/unified_metrics_tile_v3.dart';
import '../../providers/community_events_provider.dart';
import '../../widgets/home_v3/coaching_insight_builder.dart';
import '../../widgets/home_v3/metrics_source_labels.dart';
import '../../models/coaching_insight.dart';
import '../../models/daily_metrics_snapshot.dart';
import '../../repositories/meal_repository.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../../widgets/home_v3/quick_access_v3.dart';
import '../../widgets/home_v3/home_nav_hint_cards.dart';
import '../../widgets/home_v3/home_centers_preview.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/provider/provider_clients_summary.dart';
import '../bmi/bmi_details_screen.dart';
import '../insights/insights_detail_page.dart';

class NutritionistHomePage extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToMessagesTab;
  final VoidCallback? onNavigateToMealsTab;
  final VoidCallback? onNavigateToClientsTab;

  const NutritionistHomePage({
    super.key,
    this.onNavigateToMessagesTab,
    this.onNavigateToMealsTab,
    this.onNavigateToClientsTab,
  });

  @override
  ConsumerState<NutritionistHomePage> createState() => _NutritionistHomePageState();
}

class _NutritionistHomePageState extends ConsumerState<NutritionistHomePage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _nutritionistName = '';
  bool _nameLoading = true;
  bool _goalsReady = false;
  int _streakDays = 0;

  int _goalSteps = 10000;
  int _goalCalories = 2000;
  double _goalWater = 2.5;
  double _goalDistance = 5.0;
  int _currentSteps = 0;
  double _currentCalories = 0.0;
  double _currentWater = 0.0;
  double _currentDistance = 0.0;
  double _proteinToday = 0.0;
  int _proteinGoal = 150;
  double _bmi = 0;
  String _bmiStatus = '';
  double? _heightCm;
  double? _weightKg;
  String? _gender;
  int? _age;

  final List<double> _stepsWeeklyData = [];
  final List<double> _caloriesWeeklyData = [];
  final List<double> _waterWeeklyData = [];
  final List<double> _distanceWeeklyData = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadStreak();
    _loadGoals();
    _loadData();
    _loadCoachingData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(healthTrackingServiceProvider).initialize();
      try {
        await ref.read(metricsSyncServiceProvider).syncNow();
      } catch (_) {}
      if (mounted) await _loadData();
    });
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await StreakService.updateStreakOnLogin();
      if (mounted) setState(() => _streakDays = streak);
    } catch (_) {}
  }

  Future<void> _loadGoals() async {
    final goals = UserGoalsService();
    final steps = await goals.getStepsGoal();
    final water = await goals.getWaterGoal();
    final calories = await goals.getCaloriesGoal();
    final distance = await goals.getDistanceGoal();
    if (mounted) {
      setState(() {
        _goalSteps = steps;
        _goalWater = water;
        _goalCalories = calories;
        _goalDistance = distance;
        _goalsReady = true;
      });
    }
  }

  Future<void> _loadCoachingData() async {
    try {
      final mealRepo = MealRepository();
      final goals = await mealRepo.getNutritionGoals();
      final dayMeals = await mealRepo.getDayMeals(DateTime.now());
      if (!mounted) return;
      setState(() {
        _proteinToday = dayMeals.totalProtein;
        _proteinGoal = goals.goalProtein;
      });
    } catch (_) {}
  }

  List<CoachingInsight> _coachingInsights({
    required int steps,
    required int calories,
    required double water,
  }) {
    return CoachingInsightBuilder.build(
      steps: steps,
      stepsGoal: _goalSteps,
      calories: calories.toDouble(),
      caloriesGoal: _goalCalories.toDouble(),
      waterLiters: water,
      waterGoalLiters: _goalWater,
      proteinGrams: _proteinToday,
      proteinGoalGrams: _proteinGoal.toDouble(),
      stepsWeekly: _stepsWeeklyData,
      streakDays: _streakDays,
    );
  }

  Future<void> _loadData() async {
    try {
      final profileRepo = ProfileRepository();
      final metricsRepo = MetricsRepository();
      final profile = await profileRepo.fetchMyProfile();
      final todayMetrics = await metricsRepo.getTodayMetrics();
      final weeklyRows = await metricsRepo.getWeeklyMetrics();

      List<double> series(List<Map<String, dynamic>> rows, String key) {
        final list = rows.map((m) => ((m[key] as num?) ?? 0).toDouble()).toList();
        while (list.length < 7) {
          list.insert(0, 0);
        }
        if (list.length > 7) return list.sublist(list.length - 7);
        return list;
      }

      if (!mounted) return;
      setState(() {
        _nutritionistName = ((profile?['full_name'] as String?)?.trim().isNotEmpty == true)
            ? (profile!['full_name'] as String).trim()
            : ((profile?['username'] as String?)?.trim() ?? '');
        _nameLoading = false;
        _currentSteps = (todayMetrics?['steps'] as num?)?.toInt() ?? 0;
        _currentCalories =
            (todayMetrics?['calories_burned'] as num?)?.toDouble() ?? 0;
        _currentWater =
            (todayMetrics?['water_intake_liters'] as num?)?.toDouble() ?? 0;
        _currentDistance =
            (todayMetrics?['distance_km'] as num?)?.toDouble() ?? 0;
        _stepsWeeklyData
          ..clear()
          ..addAll(series(weeklyRows, 'steps'));
        _caloriesWeeklyData
          ..clear()
          ..addAll(series(weeklyRows, 'calories_burned'));
        _waterWeeklyData
          ..clear()
          ..addAll(series(weeklyRows, 'water_intake_liters'));
        _distanceWeeklyData
          ..clear()
          ..addAll(series(weeklyRows, 'distance_km'));
        _bmi = (profile?['bmi'] as num?)?.toDouble() ?? 0;
        _bmiStatus = _bmi > 0 ? (profile?['bmi_status'] as String? ?? '') : '';
        _heightCm = (profile?['height_cm'] as num?)?.toDouble();
        _weightKg = (profile?['weight_kg'] as num?)?.toDouble();
        _gender = profile?['gender'] as String?;
        final dob = profile?['date_of_birth'] as String?;
        if (dob != null && dob.isNotEmpty) {
          try {
            final d = DateTime.parse(dob);
            final now = DateTime.now();
            var age = now.year - d.year;
            if (now.month < d.month ||
                (now.month == d.month && now.day < d.day)) {
              age--;
            }
            _age = age;
          } catch (_) {}
        }
        if (_heightCm != null) {
          ref.read(healthTrackingServiceProvider).setUserHeightCm(_heightCm);
        }
        if (_bmi <= 0 &&
            _heightCm != null &&
            _weightKg != null &&
            _heightCm! > 0 &&
            _weightKg! > 0) {
          _bmi = ProfileRepository.calculateBMI(_heightCm!, _weightKg!);
          _bmiStatus = ProfileRepository.getBMIStatus(_bmi);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _nameLoading = false);
    }
  }

  Future<void> _refreshNotificationBadge() async {
    ref.invalidate(unreadNotificationsCountProvider);
  }

  void _openClientsTab({int tab = 0}) {
    ref.read(providerClientsTabIntentProvider.notifier).state = tab;
    widget.onNavigateToClientsTab?.call();
  }

  void _openClientNotes() {
    HapticFeedback.lightImpact();
    context.push('/trainer/notes');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Widget _safeSection(BuildContext context, Widget child) {
    try {
      return child;
    } catch (_) {
      return const SizedBox.shrink();
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
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(metricsSyncServiceProvider).syncNow();
    await Future.wait([
      _loadData(),
      _refreshNotificationBadge(),
      _loadStreak(),
      _loadGoals(),
      _loadCoachingData(),
    ]);
    invalidateProviderHomeCounts(ref);
    ref.invalidate(videoSessionsListProvider);
    ref.invalidate(homeCommunityEventProvider);
    ref.read(dailyMetricsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;
    final liveMetrics = ref.watch(dailyMetricsProvider).valueOrNull;
    final practice = ref.watch(providerPracticeSummaryProvider('nutritionist'));
    final summary = practice.valueOrNull ?? ProviderPracticeSummary.empty;
    final nextSession = nextSessionPreviewFromSessions(
      ref.watch(videoSessionsListProvider).valueOrNull,
    );
    final stepsMetric = resolveHomeSteps(
      cached: _currentSteps,
      live: liveMetrics,
    );
    final caloriesMetric = resolveHomeCalories(
      cached: _currentCalories,
      live: liveMetrics,
    );
    final distanceMetric = resolveHomeDistance(
      cached: _currentDistance,
      live: liveMetrics,
    );
    final currentSteps = stepsMetric.value.round();
    final currentCalories = caloriesMetric.value.round();
    final currentDistance = distanceMetric.value;
    final caloriesSourceNote = MetricsSourceLabels.caloriesNote(liveMetrics);
    final distanceSourceNote = MetricsSourceLabels.distanceNote(liveMetrics);
    final coachingInsights = _goalsReady
        ? _coachingInsights(
            steps: currentSteps,
            calories: currentCalories,
            water: _currentWater,
          )
        : const <CoachingInsight>[];

    ref.listen(unreadNotificationsCountProvider, (prev, next) {
      final previous = prev?.maybeWhen(data: (c) => c, orElse: () => 0) ?? 0;
      final current = next.maybeWhen(data: (c) => c, orElse: () => 0);
      if (current > previous) invalidateProviderHomeCounts(ref);
    });

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF3ED598),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _animated(
                  HeroHeaderV3(
                    username: _nutritionistName,
                    usernameLoading: _nameLoading,
                    notificationCount: ref.watch(unreadNotificationsCountProvider).maybeWhen(
                      data: (c) => c,
                      orElse: () => 0,
                    ),
                    coverImageUrl: ref.watch(profileImagesProvider).coverImagePath,
                    avatarUrl: ref.watch(profileImagesProvider).profileImagePath,
                    streakDays: _streakDays,
                    coachingInsights: coachingInsights,
                    onNotificationTap: () async {
                      await context.push('/notifications');
                      if (mounted) _refreshNotificationBadge();
                    },
                  ),
                  0,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _animated(
                    _safeSection(context, const HomeCommunityEventCard()),
                    40,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _animated(
                    _safeSection(
                      context,
                      UnifiedMetricsTileV3(
                        goalsLoading: !_goalsReady,
                        metrics: [
                          UnifiedMetricViewModel(
                            label: 'STEPS',
                            icon: Icons.directions_walk_outlined,
                            selectedIcon: Icons.directions_walk,
                            ringGradient: AppColors.stepsGradient,
                            barColor: AppColors.orange,
                            progress: stepsMetric.available
                                ? safeMetricProgress(
                                    currentSteps.toDouble(),
                                    _goalSteps.toDouble(),
                                  )
                                : 0.0,
                            mainValue: stepsMetric.available
                                ? stepsMetric.displayInt
                                : '—',
                            subValue:
                                'of ${_goalSteps >= 1000 ? '${(_goalSteps / 1000).toStringAsFixed(1)}k' : '$_goalSteps'} steps',
                            weekly: List<double>.from(_stepsWeeklyData),
                            todayValue: currentSteps.toDouble(),
                            goalValue: _goalSteps.toDouble(),
                          ),
                          UnifiedMetricViewModel(
                            label: 'ACTIVE CALORIES',
                            icon: Icons.local_fire_department_outlined,
                            selectedIcon: Icons.local_fire_department,
                            ringGradient: AppColors.caloriesGradient,
                            barColor: const Color(0xFFFF6B6B),
                            progress: caloriesMetric.available
                                ? safeMetricProgress(
                                    currentCalories.toDouble(),
                                    _goalCalories.toDouble(),
                                  )
                                : 0.0,
                            mainValue: caloriesMetric.available
                                ? '$currentCalories'
                                : '—',
                            subValue: 'kcal · goal $_goalCalories',
                            sourceNote: caloriesSourceNote,
                            weekly: List<double>.from(_caloriesWeeklyData),
                            todayValue: currentCalories.toDouble(),
                            goalValue: _goalCalories.toDouble(),
                          ),
                          UnifiedMetricViewModel(
                            label: 'WATER',
                            icon: Icons.water_drop_outlined,
                            selectedIcon: Icons.water_drop,
                            ringGradient: AppColors.waterGradient,
                            barColor: AppColors.cyan,
                            progress: safeMetricProgress(
                              _currentWater,
                              _goalWater,
                            ),
                            mainValue: _currentWater.toStringAsFixed(1),
                            subValue: 'of ${_goalWater.toStringAsFixed(1)} L',
                            weekly: List<double>.from(_waterWeeklyData),
                            todayValue: _currentWater,
                            goalValue: _goalWater,
                          ),
                          UnifiedMetricViewModel(
                            label: 'DISTANCE',
                            icon: Icons.location_on_outlined,
                            selectedIcon: Icons.location_on,
                            ringGradient: AppColors.distanceGradient,
                            barColor: AppColors.purple,
                            progress: distanceMetric.available
                                ? safeMetricProgress(
                                    currentDistance,
                                    _goalDistance,
                                  )
                                : 0.0,
                            mainValue: distanceMetric.available
                                ? distanceMetric.displayOneDecimal
                                : '—',
                            subValue:
                                'km · goal ${_goalDistance.toStringAsFixed(1)}',
                            sourceNote: distanceSourceNote,
                            weekly: List<double>.from(_distanceWeeklyData),
                            todayValue: currentDistance,
                            goalValue: _goalDistance,
                          ),
                        ],
                        onMetricTap: (i) => _openInsight(context, i),
                        onAddWater: () async {
                          const add = 0.25;
                          final old = _currentWater;
                          setState(() => _currentWater = _currentWater + add);
                          final newWater =
                              await WaterIntakeService.instance.addWater(add);
                          if (!mounted) return;
                          if (newWater == null) {
                            setState(() => _currentWater = old);
                            return;
                          }
                          setState(() => _currentWater = newWater);
                          ref
                              .read(questProgressSyncServiceProvider)
                              .onWaterUpdated(newWater);
                        },
                      ),
                    ),
                    80,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(
                    _safeSection(
                      context,
                      InkWell(
                        onTap: () => context.push(
                          '/bmi',
                          extra: BmiDetailsArgs(
                            bmi: _bmi,
                            bmiStatus: _bmiStatus,
                            heightCm: _heightCm,
                            weightKg: _weightKg,
                            gender: _gender,
                            age: _age,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(28),
                        child: BmiCardV3(
                          bmi: _bmi,
                          status: _bmiStatus,
                          heightCm: _heightCm,
                          weightKg: _weightKg,
                        ),
                      ),
                    ),
                    140,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(
                    _safeSection(
                      context,
                      ProviderClientsSummary(
                        activeCount: summary.activeCount,
                        requestCount: summary.requestCount,
                        clients: summary.clients,
                        loading: practice.isLoading && practice.valueOrNull == null,
                        nextSession: nextSession,
                        onOpenClients: () => _openClientsTab(tab: 0),
                        onOpenRequests: () => _openClientsTab(tab: 1),
                        onOpenNotes: _openClientNotes,
                        onOpenNextSession: nextSession == null
                            ? null
                            : () => context.push(
                                  '/video/session/${nextSession.sessionId}',
                                ),
                        onOpenClient: (c) {
                          if (c.id.isEmpty) return;
                          context.push('/nutritionist/clients/${c.id}');
                        },
                      ),
                    ),
                    180,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(_safeSection(context, const QuickAccessV3()), 220),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(
                    _safeSection(context, const HomeCentersPreview()),
                    260,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(
                    _safeSection(
                      context,
                      HomeNavHintCards(
                        onOpenMessagesTab: widget.onNavigateToMessagesTab,
                        onOpenMealsTab: widget.onNavigateToMealsTab,
                      ),
                    ),
                    300,
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

  void _openInsight(BuildContext context, int i) {
    final liveMetrics = ref.read(dailyMetricsProvider).valueOrNull;
    switch (i) {
      case 0:
        context.push(
          '/insights/steps',
          extra: InsightArgs(MetricType.steps, List<double>.from(_stepsWeeklyData),
              goal: _goalSteps.toDouble()),
        );
      case 1:
        context.push(
          '/insights/calories',
          extra: InsightArgs(MetricType.calories, List<double>.from(_caloriesWeeklyData),
              goal: _goalCalories.toDouble(),
              sourceNote: liveMetrics?.caloriesSource.insightsNote),
        );
      case 2:
        context.push(
          '/insights/water',
          extra: InsightArgs(MetricType.water, List<double>.from(_waterWeeklyData),
              goal: _goalWater),
        );
      case 3:
        context.push(
          '/insights/distance',
          extra: InsightArgs(MetricType.distance, List<double>.from(_distanceWeeklyData),
              goal: _goalDistance,
              sourceNote: liveMetrics?.distanceSource.insightsNote),
        );
    }
  }
}
