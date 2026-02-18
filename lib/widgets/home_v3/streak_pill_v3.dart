import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class StreakPillV3 extends StatelessWidget {
  final int streakDays;
  final bool compact;

  const StreakPillV3({
    super.key,
    required this.streakDays,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 40.0 : 56.0;
    final iconSize = compact ? 18.0 : 24.0;
    final fontSize = compact ? 16.0 : 20.0;
    final paddingH = compact ? 12.0 : 16.0;

    return SizedBox(
      width: double.infinity,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: paddingH),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.red, AppColors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: AppColors.cardShadowOf(context),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: iconSize,
            ),
            SizedBox(width: compact ? 8 : 12),
            Text(
              'STREAK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '$streakDays',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
