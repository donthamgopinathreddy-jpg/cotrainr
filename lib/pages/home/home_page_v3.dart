import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/steps_card_v3.dart';
import '../../widgets/home_v3/macro_row_v3.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../../widgets/home_v3/quick_access_v3.dart';
import '../../widgets/home_v3/feed_preview_v3.dart';
import '../../widgets/home_v3/nearby_preview_v3.dart';
import '../insights/insights_detail_page.dart';

class HomePageV3 extends StatefulWidget {
  const HomePageV3({super.key});

  @override
  State<HomePageV3> createState() => _HomePageV3State();
}

class _HomePageV3State extends State<HomePageV3> {
  final ScrollController _scrollController = ScrollController();

  // Mock data
  final String _username = 'John Doe';
  final int _notificationCount = 3;
  final int _streakDays = 7;
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
    ErrorWidget.builder = (details) {
      return Container(
        color: AppColors.bg,
        padding: const EdgeInsets.all(16),
        child: Text(
          'UI error: ${details.exception}',
          style: const TextStyle(color: Colors.white),
        ),
      );
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _safeSection(Widget child) {
    try {
      return child;
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Section failed to render',
          style: TextStyle(color: AppColors.textSecondary),
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
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _animated(
              HeroHeaderV3(
                username: _username,
                notificationCount: _notificationCount,
                coverImageUrl: null,
                avatarUrl: null,
                streakDays: _streakDays,
                onNotificationTap: () => context.push('/notifications'),
              ),
              0,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _animated(
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: _safeSection(
                    StepsCardV3(
                      steps: _currentSteps,
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
                ),
                100,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _animated(
                _safeSection(
                  MacroRowV3(
                    calories: _currentCalories,
                    water: _currentWater,
                    waterGoal: _goalWater,
                    caloriesSpark: _caloriesWeeklyData,
                    distanceKm: _currentDistance,
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
                _safeSection(BmiCardV3(bmi: _bmi, status: _bmiStatus)),
                180,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _animated(_safeSection(const QuickAccessV3()), 220),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _animated(_safeSection(const FeedPreviewV3()), 260),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _animated(_safeSection(const NearbyPreviewV3()), 300),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
