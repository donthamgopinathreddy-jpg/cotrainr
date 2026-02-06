import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/pressable_card.dart';

class StepsCardV3 extends StatelessWidget {
  final int steps;
  final int goal;
  final List<double> sparkline;
  final VoidCallback? onTap;
  final String? heroTag;

  const StepsCardV3({
    super.key,
    required this.steps,
    required this.goal,
    required this.sparkline,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.stepsGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'STEPS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${(steps / 1000).toStringAsFixed(1)}k / ${(goal / 1000).toStringAsFixed(1)}k',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _SparklineLine(data: sparkline)),
          const SizedBox(height: 6),
          const _WeekdayLabels(),
        ],
      ),
    );

    return PressableCard(
      onTap: onTap,
      borderRadius: 28,
      child: heroTag == null ? content : Hero(tag: heroTag!, child: content),
    );
  }
}

class _SparklineLine extends StatelessWidget {
  final List<double> data;

  const _SparklineLine({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const SizedBox(height: 24);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          height: 36,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineSparkPainter(
              data: data,
              color: Colors.white.withOpacity(0.85),
              progress: value,
            ),
          ),
        );
      },
    );
  }
}

class _LineSparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double progress;

  _LineSparkPainter({
    required this.data,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.length < 2) {
      return;
    }
    
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 0.001 ? 1.0 : maxVal - minVal;
    final dx = size.width / (data.length - 1);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = dx * i;
      final normalized = (data[i] - minVal) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      final extractLength = metric.length * progress.clamp(0.0, 1.0);
      final extractPath = metric.extractPath(0, extractLength);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineSparkPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          )
          .toList(),
    );
  }
}
