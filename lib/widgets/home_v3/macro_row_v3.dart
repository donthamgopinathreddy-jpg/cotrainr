import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../common/pressable_card.dart';

class MacroRowV3 extends StatelessWidget {
  final int calories;
  final double water;
  final double waterGoal;
  final List<double> caloriesSpark;
  final double distanceKm;
  final VoidCallback? onCaloriesTap;
  final VoidCallback? onWaterTap;
  final VoidCallback? onDistanceTap;
  final VoidCallback? onAddWater;
  final String? caloriesHeroTag;
  final String? waterHeroTag;
  final String? distanceHeroTag;

  const MacroRowV3({
    super.key,
    required this.calories,
    required this.water,
    required this.waterGoal,
    required this.caloriesSpark,
    required this.distanceKm,
    this.onCaloriesTap,
    this.onWaterTap,
    this.onDistanceTap,
    this.onAddWater,
    this.caloriesHeroTag,
    this.waterHeroTag,
    this.distanceHeroTag,
  });

  @override
  Widget build(BuildContext context) {
    const double waterHeight = 140;
    const double distanceHeight = 68;
    const double gap = 12;
    const double caloriesHeight = waterHeight + distanceHeight + gap;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(
            height: caloriesHeight,
            child: PressableCard(
              onTap: onCaloriesTap,
              borderRadius: 26,
              child: _wrapHero(
                tag: caloriesHeroTag,
                child: _CaloriesCard(
                  calories: calories,
                  spark: caloriesSpark,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: waterHeight,
                child: PressableCard(
                  onTap: onWaterTap,
                  borderRadius: 26,
                  child: _wrapHero(
                    tag: waterHeroTag,
                    child: _WaterCard(
                      water: water,
                      waterGoal: waterGoal,
                      onAddWater: onAddWater,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: distanceHeight,
                child: PressableCard(
                  onTap: onDistanceTap,
                  borderRadius: 22,
                  child: _wrapHero(
                    tag: distanceHeroTag,
                    child: _DistanceCard(distanceKm: distanceKm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wrapHero({required String? tag, required Widget child}) {
    if (tag == null) return child;
    return Hero(tag: tag, child: child);
  }
}

class _WaterCard extends StatelessWidget {
  final double water;
  final double waterGoal;
  final VoidCallback? onAddWater;

  const _WaterCard({
    required this.water,
    required this.waterGoal,
    this.onAddWater,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (waterGoal <= 0) ? 0.0 : (water / waterGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: AppColors.waterGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Text(
                  'WATER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Transform.translate(
            offset: const Offset(-2, -22),
            child: Padding(
              padding: const EdgeInsets.only(left: 48),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: water.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${waterGoal.toStringAsFixed(1)}L',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Transform.translate(
            offset: const Offset(0, -16),
            child: _WaterBar(progress: progress),
          ),
          const SizedBox(height: 6),
          Transform.translate(
            offset: const Offset(0, -10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAddWater?.call();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '+ 250ml',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  final int calories;
  final List<double> spark;

  const _CaloriesCard({required this.calories, required this.spark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.caloriesGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CALORIES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: calories.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: ' kcal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _MiniBars(data: spark),
        ],
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final double distanceKm;

  const _DistanceCard({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.distanceGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DISTANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final List<double> data;

  const _MiniBars({required this.data});

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    if (data.isEmpty) {
      return Column(
        children: [
          SizedBox(
            height: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (index) {
                return Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 5,
                      height: 0,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(labels.length, (index) {
              return Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      );
    }
    
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final count = data.length < labels.length ? data.length : labels.length;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          children: [
            SizedBox(
              height: 22,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(count, (index) {
                  final barHeight = 22 * (data[index] / maxVal) * value;
                  return Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 5,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(count, (index) {
                return Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _WaterBar extends StatelessWidget {
  final double progress;

  const _WaterBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          height: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(color: Colors.white.withOpacity(0.35)),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
