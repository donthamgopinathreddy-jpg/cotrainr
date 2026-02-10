import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../repositories/metrics_repository.dart';
import '../../services/user_goals_service.dart';

/// Provider for weekly metrics
final weeklyMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final metricsRepo = MetricsRepository();
  final weeklyMetrics = await metricsRepo.getWeeklyMetrics();
  
  // Calculate totals for the week
  int totalSteps = 0;
  double totalCalories = 0.0;
  double totalWater = 0.0;
  double totalDistance = 0.0;
  
  for (final metric in weeklyMetrics) {
    totalSteps += (metric['steps'] as int?) ?? 0;
    totalCalories += (metric['calories_burned'] as num?)?.toDouble() ?? 0.0;
    totalWater += (metric['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
    totalDistance += (metric['distance_km'] as num?)?.toDouble() ?? 0.0;
  }
  
  // Get goals for progress calculation
  final goalsService = UserGoalsService();
  final stepsGoal = await goalsService.getStepsGoal();
  final waterGoal = await goalsService.getWaterGoal();
  
  // Calculate weekly goals (7x daily goals)
  final weeklyStepsGoal = stepsGoal * 7;
  final weeklyWaterGoal = waterGoal * 7;
  final weeklyCaloriesGoal = 2000.0 * 7; // Average 2000 calories/day
  final weeklyDistanceGoal = 5.0 * 7; // Average 5km/day
  
  return {
    'steps': totalSteps,
    'calories': totalCalories,
    'water': totalWater,
    'distance': totalDistance,
    'stepsGoal': weeklyStepsGoal,
    'waterGoal': weeklyWaterGoal,
    'caloriesGoal': weeklyCaloriesGoal,
    'distanceGoal': weeklyDistanceGoal,
    'stepsProgress': weeklyStepsGoal > 0 ? (totalSteps / weeklyStepsGoal).clamp(0.0, 1.0) : 0.0,
    'caloriesProgress': weeklyCaloriesGoal > 0 ? (totalCalories / weeklyCaloriesGoal).clamp(0.0, 1.0) : 0.0,
    'waterProgress': weeklyWaterGoal > 0 ? (totalWater / weeklyWaterGoal).clamp(0.0, 1.0) : 0.0,
    'distanceProgress': weeklyDistanceGoal > 0 ? (totalDistance / weeklyDistanceGoal).clamp(0.0, 1.0) : 0.0,
    'dailyMetrics': weeklyMetrics,
  };
});

class WeeklyInsightsPage extends ConsumerWidget {
  const WeeklyInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyMetricsAsync = ref.watch(weeklyMetricsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Weekly Insights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Your stats for the last 7 days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              weeklyMetricsAsync.when(
                data: (metrics) {
                  final steps = metrics['steps'] as int;
                  final calories = metrics['calories'] as double;
                  final water = metrics['water'] as double;
                  final distance = metrics['distance'] as double;
                  
                  final stepsProgress = metrics['stepsProgress'] as double;
                  final caloriesProgress = metrics['caloriesProgress'] as double;
                  final waterProgress = metrics['waterProgress'] as double;
                  final distanceProgress = metrics['distanceProgress'] as double;
                  
                  return Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _MetricRingCard(
                            title: 'Steps',
                            value: _formatSteps(steps),
                            icon: Icons.directions_walk_outlined,
                            gradient: AppColors.stepsGradient,
                            progress: stepsProgress,
                          ),
                          _MetricRingCard(
                            title: 'Calories',
                            value: _formatCalories(calories),
                            icon: Icons.local_fire_department_outlined,
                            gradient: AppColors.caloriesGradient,
                            progress: caloriesProgress,
                          ),
                          _MetricRingCard(
                            title: 'Water',
                            value: _formatWater(water),
                            icon: Icons.water_drop_outlined,
                            gradient: AppColors.waterGradient,
                            progress: waterProgress,
                          ),
                          _MetricRingCard(
                            title: 'Distance',
                            value: _formatDistance(distance),
                            icon: Icons.location_on_outlined,
                            gradient: AppColors.distanceGradient,
                            progress: distanceProgress,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InsightSummaryCard(metrics: metrics),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading weekly insights',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRingCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final double progress;

  const _MetricRingCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _AnimatedRing(
            progress: progress,
            gradient: gradient,
          ),
        ],
      ),
    );
  }
}

class _AnimatedRing extends StatelessWidget {
  final double progress;
  final LinearGradient gradient;

  const _AnimatedRing({required this.progress, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 7,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.08)),
              ),
              ShaderMask(
                shaderCallback: (rect) => gradient.createShader(rect),
                child: CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  strokeWidth: 7,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightSummaryCard extends StatelessWidget {
  final Map<String, dynamic> metrics;

  const _InsightSummaryCard({required this.metrics});

  String _generateSummary() {
    final dailyMetrics = metrics['dailyMetrics'] as List;
    if (dailyMetrics.isEmpty) {
      return 'Start tracking your metrics to see your weekly summary!';
    }

    final steps = metrics['steps'] as int;
    final water = metrics['water'] as double;
    final distance = metrics['distance'] as double;

    final List<String> achievements = [];

    if (steps >= 50000) {
      achievements.add('amazing ${_formatSteps(steps)} steps');
    } else if (steps >= 35000) {
      achievements.add('great ${_formatSteps(steps)} steps');
    }

    if (water >= 14.0) {
      achievements.add('excellent hydration');
    } else if (water >= 10.5) {
      achievements.add('good hydration');
    }

    if (distance >= 35.0) {
      achievements.add('${distance.toStringAsFixed(1)} km covered');
    }

    if (achievements.isEmpty) {
      return 'Keep going! Track your daily activities to build your weekly summary.';
    }

    if (achievements.length == 1) {
      return 'You achieved ${achievements[0]} this week!';
    } else if (achievements.length == 2) {
      return 'You achieved ${achievements[0]} and ${achievements[1]} this week!';
    } else {
      return 'You achieved ${achievements[0]}, ${achievements[1]}, and ${achievements[2]} this week!';
    }
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _generateSummary(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xB3FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper functions for formatting
String _formatSteps(int steps) {
  if (steps >= 1000000) {
    return '${(steps / 1000000).toStringAsFixed(1)}M';
  } else if (steps >= 1000) {
    return '${(steps / 1000).toStringAsFixed(1)}k';
  }
  return steps.toString();
}

String _formatCalories(double calories) {
  if (calories >= 1000) {
    return '${(calories / 1000).toStringAsFixed(1)}k';
  }
  return calories.toStringAsFixed(0);
}

String _formatWater(double water) {
  return '${water.toStringAsFixed(1)}L';
}

String _formatDistance(double distance) {
  return '${distance.toStringAsFixed(1)} km';
}
