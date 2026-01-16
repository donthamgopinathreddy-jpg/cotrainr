import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BmiCardV3 extends StatelessWidget {
  final double bmi;
  final String status;

  const BmiCardV3({
    super.key,
    required this.bmi,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    const Color titleColor = AppColors.textPrimary;
    const Color subtitleColor = AppColors.textSecondary;
    const Color cardBg = AppColors.surfaceSoft;
    final progress = ((bmi - 14) / (40 - 14)).clamp(0.0, 1.0);

    return Container(
      height: 242,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: AppColors.green,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BMI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    'Body composition',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text(
                  'BMI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BmiSpectrumBar(progress: progress),
          const SizedBox(height: 8),
          const _BmiCategoryLabels(),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetricPill(
                icon: Icons.height_outlined,
                label: 'Height',
                value: '178 cm',
              ),
              const SizedBox(width: 10),
              _MetricPill(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                value: '72 kg',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BmiSpectrumBar extends StatelessWidget {
  final double progress;

  const _BmiSpectrumBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3FA9F5),
                    Color(0xFF22C55E),
                    Color(0xFFFACC15),
                    Color(0xFFF97316),
                    Color(0xFFEF4444),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(-1 + (2 * progress), 0),
            child: Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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

class _BmiCategoryLabels extends StatelessWidget {
  const _BmiCategoryLabels();

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Underweight',
      'Normal',
      'Overweight',
      'Obese',
      'Extremely Obese',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.65),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
