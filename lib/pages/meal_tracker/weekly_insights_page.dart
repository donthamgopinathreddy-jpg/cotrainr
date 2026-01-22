import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

class WeeklyInsightsPage extends StatefulWidget {
  final LinearGradient gradient;

  const WeeklyInsightsPage({super.key, required this.gradient});

  @override
  State<WeeklyInsightsPage> createState() => _WeeklyInsightsPageState();
}

class _WeeklyInsightsPageState extends State<WeeklyInsightsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int _weekOffset = 0; // 0 = current week, -1 = previous week, etc.

  // Mock data for 7 days
  final List<int> _caloriesData = [1800, 2100, 1950, 2200, 1900, 2050, 2000];
  final List<double> _proteinData = [120, 140, 130, 150, 125, 135, 140];
  final List<double> _carbsData = [180, 200, 190, 220, 185, 195, 200];
  final List<double> _fatsData = [55, 65, 60, 70, 58, 62, 65];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeWeek(int direction) {
    HapticFeedback.selectionClick();
    setState(() {
      _weekOffset += direction;
    });
    _controller.reset();
    _controller.forward();
  }

  Color _getPageBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF07130E) : const Color(0xFFEAFBF0);
  }

  Color _getSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF0B1510).withOpacity(0.72)
        : Colors.white.withOpacity(0.78);
  }

  Color _getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFEFFFF5) : const Color(0xFF0B1B12);
  }

  Color _getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFFBFE8D1).withOpacity(0.75)
        : const Color(0xFF2E5A42).withOpacity(0.75);
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = _getPageBg(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = _getSurface(context);
    final textPrimary = _getTextPrimary(context);
    final textSecondary = _getTextSecondary(context);

    // Calculate stats
    final avgCalories = (_caloriesData.reduce((a, b) => a + b) / _caloriesData.length).round();
    final avgProtein = (_proteinData.reduce((a, b) => a + b) / _proteinData.length);
    final bestDay = _caloriesData.indexOf(_caloriesData.reduce(max));
    final streakDays = 5; // Mock

    return Scaffold(
      backgroundColor: isDark ? null : pageBg,
      body: Container(
        decoration: isDark
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF07130E),
                    const Color(0xFF05080A),
                  ],
                ),
              )
            : null,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Weekly Insights',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                // Week Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _changeWeek(-1),
                          icon: Icon(Icons.chevron_left_rounded, color: textPrimary),
                        ),
                        Text(
                          'Week ${_weekOffset == 0 ? 'This Week' : '${_weekOffset.abs()} weeks ago'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: _weekOffset < 0 ? () => _changeWeek(1) : null,
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: _weekOffset < 0
                                ? textPrimary
                                : textPrimary.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Stats Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Avg Calories',
                            value: '$avgCalories',
                            surface: surface,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Avg Protein',
                            value: '${avgProtein.toStringAsFixed(1)}g',
                            surface: surface,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Streak',
                            value: '$streakDays days',
                            surface: surface,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Best Day',
                            value: 'Day ${bestDay + 1}',
                            surface: surface,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Calories Line Chart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _ChartCard(
                      title: 'Calories Trend',
                      surface: surface,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      gradient: widget.gradient,
                      child: SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 500,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: textPrimary.withOpacity(0.1),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                    if (value.toInt() >= 0 &&
                                        value.toInt() < days.length) {
                                      return Text(
                                        days[value.toInt()],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    );
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _caloriesData.asMap().entries.map((entry) {
                                  return FlSpot(entry.key.toDouble(), entry.value.toDouble());
                                }).toList(),
                                isCurved: true,
                                color: const Color(0xFF19C37D),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF19C37D).withOpacity(0.15),
                                ),
                              ),
                            ],
                            minY: 1500,
                            maxY: 2500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Macros Stacked Bars
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _ChartCard(
                      title: 'Macros Breakdown',
                      surface: surface,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      gradient: widget.gradient,
                      child: SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 300,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                    if (value.toInt() >= 0 &&
                                        value.toInt() < days.length) {
                                      return Text(
                                        days[value.toInt()],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(7, (index) {
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: _proteinData[index],
                                    color: const Color(0xFF19C37D),
                                    width: 8,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: _proteinData[index] + _carbsData[index],
                                    fromY: _proteinData[index],
                                    color: const Color(0xFF38D9A9),
                                    width: 8,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: _proteinData[index] +
                                        _carbsData[index] +
                                        _fatsData[index],
                                    fromY: _proteinData[index] + _carbsData[index],
                                    color: const Color(0xFF1FBF77),
                                    width: 8,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Meal Consistency Heatmap
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _ChartCard(
                      title: 'Meal Consistency',
                      surface: surface,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      gradient: widget.gradient,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                                .map((meal) => Text(
                                      meal,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: textSecondary,
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(4, (mealIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: List.generate(7, (dayIndex) {
                                  final intensity = (Random().nextDouble() * 0.8 + 0.2);
                                  return Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF19C37D)
                                          .withOpacity(intensity),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                // Top Foods
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    child: _ChartCard(
                      title: 'Top Foods',
                      surface: surface,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      gradient: widget.gradient,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          ...List.generate(5, (index) {
                            final foods = [
                              'Chicken Breast',
                              'Brown Rice',
                              'Salmon',
                              'Greek Yogurt',
                              'Banana',
                            ];
                            final counts = [12, 10, 8, 7, 6];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: widget.gradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          foods[index],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: counts[index] / 12,
                                            backgroundColor:
                                                textPrimary.withOpacity(0.1),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              const Color(0xFF19C37D),
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${counts[index]}x',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Stat Card
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _StatCard({
    required this.label,
    required this.value,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Chart Card
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final LinearGradient gradient;

  const _ChartCard({
    required this.title,
    required this.child,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ],
      ),
    );
  }
}
