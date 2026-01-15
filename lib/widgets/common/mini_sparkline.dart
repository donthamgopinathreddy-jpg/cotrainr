import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/design_tokens.dart';

class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;

  const MiniSparkline({
    super.key,
    required this.data,
    this.color = DesignTokens.accentOrange,
    this.height = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);

    final maxY = data.reduce((a, b) => a > b ? a : b) * 1.2;
    final minY = 0.0;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              shadow: Shadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ),
          ],
          minY: minY,
          maxY: maxY,
        ),
      ),
    );
  }
}



