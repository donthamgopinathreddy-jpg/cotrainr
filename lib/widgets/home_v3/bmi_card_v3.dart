import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/animated_number.dart';
import 'home_premium_theme.dart';

/// BMI meter scale — shared by tile tint, value, status, and indicator.
abstract final class BmiMeterColors {
  static const scale = LinearGradient(
    colors: [
      Color(0xFF3FA9F5), // Underweight
      Color(0xFF22C55E), // Normal
      Color(0xFFFACC15), // Overweight
      Color(0xFFFF5A5A), // Obese
    ],
    stops: [0.0, 0.25, 0.5, 0.75],
  );

  static const stops = [0.0, 0.25, 0.5, 0.75];

  static Color fromProgress(double progress) {
    const colors = [
      Color(0xFF3FA9F5),
      Color(0xFF22C55E),
      Color(0xFFFACC15),
      Color(0xFFFF5A5A),
    ];
    final clamped = progress.clamp(0.0, 1.0);
    for (var i = 0; i < stops.length - 1; i++) {
      if (clamped <= stops[i + 1]) {
        final t = (clamped - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t.clamp(0.0, 1.0))!;
      }
    }
    return colors.last;
  }
}

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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final progress = bmi > 0 ? _calculateProgressFromBmi(bmi) : 0.0;
    final meterColor = bmi > 0
        ? BmiMeterColors.fromProgress(progress)
        : (isLight ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));
    final statusInfo = _getStatusInfo(status, meterColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: HomePremiumTheme.bmiTileGradient(isLight, meterColor),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Top: BMI label and value side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: BMI label with icon
              Flexible(
                child: Column(
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
                        Flexible(
                          child: Text(
                            'BMI',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Body Mass Index',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryOf(context)
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: BMI value and status
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: bmi > 0
                          ? AnimatedNumber(
                              value: bmi,
                              format: (v) => v.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: meterColor,
                                height: 1.0,
                              ),
                            )
                          : Text(
                              '--',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimaryOf(context),
                                height: 1.0,
                              ),
                            ),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Semantics(
                        label: 'BMI status $status',
                        excludeSemantics: true,
                        child: Text(
                          status.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
          
          const SizedBox(height: 12),

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
        ),
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

  _StatusInfo _getStatusInfo(String status, Color meterColor) {
    switch (status.toLowerCase()) {
      case 'underweight':
        return _StatusInfo(color: meterColor, label: 'Underweight');
      case 'normal':
      case 'healthy':
        return _StatusInfo(color: meterColor, label: 'Normal');
      case 'overweight':
        return _StatusInfo(color: meterColor, label: 'Overweight');
      case 'obese':
        return _StatusInfo(color: meterColor, label: 'Obese');
      default:
        return _StatusInfo(color: meterColor, label: 'Unknown');
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                    gradient: BmiMeterColors.scale,
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
                      color: BmiMeterColors.fromProgress(progress),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
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
              const SizedBox(width: 8),
              Text(
                '18.5-24.9',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context).withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '25-29.9',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context).withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
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
        ),
      ],
    );
  }

}
