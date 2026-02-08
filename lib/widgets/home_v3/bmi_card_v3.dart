import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BmiCardV3 extends StatelessWidget {
  final double bmi;
  final String status;
  final double? heightCm;
  final double? weightKg;

  const BmiCardV3({
    super.key,
    required this.bmi,
    required this.status,
    this.heightCm,
    this.weightKg,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = bmi > 0 ? _calculateProgressFromBmi(bmi) : 0.0;
    final statusInfo = _getStatusInfo(status);
    
    // Light background color matching status
    final statusColor = bmi > 0 ? _getColorFromProgress(progress) : Colors.grey;
    final cardBg = statusColor.withOpacity(isDark ? 0.3 : 0.25);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: BMI label and value side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: BMI label with icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.monitor_weight,
                        size: 20,
                        color: AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BMI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Body Mass Index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryOf(context).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              // Right: BMI value and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: bmi > 0 ? _getColorFromProgress(progress) : AppColors.textPrimaryOf(context),
                        height: 1.0,
                      ),
                    ),
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusInfo.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Full width scale bar
          _GradientScaleBar(
            progress: progress,
            bmi: bmi,
            context: context,
            isCompact: true,
          ),
          
          const SizedBox(height: 16),
          
          // Height and Weight pills in a row
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  icon: Icons.height,
                  label: 'Height',
                  value: _formatHeight(heightCm),
                  context: context,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  icon: Icons.monitor_weight,
                  label: 'Weight',
                  value: _formatWeight(weightKg),
                  context: context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatHeight(double? heightCm) {
    if (heightCm == null || heightCm <= 0) return '--';
    
    // Show both metric and imperial
    final cm = heightCm.toInt();
    final totalInches = (heightCm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    
    return '$cm cm / $feet\'$inches"';
  }

  String _formatWeight(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return '--';
    
    // Show both metric and imperial
    final kg = weightKg.toStringAsFixed(1);
    final weightLbs = (weightKg / 0.453592).round();
    
    return '$kg kg / $weightLbs lbs';
  }

  double _calculateProgressFromBmi(double bmi) {
    // Map BMI to progress (0.0 to 1.0) based on scale ranges:
    // <18.5 (Underweight) → 0.0-0.25
    // 18.5-24.9 (Normal) → 0.25-0.5
    // 25-29.9 (Overweight) → 0.5-0.75
    // >=30 (Obese) → 0.75-1.0
    
    if (bmi < 18.5) {
      // Underweight: map 0-18.5 to 0.0-0.25
      if (bmi <= 0) return 0.0;
      return (bmi / 18.5) * 0.25;
    } else if (bmi <= 24.9) {
      // Normal: map 18.5-24.9 to 0.25-0.5
      return 0.25 + ((bmi - 18.5) / (24.9 - 18.5)) * 0.25;
    } else if (bmi <= 29.9) {
      // Overweight: map 25-29.9 to 0.5-0.75
      return 0.5 + ((bmi - 25.0) / (29.9 - 25.0)) * 0.25;
    } else {
      // Obese: map 30+ to 0.75-1.0 (cap at 40 for display)
      const maxBmi = 40.0;
      if (bmi >= maxBmi) return 1.0;
      return 0.75 + ((bmi - 30.0) / (maxBmi - 30.0)) * 0.25;
    }
  }

  Color _getColorFromProgress(double progress) {
    // Map progress (0.0 to 1.0) to gradient colors matching the scale
    const colors = [
      Color(0xFF3FA9F5), // Blue - Underweight (0.0)
      Color(0xFF22C55E), // Green - Normal (0.25)
      Color(0xFFFACC15), // Yellow - Overweight (0.5)
      Color(0xFFFF5A5A), // Red - Obese (0.75)
    ];
    const stops = [0.0, 0.25, 0.5, 0.75];
    
    // Clamp progress to valid range
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    // Find the two colors to interpolate between
    for (int i = 0; i < stops.length - 1; i++) {
      if (clampedProgress <= stops[i + 1]) {
        final t = (clampedProgress - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t.clamp(0.0, 1.0))!;
      }
    }
    // If progress > 0.75, use red (obese)
    return colors.last;
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'underweight':
        return _StatusInfo(
          color: const Color(0xFF3FA9F5),
          label: 'Underweight',
        );
      case 'normal':
        return _StatusInfo(
          color: const Color(0xFF22C55E),
          label: 'Normal',
        );
      case 'overweight':
        return _StatusInfo(
          color: const Color(0xFFFF8A00),
          label: 'Overweight',
        );
      case 'obese':
        return _StatusInfo(
          color: const Color(0xFFFF5A5A),
          label: 'Obese',
        );
      default:
        return _StatusInfo(
          color: Colors.grey,
          label: 'Unknown',
        );
    }
  }
}

class _StatusInfo {
  final Color color;
  final String label;

  _StatusInfo({required this.color, required this.label});
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final BuildContext context;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientScaleBar extends StatelessWidget {
  final double progress;
  final double bmi;
  final BuildContext context;
  final bool isCompact;

  const _GradientScaleBar({
    required this.progress,
    required this.bmi,
    required this.context,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scaleHeight = isCompact ? 6.0 : 8.0;
    final indicatorSize = isCompact ? 14.0 : 16.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: indicatorSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background (full width, positioned in center)
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: scaleHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3FA9F5), // Blue
                        Color(0xFF22C55E), // Green
                        Color(0xFFFACC15), // Yellow
                        Color(0xFFFF5A5A), // Red
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Indicator dot - colored dot matching scale position, positioned above scale
              if (progress > 0 && bmi > 0)
                Align(
                  alignment: Alignment(-1 + (2 * progress.clamp(0.0, 1.0)), 0),
                  child: Container(
                    width: indicatorSize,
                    height: indicatorSize,
                    decoration: BoxDecoration(
                      color: _getColorFromProgress(progress),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '<18.5',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context).withOpacity(0.7),
              ),
            ),
            Text(
              '18.5-24.9',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context).withOpacity(0.7),
              ),
            ),
            Text(
              '25-29.9',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context).withOpacity(0.7),
              ),
            ),
            Text(
              '>30',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorFromProgress(double progress) {
    // Map progress (0.0 to 1.0) to gradient colors matching the scale
    const colors = [
      Color(0xFF3FA9F5), // Blue - Underweight (0.0)
      Color(0xFF22C55E), // Green - Normal (0.25)
      Color(0xFFFACC15), // Yellow - Overweight (0.5)
      Color(0xFFFF5A5A), // Red - Obese (0.75)
    ];
    const stops = [0.0, 0.25, 0.5, 0.75];
    
    // Clamp progress to valid range
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    // Find the two colors to interpolate between
    for (int i = 0; i < stops.length - 1; i++) {
      if (clampedProgress <= stops[i + 1]) {
        final t = (clampedProgress - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t.clamp(0.0, 1.0))!;
      }
    }
    // If progress > 0.75, use red (obese)
    return colors.last;
  }
}
