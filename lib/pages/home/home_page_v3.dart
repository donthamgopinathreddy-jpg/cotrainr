import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
import '../../widgets/home_v3/coaching_insight_builder.dart';
import '../../widgets/home_v3/metrics_source_labels.dart';
import '../../models/coaching_insight.dart';
import '../../models/daily_metrics_snapshot.dart';
import '../../repositories/meal_repository.dart';
import '../../providers/profile_images_provider.dart';
import '../../providers/health_tracking_provider.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/unified_metrics_tile_v3.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../bmi/bmi_details_screen.dart';
import '../../widgets/home_v3/quick_access_v3.dart';
import '../../widgets/home_v3/home_nav_hint_cards.dart';
import '../../widgets/home_v3/nearby_preview_v3.dart';
import '../insights/insights_detail_page.dart';
import '../../services/streak_service.dart';
import '../../services/user_goals_service.dart';
import '../../services/water_intake_service.dart';
import '../../providers/unread_notifications_count_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../services/metrics_sync_service.dart';
import '../../repositories/metrics_repository.dart';
import '../../providers/quest_provider.dart';

class HomePageV3 extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToMessagesTab;
  final VoidCallback? onNavigateToMealsTab;

  const HomePageV3({
    super.key,
    this.onNavigateToMessagesTab,
    this.onNavigateToMealsTab,
  });

  @override
  ConsumerState<HomePageV3> createState() => _HomePageV3State();
}

class _HomePageV3State extends ConsumerState<HomePageV3>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Real data from Supabase
  String _username = 'Loading...';
  String? _avatarUrl;
  String? _coverImageUrl;
  int _streakDays = 0;
  int _goalSteps = 10000;
  int _goalCalories = 2000;
  double _currentWater = 0.0;
  double _goalWater = 2.5;
  double _goalDistance = 5.0;
  int _currentSteps = 0;
  double _currentCalories = 0.0;
  double _currentDistance = 0.0;
  double _proteinToday = 0.0;
  int _proteinGoal = 150;
  double _bmi = 0.0;
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
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    UserGoalsService.revision.addListener(_onGoalsRevisionChanged);
    WaterIntakeService.revision.addListener(_onWaterIntakeRevision);
    
    // Load profile data first
    _loadProfileData();
    _loadStreak();
    _loadGoals();
    _loadCoachingData();
    
    // Initialize health tracking + sync, then load week series.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(healthTrackingServiceProvider).initialize();
      try {
        await ref.read(metricsSyncServiceProvider).syncNow();
      } catch (_) {}
      if (mounted) await _loadMetrics();
    });
  }
  
  Future<void> _loadProfileData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser == null) {
        print('HOME_V3 ERROR: currentUser is null');
        if (mounted) {
          setState(() {
            _username = 'Not logged in';
          });
        }
        return;
      }
      
      final uid = currentUser.id;
      print('HOME_V3: Fetching profile for user ID: $uid');
      
      // Fetch profile directly from Supabase
      final list = (await supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
      final profile = list.isNotEmpty ? list.first : null;
      
      print('HOME_V3 profile query result: $profile');
      
      if (!mounted) return;
      
      if (profile != null) {
        final fullName = profile['full_name'] as String?;
        final username = profile['username'] as String?;
        final avatarUrl = profile['avatar_url'] as String?;
        final coverUrl = profile['cover_url'] as String?;
        final heightCm = (profile['height_cm'] as num?)?.toDouble();
        final weightKg = (profile['weight_kg'] as num?)?.toDouble();
        final gender = profile['gender'] as String?;
        final dobStr = profile['date_of_birth'] as String?;
        int? age;
        if (dobStr != null && dobStr.isNotEmpty) {
          try {
            final dob = DateTime.parse(dobStr);
            final now = DateTime.now();
            age = now.year - dob.year;
            if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
              age = age - 1;
            }
          } catch (_) {}
        }
        
        // Use same logic as Profile page
        final newUsername = fullName != null && fullName.trim().isNotEmpty
            ? fullName.trim()
            : (username != null && username.isNotEmpty
                ? username
                : 'User');
        
        // Calculate BMI
        double newBmi = 0.0;
        String newBmiStatus = '';
        if (heightCm != null && heightCm > 0 && weightKg != null && weightKg > 0) {
          newBmi = ProfileRepository.calculateBMI(heightCm, weightKg);
          newBmiStatus = ProfileRepository.getBMIStatus(newBmi);
          print('HOME_V3: Calculated BMI: $newBmi ($newBmiStatus) from height: $heightCm cm, weight: $weightKg kg');
        } else {
          print('HOME_V3: Cannot calculate BMI - height: $heightCm, weight: $weightKg');
        }
        
        print('HOME_V3: Loaded - name: "$newUsername", avatar: "$avatarUrl", cover: "$coverUrl"');
        
        setState(() {
          _username = newUsername;
          _avatarUrl = avatarUrl;
          _coverImageUrl = coverUrl;
          _bmi = newBmi;
          _bmiStatus = newBmiStatus;
          _heightCm = heightCm;
          _weightKg = weightKg;
          _gender = gender;
          _age = age;
        });

        ref.read(healthTrackingServiceProvider).setUserHeightCm(heightCm);
        
        // Update profile images provider if URLs exist
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          ref.read(profileImagesProvider.notifier).updateProfileImage(avatarUrl);
        }
        if (coverUrl != null && coverUrl.isNotEmpty) {
          ref.read(profileImagesProvider.notifier).updateCoverImage(coverUrl);
        }
      } else {
        print('HOME_V3 ERROR: Profile not found');
        if (mounted) {
          setState(() {
            _username = 'Profile not found';
          });
        }
      }
    } catch (e, stackTrace) {
      print('HOME_V3 ERROR loading profile: $e');
      print('HOME_V3 stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _username = 'Error loading profile';
        });
      }
    }
  }
  
  Future<void> _refreshNotificationBadge() async {
    ref.invalidate(unreadNotificationsCountProvider);
  }

  Future<void> _loadGoals() async {
    final goalsService = UserGoalsService();
    final stepsGoal = await goalsService.getStepsGoal();
    final waterGoal = await goalsService.getWaterGoal();
    final caloriesGoal = await goalsService.getCaloriesGoal();
    final distanceGoal = await goalsService.getDistanceGoal();
    if (mounted) {
      setState(() {
        _goalSteps = stepsGoal;
        _goalWater = waterGoal;
        _goalCalories = caloriesGoal;
        _goalDistance = distanceGoal;
      });
    }
  }

  Future<void> _loadStreak() async {
    final streak = await StreakService.updateStreakOnLogin();
    if (mounted) {
      setState(() {
        _streakDays = streak;
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
    } catch (e) {
      print('HomePageV3: Error loading coaching data: $e');
    }
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
      weeklyWorkoutsGoal: 3,
      streakDays: _streakDays,
    );
  }

  Future<void> _loadMetrics() async {
    try {
      final metricsRepo = MetricsRepository();
      final todayMetrics = await metricsRepo.getTodayMetrics();
      final weeklyRows = await metricsRepo.getWeeklyMetrics();
      if (kDebugMode) {
        debugPrint(
          'HomePageV3: weeklyRows=${weeklyRows.length} '
          'dates=${weeklyRows.map((r) => r['date']).toList()}',
        );
      }
      // Same source as notification quick-actions / Insights water metric.
      final todayWater =
          await WaterIntakeService.instance.getTodayLiters();

      List<double> seriesFromRows(
        List<Map<String, dynamic>> rows,
        String key,
      ) {
        final now = DateTime.now();
        final dates = List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return DateTime(d.year, d.month, d.day);
        });
        final map = <String, double>{};
        for (final row in rows) {
          final dateStr = row['date'] as String?;
          if (dateStr == null) continue;
          // Normalize date keys (handle timestamp or date-only).
          final keyDate = dateStr.split('T').first;
          map[keyDate] = ((row[key] as num?) ?? 0).toDouble();
        }
        return dates
            .map((d) => map[d.toIso8601String().split('T')[0]] ?? 0.0)
            .toList();
      }

      if (!mounted) return;

      setState(() {
        if (todayMetrics != null) {
          _currentSteps = (todayMetrics['steps'] as int?) ?? 0;
          _currentCalories =
              (todayMetrics['calories_burned'] as num?)?.toDouble() ?? 0.0;
          _currentDistance =
              (todayMetrics['distance_km'] as num?)?.toDouble() ?? 0.0;
          _currentWater = todayWater;
          print(
            'HomePageV3: Loaded metrics from Supabase - Steps: $_currentSteps, Water: $_currentWater L, Calories: $_currentCalories, Distance: $_currentDistance km',
          );
        } else {
          _currentWater = todayWater;
          print(
            'HomePageV3: No metrics found for today, keeping current values',
          );
        }

        _stepsWeeklyData
          ..clear()
          ..addAll(seriesFromRows(weeklyRows, 'steps'));
        _caloriesWeeklyData
          ..clear()
          ..addAll(seriesFromRows(weeklyRows, 'calories_burned'));
        _waterWeeklyData
          ..clear()
          ..addAll(seriesFromRows(weeklyRows, 'water_intake_liters'));
        _distanceWeeklyData
          ..clear()
          ..addAll(seriesFromRows(weeklyRows, 'distance_km'));

        // Prefer today's live / cached value for the last day so insights
        // aren't empty when Health Connect has data but sync lags.
        if (_stepsWeeklyData.isNotEmpty) {
          final todaySteps = _currentSteps.toDouble();
          if (todaySteps > _stepsWeeklyData.last) {
            _stepsWeeklyData[_stepsWeeklyData.length - 1] = todaySteps;
          }
        }
        if (_caloriesWeeklyData.isNotEmpty &&
            _currentCalories > _caloriesWeeklyData.last) {
          _caloriesWeeklyData[_caloriesWeeklyData.length - 1] = _currentCalories;
        }
        if (_waterWeeklyData.isNotEmpty &&
            _currentWater > _waterWeeklyData.last) {
          _waterWeeklyData[_waterWeeklyData.length - 1] = _currentWater;
        }
        if (_distanceWeeklyData.isNotEmpty &&
            _currentDistance > _distanceWeeklyData.last) {
          _distanceWeeklyData[_distanceWeeklyData.length - 1] =
              _currentDistance;
        }
      });
    } catch (e) {
      print('HomePageV3: Error loading metrics: $e');
    }
  }

  void _onGoalsRevisionChanged() {
    _loadGoals();
  }

  void _onWaterIntakeRevision() {
    _loadMetrics();
  }

  @override
  void dispose() {
    UserGoalsService.revision.removeListener(_onGoalsRevisionChanged);
    WaterIntakeService.revision.removeListener(_onWaterIntakeRevision);
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
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final metricsAsync = ref.watch(dailyMetricsProvider);
    final liveMetrics = metricsAsync.valueOrNull;

    // Prefer live Health Connect snapshot; fall back to Supabase cache while loading.
    final currentSteps = liveMetrics?.steps ?? _currentSteps;
    final currentCalories =
        (liveMetrics?.activeCalories ?? _currentCalories).round();
    final currentDistance =
        liveMetrics?.distanceKm ?? _currentDistance;

    final caloriesSourceNote = MetricsSourceLabels.caloriesNote(liveMetrics);
    final distanceSourceNote = MetricsSourceLabels.distanceNote(liveMetrics);

    final coachingInsights = _coachingInsights(
      steps: currentSteps,
      calories: currentCalories,
      water: _currentWater,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: isLight ? Colors.white : cs.background,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.orange,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
          SliverToBoxAdapter(
            child: _animated(
              HeroHeaderV3(
                username: _username,
                notificationCount: ref.watch(unreadNotificationsCountProvider).maybeWhen(
                      data: (c) => c,
                      orElse: () => 0,
                    ),
                // Prefer provider: it updates immediately on edit profile (crop + upload).
                // `_coverImageUrl` / `_avatarUrl` are one-shot RPC cache and would stay stale.
                coverImageUrl: ref.watch(profileImagesProvider).coverImagePath ??
                    _coverImageUrl,
                avatarUrl: ref.watch(profileImagesProvider).profileImagePath ??
                    _avatarUrl,
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
            child: Transform.translate(
              offset: const Offset(0, -8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(
                  _safeSection(
                    context,
                    UnifiedMetricsTileV3(
                      metrics: [
                        UnifiedMetricViewModel(
                          label: 'STEPS',
                          icon: Icons.directions_walk_outlined,
                          selectedIcon: Icons.directions_walk,
                          ringGradient: AppColors.stepsGradient,
                          barColor: AppColors.orange,
                          progress: _goalSteps > 0
                              ? (currentSteps / _goalSteps).clamp(0.0, 1.0)
                              : 0.0,
                          mainValue: currentSteps >= 1000
                              ? '${(currentSteps / 1000).toStringAsFixed(1)}k'
                              : '$currentSteps',
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
                          progress: _goalCalories > 0
                              ? (currentCalories / _goalCalories)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          mainValue: '$currentCalories',
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
                          progress: _goalWater > 0
                              ? (_currentWater / _goalWater).clamp(0.0, 1.0)
                              : 0.0,
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
                          progress: _goalDistance > 0
                              ? (currentDistance / _goalDistance)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          mainValue: currentDistance.toStringAsFixed(1),
                          subValue:
                              'km · goal ${_goalDistance.toStringAsFixed(1)}',
                          sourceNote: distanceSourceNote,
                          weekly: List<double>.from(_distanceWeeklyData),
                          todayValue: currentDistance,
                          goalValue: _goalDistance,
                        ),
                      ],
                      onMetricTap: (i) async {
                        List<double> weekWithToday(
                          List<double> week,
                          double today,
                        ) {
                          final w = List<double>.from(week);
                          while (w.length < 7) {
                            w.insert(0, 0);
                          }
                          if (w.length > 7) {
                            w.removeRange(0, w.length - 7);
                          }
                          if (today > w.last) {
                            w[w.length - 1] = today;
                          }
                          return w;
                        }

                        switch (i) {
                          case 0:
                            await context.push(
                              '/insights/steps',
                              extra: InsightArgs(
                                MetricType.steps,
                                weekWithToday(
                                  _stepsWeeklyData,
                                  currentSteps.toDouble(),
                                ),
                                goal: _goalSteps.toDouble(),
                              ),
                            );
                            break;
                          case 1:
                            await context.push(
                              '/insights/calories',
                              extra: InsightArgs(
                                MetricType.calories,
                                weekWithToday(
                                  _caloriesWeeklyData,
                                  currentCalories.toDouble(),
                                ),
                                goal: _goalCalories.toDouble(),
                                sourceNote: liveMetrics?.caloriesSource
                                    .insightsNote,
                              ),
                            );
                            break;
                          case 2:
                            await context.push(
                              '/insights/water',
                              extra: InsightArgs(
                                MetricType.water,
                                weekWithToday(
                                  _waterWeeklyData,
                                  _currentWater,
                                ),
                                goal: _goalWater,
                              ),
                            );
                            break;
                          case 3:
                            await context.push(
                              '/insights/distance',
                              extra: InsightArgs(
                                MetricType.distance,
                                weekWithToday(
                                  _distanceWeeklyData,
                                  currentDistance,
                                ),
                                goal: _goalDistance,
                                sourceNote: liveMetrics?.distanceSource
                                    .insightsNote,
                              ),
                            );
                            break;
                        }
                        if (mounted) await _loadGoals();
                      },
                      onAddWater: () async {
                        const waterToAdd = 0.25;
                        final oldWater = _currentWater;
                        setState(
                          () => _currentWater = (_currentWater + waterToAdd)
                              .clamp(0.0, _goalWater),
                        );
                        final newWater =
                            await WaterIntakeService.instance.addWater(
                          waterToAdd,
                        );
                        if (!mounted) return;
                        if (newWater == null) {
                          setState(() => _currentWater = oldWater);
                          return;
                        }
                        setState(() => _currentWater = newWater);
                        ref
                            .read(questProgressSyncServiceProvider)
                            .onWaterUpdated(newWater);
                      },
                    ),
                  ),
                  100,
                ),
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
                    onTap: () => context.push('/bmi', extra: BmiDetailsArgs(
                        bmi: _bmi,
                        bmiStatus: _bmiStatus,
                        heightCm: _heightCm,
                        weightKg: _weightKg,
                        gender: _gender,
                        age: _age,
                      )),
                      borderRadius: BorderRadius.circular(28),
                      child: BmiCardV3(
                        bmi: _bmi,
                        status: _bmiStatus,
                        heightCm: _heightCm,
                        weightKg: _weightKg,
                      ),
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
              child:
                  _animated(_safeSection(context, const QuickAccessV3()), 220),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  _animated(_safeSection(context, const NearbyPreviewV3()), 260),
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

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    
    // Sync metrics immediately
    await ref.read(metricsSyncServiceProvider).syncNow();
    
    // Reload all data
    await Future.wait([
      _loadProfileData(),
      _refreshNotificationBadge(),
      _loadStreak(),
      _loadGoals(),
      _loadMetrics(),
      _loadCoachingData(),
    ]);
    
    // Refresh health tracking data
    ref.read(dailyMetricsProvider.notifier).refresh();
  }
}
