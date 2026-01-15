import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class StreakCardV3 extends StatelessWidget {
  final int days;

  const StreakCardV3({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily streak',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$days days',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          _MiniBars(count: 7),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final int count;

  const _MiniBars({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final height = 10 + (index % 3) * 6.0;
        return Container(
          margin: const EdgeInsets.only(left: 4),
          width: 6,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
