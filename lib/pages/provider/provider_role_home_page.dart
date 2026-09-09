import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/coaching_insight.dart';
import '../../models/daily_metrics_snapshot.dart';
import '../../providers/community_events_provider.dart';
import '../../providers/health_tracking_provider.dart';
import '../../providers/profile_images_provider.dart';
import '../../providers/provider_practice_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/unread_notifications_count_provider.dart';
import '../../providers/video_sessions_provider.dart';
import '../../repositories/meal_repository.dart';
import '../../repositories/metrics_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/provider_reviews_repository.dart';
import '../../services/metrics_sync_service.dart';
import '../../services/streak_service.dart';
import '../../services/user_goals_service.dart';
import '../../services/water_intake_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/health_metric_display.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../../widgets/home_v3/coaching_insight_builder.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/home_centers_preview.dart';
import '../../widgets/home_v3/home_community_event_card.dart';
import '../../widgets/home_v3/home_nav_hint_cards.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/home_v3/metrics_source_labels.dart';
import '../../widgets/home_v3/quick_access_v3.dart';
import '../../widgets/home_v3/unified_metrics_tile_v3.dart';
import '../../widgets/provider/provider_clients_summary.dart';
import '../../widgets/provider/provider_reviews_home_section.dart';
import '../bmi/bmi_details_screen.dart';
import '../insights/insights_detail_page.dart';

/// Shared V1 Home for Trainer and Nutritionist roles.
///
/// Locked order:
/// Cover -> Events -> My Fitness (collapsed) -> Professional overview
/// -> Recent clients -> Reviews & Ratings -> Explore -> Messages/Meals hints.
///
/// Personal metrics and BMI remain available for providers in V1, but are
/// intentionally collapsed so professional work has higher visual priority.
class ProviderRoleHomePage extends ConsumerStatefulWidget {
  const ProviderRoleHomePage({
    super.key,
    required this.providerType,
    required this.clientPathPrefix,
    this.onNavigateToMessagesTab,
    this.onNavigateToMealsTab,
    this.onNavigateToClientsTab,
  });

  final String providerType;
  final String clientPathPrefix;
  final VoidCallback? onNavigateToMessagesTab;
  final VoidCallback? onNavigateToMealsTab;
  final VoidCallback? onNavigateToClientsTab;

  @override
  ConsumerState<ProviderRoleHomePage> createState() =>
      _ProviderRoleHomePageState();
}

class _ProviderRoleHomePageState extends ConsumerState<ProviderRoleHomePage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ProviderReviewsRepository _reviewsRepository =
      ProviderReviewsRepository();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  String _providerName = '';
  bool _nameLoading = true;
  bool _goalsReady = false;
  bool _fitnessExpanded = false;
  bool _reviewsLoading = true;
  bool _reviewsFailed = false;
  int _streakDays = 0;

  int _goalSteps = 10000;
  int _goalCalories = 2000;
  double _goalWater = 2.5;
  double _goalDistance = 5.0;

  int _currentSteps = 0;
  double _currentCalories = 0;
  double _currentWater = 0;
  double _currentDistance = 0;
  double _proteinToday = 0;
  int _proteinGoal = 150;

  double _bmi = 0;
  String _bmiStatus = '';
  double? _heightCm;
  double? _weightKg;
  String? _gender;
  int? _age;

  List<ProviderReview> _reviews = const [];

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
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _loadStreak();
    _loadGoals();
    _loadData();
    _loadCoachingData();
    _loadReviews();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(healthTrackingServiceProvider).initialize();
      try {
        await ref.read(metricsSyncServiceProvider).syncNow();
      } catch (_) {
        // Health/device sync must never block provider Home.
      }
      if (mounted) await _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await StreakService.updateStreakOnLogin();
      if (mounted) setState(() => _streakDays = streak);
    } catch (_) {}
  }

  Future<void> _loadGoals() async {
    try {
      final goals = UserGoalsService();
      final values = await Future.wait<dynamic>([
        goals.getStepsGoal(),
        goals.getWaterGoal(),
        goals.getCaloriesGoal(),
        goals.getDistanceGoal(),
      ]);
      if (!mounted) return;
      setState(() {
        _goalSteps = values[0] as int;
        _goalWater = (values[1] as num).toDouble();
        _goalCalories = values[2] as int;
        _goalDistance = (values[3] as num).toDouble();
        _goalsReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _goalsReady = true);
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

  Future<void> _loadReviews() async {
    final providerId = Supabase.instance.client.auth.currentUser?.id;
    if (providerId == null) {
      if (!mounted) return;
      setState(() {
        _reviews = const [];
        _reviewsLoading = false;
        _reviewsFailed = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _reviewsLoading = true;
        _reviewsFailed = false;
      });
    }

    try {
      final reviews = await _reviewsRepository.listForProvider(providerId);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsFailed = true;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final profileRepo = ProfileRepository();
      final metricsRepo = MetricsRepository();

      final profile = await profileRepo.fetchMyProfile();
      final todayMetrics = await metricsRepo.getTodayMetrics();
      final weeklyRows = await metricsRepo.getWeeklyMetrics();

      List<double> series(String key) {
        final list = weeklyRows
            .map((row) => ((row[key] as num?) ?? 0).toDouble())
            .toList();
        while (list.length < 7) {
          list.insert(0, 0);
        }
        return list.length > 7 ? list.sublist(list.length - 7) : list;
      }

      if (!mounted) return;
      setState(() {
        final fullName = (profile?['full_name'] as String?)?.trim() ?? '';
        final username = (profile?['username'] as String?)?.trim() ?? '';
        _providerName = fullName.isNotEmpty ? fullName : username;
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
          ..addAll(series('steps'));
        _caloriesWeeklyData
          ..clear()
          ..addAll(series('calories_burned'));
        _waterWeeklyData
          ..clear()
          ..addAll(series('water_intake_liters'));
        _distanceWeeklyData
          ..clear()
          ..addAll(series('distance_km'));

        _bmi = (profile?['bmi'] as num?)?.toDouble() ?? 0;
        _bmiStatus =
            _bmi > 0 ? (profile?['bmi_status'] as String? ?? '') : '';
        _heightCm = (profile?['height_cm'] as num?)?.toDouble();
        _weightKg = (profile?['weight_kg'] as num?)?.toDouble();
        _gender = profile?['gender'] as String?;

        final dob = profile?['date_of_birth'] as String?;
        if (dob != null && dob.isNotEmpty) {
          try {
            final birthDate = DateTime.parse(dob);
            final now = DateTime.now();
            var age = now.year - birthDate.year;
            if (now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day)) {
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

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();

    try {
      await ref.read(metricsSyncServiceProvider).syncNow();
    } catch (_) {}

    await Future.wait([
      _loadData(),
      _refreshNotificationBadge(),
      _loadStreak(),
      _loadGoals(),
      _loadCoachingData(),
      _loadReviews(),
    ]);

    invalidateProviderHomeCounts(ref);
    ref.invalidate(videoSessionsListProvider);
    ref.invalidate(homeCommunityEventProvider);
    ref.read(dailyMetricsProvider.notifier).refresh();
  }

  Widget _animated(BuildContext context, Widget child, int delayMs) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
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

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;

    final liveMetrics = ref.watch(dailyMetricsProvider).valueOrNull;
    final practice =
        ref.watch(providerPracticeSummaryProvider(widget.providerType));
    final summary = practice.valueOrNull ?? ProviderPracticeSummary.empty;

    final nextSession = nextSessionPreviewFromSessions(
      ref.watch(videoSessionsListProvider).valueOrNull,
    );

    final stepsMetric =
        resolveHomeSteps(cached: _currentSteps, live: liveMetrics);
    final caloriesMetric =
        resolveHomeCalories(cached: _currentCalories, live: liveMetrics);
    final distanceMetric =
        resolveHomeDistance(cached: _currentDistance, live: liveMetrics);

    final currentSteps = stepsMetric.value.round();
    final currentCalories = caloriesMetric.value.round();
    final currentDistance = distanceMetric.value;

    final coachingInsights = _goalsReady
        ? _coachingInsights(
            steps: currentSteps,
            calories: currentCalories,
            water: _currentWater,
          )
        : const <CoachingInsight>[];

    ref.listen(unreadNotificationsCountProvider, (previous, next) {
      final previousCount =
          previous?.maybeWhen(data: (value) => value, orElse: () => 0) ?? 0;
      final currentCount =
          next.maybeWhen(data: (value) => value, orElse: () => 0);
      if (currentCount > previousCount) {
        invalidateProviderHomeCounts(ref);
      }
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
                  context,
                  HeroHeaderV3(
                    username: _providerName,
                    usernameLoading: _nameLoading,
                    notificationCount: ref
                        .watch(unreadNotificationsCountProvider)
                        .maybeWhen(data: (value) => value, orElse: () => 0),
                    coverImageUrl:
                        ref.watch(profileImagesProvider).coverImagePath,
                    avatarUrl:
                        ref.watch(profileImagesProvider).profileImagePath,
                    streakDays: _streakDays,
                    coachingInsights: coachingInsights,
                    onNotificationTap: () async {
                      await context.push('/notifications');
                      if (mounted) {
                        _refreshNotificationBadge();
                      }
                    },
                  ),
                  0,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _animated(
                    context,
                    const HomeCommunityEventCard(),
                    40,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _animated(
                    context,
                    _ProviderFitnessExpansion(
                      expanded: _fitnessExpanded,
                      stepsSummary:
                          stepsMetric.available ? stepsMetric.displayInt : '—',
                      bmiSummary: _bmi > 0 ? _bmi.toStringAsFixed(1) : '—',
                      onChanged: (expanded) {
                        HapticFeedback.selectionClick();
                        setState(() => _fitnessExpanded = expanded);
                      },
                      child: Column(
                        children: [
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
                                    : 0,
                                mainValue: stepsMetric.available
                                    ? stepsMetric.displayInt
                                    : '—',
                                subValue: 'of $_goalSteps steps',
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
                                    : 0,
                                mainValue: caloriesMetric.available
                                    ? '$currentCalories'
                                    : '—',
                                subValue: 'kcal · goal $_goalCalories',
                                sourceNote:
                                    MetricsSourceLabels.caloriesNote(liveMetrics),
                                weekly:
                                    List<double>.from(_caloriesWeeklyData),
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
                                subValue:
                                    'of ${_goalWater.toStringAsFixed(1)} L',
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
                                    : 0,
                                mainValue: distanceMetric.available
                                    ? distanceMetric.displayOneDecimal
                                    : '—',
                                subValue:
                                    'km · goal ${_goalDistance.toStringAsFixed(1)}',
                                sourceNote:
                                    MetricsSourceLabels.distanceNote(liveMetrics),
                                weekly:
                                    List<double>.from(_distanceWeeklyData),
                                todayValue: currentDistance,
                                goalValue: _goalDistance,
                              ),
                            ],
                            onMetricTap: (index) =>
                                _openInsight(context, index),
                            onAddWater: () async {
                              const amount = 0.25;
                              final previousWater = _currentWater;
                              setState(() {
                                _currentWater += amount;
                              });

                              final saved = await WaterIntakeService.instance
                                  .addWater(amount);
                              if (!mounted) return;

                              if (saved == null) {
                                setState(() {
                                  _currentWater = previousWater;
                                });
                                return;
                              }

                              setState(() {
                                _currentWater = saved;
                              });
                              ref
                                  .read(questProgressSyncServiceProvider)
                                  .onWaterUpdated(saved);
                            },
                          ),
                          const SizedBox(height: 12),
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
                        ],
                      ),
                    ),
                    80,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _SectionTitle(
                    title: 'Professional overview',
                    isLight: isLight,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _animated(
                    context,
                    ProviderClientsSummary(
                      activeCount: summary.activeCount,
                      requestCount: summary.requestCount,
                      clients: summary.clients,
                      loading:
                          practice.isLoading && practice.valueOrNull == null,
                      nextSession: nextSession,
                      onOpenClients: () => _openClientsTab(tab: 0),
                      onOpenRequests: () => _openClientsTab(tab: 1),
                      onOpenNotes: _openClientNotes,
                      onOpenNextSession: nextSession == null
                          ? null
                          : () => context.push(
                                '/video/session/${nextSession.sessionId}',
                              ),
                      onOpenClient: (client) {
                        if (client.id.isEmpty) return;
                        context.push(
                          '${widget.clientPathPrefix}/${client.id}',
                        );
                      },
                    ),
                    140,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _animated(
                    context,
                    _reviewsFailed
                        ? ProviderReviewsHomeError(onRetry: _loadReviews)
                        : ProviderReviewsHomeSection(
                            reviews: _reviews,
                            loading: _reviewsLoading,
                            onRetry: _loadReviews,
                          ),
                    180,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _SectionTitle(
                    title: 'Explore',
                    isLight: isLight,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _animated(
                    context,
                    const QuickAccessV3(),
                    220,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _animated(
                    context,
                    const HomeCentersPreview(),
                    260,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _SectionTitle(
                    title: 'Messages',
                    isLight: isLight,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _animated(
                    context,
                    HomeNavHintCards(
                      onOpenMessagesTab: widget.onNavigateToMessagesTab,
                      onOpenMealsTab: widget.onNavigateToMealsTab,
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

  void _openInsight(BuildContext context, int index) {
    final liveMetrics = ref.read(dailyMetricsProvider).valueOrNull;
    switch (index) {
      case 0:
        context.push(
          '/insights/steps',
          extra: InsightArgs(
            MetricType.steps,
            List<double>.from(_stepsWeeklyData),
            goal: _goalSteps.toDouble(),
          ),
        );
      case 1:
        context.push(
          '/insights/calories',
          extra: InsightArgs(
            MetricType.calories,
            List<double>.from(_caloriesWeeklyData),
            goal: _goalCalories.toDouble(),
            sourceNote: liveMetrics?.caloriesSource.insightsNote,
          ),
        );
      case 2:
        context.push(
          '/insights/water',
          extra: InsightArgs(
            MetricType.water,
            List<double>.from(_waterWeeklyData),
            goal: _goalWater,
          ),
        );
      case 3:
        context.push(
          '/insights/distance',
          extra: InsightArgs(
            MetricType.distance,
            List<double>.from(_distanceWeeklyData),
            goal: _goalDistance,
            sourceNote: liveMetrics?.distanceSource.insightsNote,
          ),
        );
    }
  }
}

class _ProviderFitnessExpansion extends StatelessWidget {
  const _ProviderFitnessExpansion({
    required this.expanded,
    required this.stepsSummary,
    required this.bmiSummary,
    required this.onChanged,
    required this.child,
  });

  final bool expanded;
  final String stepsSummary;
  final String bmiSummary;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: isLight
            ? HomePremiumTheme.lightCreamCard
            : HomePremiumTheme.darkCard,
        child: ExpansionTile(
          key: const PageStorageKey<String>('provider-my-fitness'),
          initiallyExpanded: false,
          maintainState: true,
          onExpansionChanged: onChanged,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            'My Fitness',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          subtitle: Text(
            'Steps $stepsSummary · BMI $bmiSummary',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HomePremiumTheme.secondaryText(isLight),
              fontSize: 12,
            ),
          ),
          trailing: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.isLight,
  });

  final String title;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: HomePremiumTheme.primaryText(isLight),
      ),
    );
  }
}
