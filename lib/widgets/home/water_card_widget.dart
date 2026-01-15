import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

class WaterCardWidget extends StatelessWidget {
  final double currentWater; // in liters
  final double goalWater; // in liters
  final List<double> weeklyData;

  const WaterCardWidget({
    super.key,
    required this.currentWater,
    required this.goalWater,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E)
        : Colors.white;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/home/weekly-insights?tab=water');
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showAddWaterSheet(context);
        },
        child: Container(
          margin: const EdgeInsets.only(right: 16, left: 8),
          padding: const EdgeInsets.all(16),
          height: 130,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.water_drop_rounded,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Water',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${currentWater.toStringAsFixed(1)}L / ${goalWater.toStringAsFixed(1)}L',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // Mini line sparkline
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: weeklyData
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: const Color(0xFF2196F3),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    minY: 0,
                    maxY: weeklyData.reduce((a, b) => a > b ? a : b) * 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddWaterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddWaterSheet(
        onAdd: (ml) {
          // TODO: Add water to daily metrics
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _AddWaterSheet extends StatefulWidget {
  final Function(int) onAdd;

  const _AddWaterSheet({required this.onAdd});

  @override
  State<_AddWaterSheet> createState() => _AddWaterSheetState();
}

class _AddWaterSheetState extends State<_AddWaterSheet> {
  int _selectedMl = 250;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Water',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          // Presets
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [150, 250, 500, 750].map((ml) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _selectedMl = ml);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedMl == ml
                        ? const Color(0xFFFF6B35)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ml}ml',
                    style: TextStyle(
                      color: _selectedMl == ml ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Custom slider
          Text('Custom: ${_selectedMl}ml'),
          Slider(
            value: _selectedMl.toDouble(),
            min: 50,
            max: 1000,
            divisions: 19,
            onChanged: (value) {
              setState(() => _selectedMl = value.round());
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              widget.onAdd(_selectedMl);
            },
            child: const Text('Add Water'),
          ),
        ],
      ),
    );
  }
}





