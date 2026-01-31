import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

enum MetricType { steps, water, calories, distance }

class InsightArgs {
  final MetricType t;
  final List<double> w;
  final double? goal;

  InsightArgs(this.t, this.w, {this.goal});
}

class InsightsDetailPage extends StatefulWidget {
  final InsightArgs args;

  const InsightsDetailPage({super.key, required this.args});

  @override
  State<InsightsDetailPage> createState() => _InsightsDetailPageState();
}

class _InsightsDetailPageState extends State<InsightsDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _rangeController;
  int? _selectedIndex;
  bool _caloriesConsumed = true;
  late final List<DateTime> _weekDates;
  late final List<DateTime> _monthDates;
  late final List<double> _monthData;

  @override
  void initState() {
    super.initState();
    _rangeController = TabController(length: 2, vsync: this);
    _rangeController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedIndex = null;
        });
      }
    });
    final now = DateTime.now();
    _weekDates = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });
    _monthDates = List.generate(30, (index) {
      final day = now.subtract(Duration(days: 29 - index));
      return DateTime(day.year, day.month, day.day);
    });
    _monthData = List.generate(30, (index) {
      final base = 5 + (index % 7);
      return base.toDouble();
    });
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  void _showGoalPicker(BuildContext context, double currentGoal) {
    final commonGoals = [5000, 7500, 10000, 12000, 15000];
    final TextEditingController customGoalController = TextEditingController(
      text: !commonGoals.contains(currentGoal.toInt()) ? currentGoal.toInt().toString() : '',
    );
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double? selectedGoal = currentGoal;
          bool isCustom = !commonGoals.contains(currentGoal.toInt());
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  'Set Daily Steps Goal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                // Common goals
                ...commonGoals.map((goal) => ListTile(
                  title: Text(
                    '${goal.toStringAsFixed(0)} steps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: !isCustom && selectedGoal == goal
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setModalState(() {
                      selectedGoal = goal.toDouble();
                      isCustom = false;
                      customGoalController.clear();
                    });
                  },
                )),
                const SizedBox(height: 8),
                // Custom input
                Text(
                  'Custom',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customGoalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter custom steps',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: customGoalController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.check_rounded,
                              color: isCustom && selectedGoal != null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              final value = double.tryParse(customGoalController.text);
                              if (value != null && value > 0) {
                                setModalState(() {
                                  selectedGoal = value;
                                  isCustom = true;
                                });
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      if (value.isEmpty) {
                        isCustom = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
                // Save and Cancel buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          customGoalController.dispose();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final finalGoal = selectedGoal ?? currentGoal;
                          customGoalController.dispose();
                          Navigator.pop(context);
                          // TODO: Save goal to state or backend
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Goal set to ${finalGoal.toInt()} steps'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _MetricConfig.from(widget.args.t);
    final isMonth = _rangeController.index == 1;
    final data = isMonth ? _monthData : widget.args.w;
    final dates = isMonth ? _monthDates : _weekDates;
    final goal = widget.args.goal;
    final total = data.fold<double>(0, (a, b) => a + b);
    final average = total / data.length;
    final peak = data.reduce((a, b) => a > b ? a : b);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Container(
        decoration: BoxDecoration(
          color: cs.surface,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
                elevation: 0,
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'Last 7 days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (config.type == MetricType.steps)
                    TextButton(
                      onPressed: () => _showGoalPicker(context, goal ?? 10000),
                      child: Text(
                        'Set goal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _KpiHeader(
                        config: config,
                        value: total,
                        unit: config.unit,
                        deltaLabel: '+12%',
                      ),
                      const SizedBox(height: 12),
                      _RangeTabs(controller: _rangeController),
                      const SizedBox(height: 12),
                      if (config.type == MetricType.calories)
                        _ConsumedToggle(
                          isLeft: _caloriesConsumed,
                          onChanged: (value) {
                            setState(() => _caloriesConsumed = value);
                          },
                        ),
                      if (config.type == MetricType.calories)
                        const SizedBox(height: 8),
                      _GraphCard(
                        config: config,
                        data: data,
                        goal: goal,
                        dates: dates,
                        onTouchIndex: (index) {
                          if (_selectedIndex != index) {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedIndex = index);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (!isMonth)
                        _WeekdayRow(
                          dates: dates,
                          highlightIndex: _selectedIndex,
                        ),
                      if (isMonth)
                        _RangeSummaryRow(
                          start: dates.first,
                          end: dates.last,
                        ),
                      const SizedBox(height: 12),
                      _InsightsCards(
                        config: config,
                        average: average,
                        peak: peak,
                        consistency: 0.78,
                        goalHitRate: 0.64,
                        unit: config.unit,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricConfig {
  final MetricType type;
  final String title;
  final String unit;
  final LinearGradient gradient;
  final Color fillColor;
  final String heroTag;

  _MetricConfig({
    required this.type,
    required this.title,
    required this.unit,
    required this.gradient,
    required this.fillColor,
    required this.heroTag,
  });

  factory _MetricConfig.from(MetricType type) {
    switch (type) {
      case MetricType.steps:
        return _MetricConfig(
          type: type,
          title: 'Steps Insights',
          unit: 'steps',
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8A00), Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          fillColor: const Color(0xFFFF8A00).withOpacity(0.18),
          heroTag: 'tile_steps',
        );
      case MetricType.water:
        return _MetricConfig(
          type: type,
          title: 'Water Insights',
          unit: 'L',
          gradient: const LinearGradient(
            colors: [Color(0xFF1EA7FF), Color(0xFF6FD3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          fillColor: const Color(0xFF1EA7FF).withOpacity(0.18),
          heroTag: 'tile_water',
        );
      case MetricType.calories:
        return _MetricConfig(
          type: type,
          title: 'Calories Insights',
          unit: 'kcal',
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4D6D), Color(0xFFFF8FA3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          fillColor: const Color(0xFFFF4D6D).withOpacity(0.18),
          heroTag: 'tile_calories',
        );
      case MetricType.distance:
        return _MetricConfig(
          type: type,
          title: 'Distance Insights',
          unit: 'km',
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9D9BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          fillColor: const Color(0xFF6C63FF).withOpacity(0.18),
          heroTag: 'tile_distance',
        );
    }
  }
}

class _KpiHeader extends StatelessWidget {
  final _MetricConfig config;
  final double value;
  final String unit;
  final String deltaLabel;

  const _KpiHeader({
    required this.config,
    required this.value,
    required this.unit,
    required this.deltaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 28,
      gradient: config.gradient,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _metricIcon(config.type),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                value.toStringAsFixed(1),
                key: ValueKey(value),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              deltaLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  final TabController controller;

  const _RangeTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.22) : cs.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(999),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        unselectedLabelColor: isDark ? Colors.white.withOpacity(0.6) : cs.onSurfaceVariant,
        labelColor: isDark ? Colors.white : cs.onSurface,
        tabs: const [
          Tab(text: 'Week'),
          Tab(text: 'Month'),
        ],
      ),
    );
  }
}

class _GraphCard extends StatelessWidget {
  final _MetricConfig config;
  final List<double> data;
  final double? goal;
  final List<DateTime> dates;
  final ValueChanged<int?> onTouchIndex;

  const _GraphCard({
    required this.config,
    required this.data,
    required this.goal,
    required this.dates,
    required this.onTouchIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: config.heroTag,
      child: _GlassCard(
        radius: 24,
        gradient: config.gradient,
        child: SizedBox(
          height: 220,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LineChart(
                _lineChartData(value),
                duration: const Duration(milliseconds: 0),
              );
            },
          ),
        ),
      ),
    );
  }

  LineChartData _lineChartData(double progress) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }
    return LineChartData(
      minX: 0,
      maxX: data.length - 1,
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.black.withOpacity(0.45),
          tooltipRoundedRadius: 14,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final index = spot.x.toInt().clamp(0, dates.length - 1);
              final date = dates[index];
              final dateLabel = '${date.day}/${date.month}';
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} ${config.unit}\n$dateLabel',
                const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              );
            }).toList();
          },
        ),
        touchCallback: (event, response) {
          onTouchIndex(response?.lineBarSpots?.first.spotIndex);
        },
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: Colors.white.withOpacity(0.35),
                strokeWidth: 2,
              ),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeColor: Colors.white,
                  );
                },
              ),
            );
          }).toList();
        },
      ),
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= dates.length) {
                return const SizedBox.shrink();
              }
              final date = dates[index];
              final label = '${date.day}';
              return Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.6),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.white,
          barWidth: 3,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: config.fillColor.withOpacity(0.16 * progress),
          ),
        ),
      ],
      extraLinesData: goal == null
          ? ExtraLinesData()
          : ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: goal!,
                color: Colors.white.withOpacity(0.35),
                strokeWidth: 1,
                dashArray: [6, 6],
              ),
            ]),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final List<DateTime> dates;
  final int? highlightIndex;

  const _WeekdayRow({required this.dates, required this.highlightIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GlassCard(
      radius: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(dates.length, (index) {
          final isActive = index == highlightIndex;
          final date = dates[index];
          final weekday = _weekdayShort(date.weekday);
          final activeColor = isDark ? Colors.white : cs.onSurface;
          final inactiveColor = isDark ? Colors.white.withOpacity(0.6) : cs.onSurfaceVariant;
          return Column(
            children: [
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 6,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark ? Colors.white : cs.primary)
                      : (isDark ? Colors.white.withOpacity(0.2) : cs.surfaceContainerHighest),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

String _weekdayShort(int weekday) {
  const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return names[(weekday - 1).clamp(0, 6)];
}

class _RangeSummaryRow extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const _RangeSummaryRow({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GlassCard(
      radius: 22,
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: isDark ? Colors.white : cs.onSurface,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '${start.day}/${start.month} - ${end.day}/${end.month}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCards extends StatelessWidget {
  final _MetricConfig config;
  final double average;
  final double peak;
  final double consistency;
  final double goalHitRate;
  final String unit;

  const _InsightsCards({
    required this.config,
    required this.average,
    required this.peak,
    required this.consistency,
    required this.goalHitRate,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Peak day',
                value: peak.toStringAsFixed(1),
                unit: unit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightStatCard(
                icon: Icons.show_chart_rounded,
                label: 'Avg',
                value: average.toStringAsFixed(1),
                unit: unit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InsightStatCard(
                icon: Icons.timeline_rounded,
                label: 'Consistency',
                value: '${(consistency * 100).toInt()}%',
                unit: '',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightStatCard(
                icon: Icons.emoji_events_outlined,
                label: 'Goal hit',
                value: '${(goalHitRate * 100).toInt()}%',
                unit: '',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _InsightStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GlassCard(
      radius: 22,
      gradient: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white.withOpacity(0.8) : cs.onSurface.withOpacity(0.8),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white.withOpacity(0.6) : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : cs.onSurface,
              ),
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withOpacity(0.7) : cs.onSurfaceVariant,
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

class _ConsumedToggle extends StatelessWidget {
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _ConsumedToggle({required this.isLeft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 22,
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              label: 'Consumed',
              isActive: isLeft,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleChip(
              label: 'Burned',
              isActive: !isLeft,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(isActive ? 1 : 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final LinearGradient? gradient;

  const _GlassCard({
    required this.child,
    required this.radius,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null 
                ? (isDark ? Colors.white.withOpacity(0.12) : cs.surfaceContainerHighest)
                : null,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

IconData _metricIcon(MetricType type) {
  switch (type) {
    case MetricType.steps:
      return Icons.directions_walk_outlined;
    case MetricType.water:
      return Icons.water_drop_outlined;
    case MetricType.calories:
      return Icons.local_fire_department_outlined;
    case MetricType.distance:
      return Icons.location_on_outlined;
  }
}
