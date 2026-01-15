import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class WeeklyInsightsPage extends StatelessWidget {
  const WeeklyInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _MetricRingCard(
                    title: 'Steps',
                    value: '58.2k',
                    icon: Icons.directions_walk_outlined,
                    gradient: AppColors.stepsGradient,
                    progress: 0.82,
                  ),
                  _MetricRingCard(
                    title: 'Calories',
                    value: '12.4k',
                    icon: Icons.local_fire_department_outlined,
                    gradient: AppColors.caloriesGradient,
                    progress: 0.7,
                  ),
                  _MetricRingCard(
                    title: 'Water',
                    value: '11.3L',
                    icon: Icons.water_drop_outlined,
                    gradient: AppColors.waterGradient,
                    progress: 0.56,
                  ),
                  _MetricRingCard(
                    title: 'Distance',
                    value: '34.6 km',
                    icon: Icons.location_on_outlined,
                    gradient: AppColors.distanceGradient,
                    progress: 0.64,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _InsightSummaryCard(),
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
  const _InsightSummaryCard();

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
        children: const [
          Text(
            'Weekly summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'You improved your steps by 12% and kept hydration steady.',
            style: TextStyle(
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
