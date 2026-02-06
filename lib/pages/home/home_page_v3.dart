import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_images_provider.dart';
import '../../providers/health_tracking_provider.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/streak_pill_v3.dart';
import '../../widgets/home_v3/steps_card_v3.dart';
import '../../widgets/home_v3/macro_row_v3.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../../widgets/home_v3/quick_access_v3.dart';
import '../../widgets/home_v3/feed_preview_v3.dart';
import '../../widgets/home_v3/nearby_preview_v3.dart';
import '../insights/insights_detail_page.dart';
import '../../services/streak_service.dart';
import '../../services/user_goals_service.dart';

class HomePageV3 extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToCocircle;

  const HomePageV3({super.key, this.onNavigateToCocircle});

  @override
  ConsumerState<HomePageV3> createState() => _HomePageV3State();
}

class _HomePageV3State extends ConsumerState<HomePageV3>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Mock data
  final String _username = 'John Doe';
  final int _notificationCount = 3;
  int _streakDays = 0;
  int _goalSteps = 10000;
  double _currentWater = 0.0;
  double _goalWater = 2.5;
  final double _bmi = 0.0;
  final String _bmiStatus = '';

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
    _loadStreak();
    _loadGoals();
    // Initialize health tracking service for background step counting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthTrackingServiceProvider).initialize();
    });
  }

  Future<void> _loadGoals() async {
    final goalsService = UserGoalsService();
    final stepsGoal = await goalsService.getStepsGoal();
    final waterGoal = await goalsService.getWaterGoal();
    if (mounted) {
      setState(() {
        _goalSteps = stepsGoal;
        _goalWater = waterGoal;
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
    final cs = Theme.of(context).colorScheme;
    // Watch step count from health tracking provider (updates every 30 seconds)
    final stepsAsync = ref.watch(stepsNotifierProvider);
    final currentSteps = stepsAsync.value ?? 0;
    
    // Watch calories and distance
    final caloriesAsync = ref.watch(caloriesProvider);
    final currentCalories = caloriesAsync.value?.toInt() ?? 0;
    
    final distanceAsync = ref.watch(distanceProvider);
    final currentDistance = distanceAsync.value ?? 0.0;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: cs.background,
        body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _animated(
              HeroHeaderV3(
                username: _username,
                notificationCount: _notificationCount,
                coverImageUrl: ref.watch(profileImagesProvider).coverImagePath,
                avatarUrl: ref.watch(profileImagesProvider).profileImagePath,
                streakDays: 0, // Remove streak from header
                onNotificationTap: () => context.push('/notifications'),
              ),
              0,
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(
                  _safeSection(
                    context,
                    StreakPillV3(streakDays: _streakDays),
                  ),
                  50,
                ),
              ),
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
                    StepsCardV3(
                    steps: currentSteps,
                    goal: _goalSteps,
                    sparkline: _stepsWeeklyData,
                    heroTag: 'tile_steps',
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _animated(
                _safeSection(
                  context,
                  MacroRowV3(
                    calories: currentCalories,
                    water: _currentWater,
                    waterGoal: _goalWater,
                    caloriesSpark: _caloriesWeeklyData,
                    distanceKm: currentDistance,
                    caloriesHeroTag: 'tile_calories',
                    waterHeroTag: 'tile_water',
                    distanceHeroTag: 'tile_distance',
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
                    onAddWater: () {
                      setState(() {
                        _currentWater += 0.25; // Add 250ml (0.25L)
                        if (_currentWater > _goalWater) {
                          _currentWater = _goalWater; // Cap at goal
                        }
                      });
                    },
                  ),
                ),
                140,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  _animated(_safeSection(context, const QuickAccessV3()), 220),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  _animated(_safeSection(context, FeedPreviewV3(onViewAllTap: widget.onNavigateToCocircle)), 260),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  _animated(_safeSection(context, const NearbyPreviewV3()), 300),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      ),
    );
  }
}
