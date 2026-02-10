import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
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
import '../../repositories/profile_repository.dart';
import '../../services/metrics_sync_service.dart';
import '../../repositories/metrics_repository.dart';
import '../../providers/quest_provider.dart';

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

  // Real data from Supabase
  String _username = 'Loading...';
  String? _avatarUrl;
  String? _coverImageUrl;
  int _notificationCount = 0;
  int _streakDays = 0;
  int _goalSteps = 10000;
  double _currentWater = 0.0;
  double _goalWater = 2.5;
  int _currentSteps = 0;
  double _currentCalories = 0.0;
  double _currentDistance = 0.0;
  double _bmi = 0.0;
  String _bmiStatus = '';
  double? _heightCm;
  double? _weightKg;

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
    
    // Load profile data first
    _loadProfileData();
    _loadNotificationsCount();
    _loadStreak();
    _loadGoals();
    _loadMetrics();
    
    // Initialize health tracking service for background step counting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthTrackingServiceProvider).initialize();
      // Start metrics sync service
      ref.read(metricsSyncServiceProvider).startSync();
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
      final profile = await supabase
          .from('profiles')
          .select('id, full_name, username, avatar_url, cover_url, height_cm, weight_kg, role')
          .eq('id', uid)
          .maybeSingle();
      
      print('HOME_V3 profile query result: $profile');
      
      if (!mounted) return;
      
      if (profile != null) {
        final fullName = profile['full_name'] as String?;
        final username = profile['username'] as String?;
        final avatarUrl = profile['avatar_url'] as String?;
        final coverUrl = profile['cover_url'] as String?;
        final heightCm = (profile['height_cm'] as num?)?.toDouble();
        final weightKg = (profile['weight_kg'] as num?)?.toDouble();
        
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
        });
        
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
  
  Future<void> _loadNotificationsCount() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

      if (mounted) {
        setState(() {
          _notificationCount = (response as List).length;
        });
      }
    } catch (e) {
      print('HOME_V3: Error loading notifications: $e');
    }
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

  Future<void> _loadMetrics() async {
    try {
      final metricsRepo = MetricsRepository();
      final todayMetrics = await metricsRepo.getTodayMetrics();
      
      if (mounted) {
        if (todayMetrics != null) {
          setState(() {
            _currentSteps = (todayMetrics['steps'] as int?) ?? 0;
            _currentCalories = (todayMetrics['calories_burned'] as num?)?.toDouble() ?? 0.0;
            _currentDistance = (todayMetrics['distance_km'] as num?)?.toDouble() ?? 0.0;
            _currentWater = (todayMetrics['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
          });
          print('HomePageV3: Loaded metrics from Supabase - Steps: $_currentSteps, Water: $_currentWater L, Calories: $_currentCalories, Distance: $_currentDistance km');
        } else {
          print('HomePageV3: No metrics found for today, keeping current values');
          // Don't reset to 0 if no metrics found - keep current values
        }
      }
    } catch (e) {
      print('HomePageV3: Error loading metrics: $e');
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
    final providerSteps = stepsAsync.value ?? 0;
    
    // Watch calories and distance
    final caloriesAsync = ref.watch(caloriesProvider);
    final providerCalories = caloriesAsync.value ?? 0.0;
    
    final distanceAsync = ref.watch(distanceProvider);
    final providerDistance = distanceAsync.value ?? 0.0;
    
    // Use provider values if available, otherwise use loaded values from Supabase
    final currentSteps = providerSteps > 0 ? providerSteps : _currentSteps;
    final currentCalories = providerCalories > 0 ? providerCalories.toInt() : _currentCalories.toInt();
    final currentDistance = providerDistance > 0 ? providerDistance : _currentDistance;
    
    // Sync metrics to Supabase when provider values change
    if (providerSteps > 0 || providerCalories > 0 || providerDistance > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(metricsSyncServiceProvider).syncNow();
      });
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: cs.background,
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
                notificationCount: _notificationCount,
                // Use database URLs first, fallback to provider (for local edits)
                coverImageUrl: _coverImageUrl ?? ref.watch(profileImagesProvider).coverImagePath,
                avatarUrl: _avatarUrl ?? ref.watch(profileImagesProvider).profileImagePath,
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
                    onAddWater: () async {
                      // Add 250ml (0.25L) to water intake
                      final waterToAdd = 0.25;
                      final oldWater = _currentWater;
                      final newWater = (_currentWater + waterToAdd).clamp(0.0, _goalWater);
                      
                      // Update local state immediately for UI responsiveness
                      setState(() {
                        _currentWater = newWater;
                      });
                      
                      // Save to Supabase - use updateTodayMetrics to set the total value
                      try {
                        final metricsRepo = MetricsRepository();
                        await metricsRepo.updateTodayMetrics(waterIntakeLiters: newWater);
                        print('HomePageV3: Saved water intake to Supabase: $newWater L (was $oldWater L)');
                        
                        // Also sync to quest progress
                        ref.read(questProgressSyncServiceProvider).onWaterUpdated(newWater);
                      } catch (e) {
                        print('HomePageV3: Error saving water intake: $e');
                        // Revert on error
                        if (mounted) {
                          setState(() {
                            _currentWater = oldWater;
                          });
                        }
                      }
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
      _loadNotificationsCount(),
      _loadStreak(),
      _loadGoals(),
      _loadMetrics(),
    ]);
    
    // Refresh health tracking data
    ref.read(stepsNotifierProvider.notifier).refresh();
    ref.invalidate(caloriesProvider);
    ref.invalidate(distanceProvider);
  }
}
