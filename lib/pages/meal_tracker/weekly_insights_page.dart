import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/meal_tracker_tokens.dart';
import 'dart:math' as math;

class WeeklyFood {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final String unit;

  const WeeklyFood({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.unit,
  });
}

class WeeklyInsightsPage extends StatefulWidget {
  final LinearGradient gradient;
  final DateTime selectedDate;
  final int goalCalories;
  final int goalProtein;
  final int goalCarbs;
  final int goalFats;
  final List<WeeklyFood> commonFoods;
  final List<WeeklyFood> recentFoods;

  const WeeklyInsightsPage({
    super.key,
    required this.gradient,
    required this.selectedDate,
    this.goalCalories = 2000,
    this.goalProtein = 150,
    this.goalCarbs = 200,
    this.goalFats = 65,
    this.commonFoods = const [],
    this.recentFoods = const [],
  });

  @override
  State<WeeklyInsightsPage> createState() => _WeeklyInsightsPageState();
}

class _WeeklyInsightsPageState extends State<WeeklyInsightsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _t;
  late DateTime _weekStart; // Monday
  _Metric _metric = _Metric.calories;

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
      duration: const Duration(milliseconds: 650),
    );
    _t = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _weekStart = _startOfWeek(_dateOnly(widget.selectedDate));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    return _dateOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));
  }

  List<DateTime> _weekDays(DateTime weekStart) =>
      List.generate(7, (i) => weekStart.add(Duration(days: i)));

  String _monthShort(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return m[month - 1];
  }

  String _formatRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${_monthShort(start.month)} ${start.day}–${end.day}';
    }
    return '${_monthShort(start.month)} ${start.day} – ${_monthShort(end.month)} ${end.day}';
  }

  void _setWeekStart(DateTime weekStart) {
    HapticFeedback.selectionClick();
    setState(() => _weekStart = weekStart);
    _controller
      ..reset()
      ..forward();
  }

  void _setMetric(_Metric m) {
    if (_metric == m) return;
    HapticFeedback.selectionClick();
    setState(() => _metric = m);
    _controller
      ..reset()
      ..forward();
  }

  Color _getPageBg(BuildContext context) {
    return MealTrackerTokens.pageBgOf(context);
  }

  Color _getSurface(BuildContext context) {
    return MealTrackerTokens.cardBgOf(context);
  }

  Color _getTextPrimary(BuildContext context) {
    return MealTrackerTokens.textPrimaryOf(context);
  }

  Color _getTextSecondary(BuildContext context) {
    return MealTrackerTokens.textSecondaryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = _getPageBg(context);
    final surface = _getSurface(context);
    final textPrimary = _getTextPrimary(context);
    final textSecondary = _getTextSecondary(context);

    final days = _weekDays(_weekStart);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final today = _dateOnly(DateTime.now());
    final todayIndex = days.indexWhere((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);

    final metricLabel = switch (_metric) {
      _Metric.calories => 'Calories',
      _Metric.protein => 'Protein',
      _Metric.carbs => 'Carbs',
      _Metric.fats => 'Fat',
    };

    final List<double> series = switch (_metric) {
      _Metric.calories => _caloriesData.map((e) => e.toDouble()).toList(),
      _Metric.protein => _proteinData,
      _Metric.carbs => _carbsData,
      _Metric.fats => _fatsData,
    };

    // Week aggregates (used for total ring + extra info)
    final totalCalories = _caloriesData.reduce((a, b) => a + b).toDouble();
    final totalProtein = _proteinData.reduce((a, b) => a + b);
    final totalCarbs = _carbsData.reduce((a, b) => a + b);
    final totalFats = _fatsData.reduce((a, b) => a + b);

    final minCalories = _caloriesData.reduce((a, b) => a < b ? a : b);
    final maxCalories = _caloriesData.reduce((a, b) => a > b ? a : b);
    final bestCaloriesDayIndex = _caloriesData.indexOf(maxCalories);
    final lowCaloriesDayIndex = _caloriesData.indexOf(minCalories);

    final minV = series.reduce((a, b) => a < b ? a : b);
    final maxV = series.reduce((a, b) => a > b ? a : b);
    final avgV = series.reduce((a, b) => a + b) / series.length;
    final bestIndex = series.indexOf(maxV);

    String formatValue(double v) {
      return _metric == _Metric.calories
          ? v.round().toString()
          : v.toStringAsFixed(0);
    }

    String unit() {
      return switch (_metric) {
        _Metric.calories => 'kcal',
        _Metric.protein => 'g',
        _Metric.carbs => 'g',
        _Metric.fats => 'g',
      };
    }

    final totalForMetric = switch (_metric) {
      _Metric.calories => totalCalories,
      _Metric.protein => totalProtein,
      _Metric.carbs => totalCarbs,
      _Metric.fats => totalFats,
    };

    final weeklyGoal = switch (_metric) {
      _Metric.calories => widget.goalCalories * 7,
      _Metric.protein => widget.goalProtein * 7,
      _Metric.carbs => widget.goalCarbs * 7,
      _Metric.fats => widget.goalFats * 7,
    }.toDouble();

    // Single solid ring color per metric (no gradients).
    final metricColor = switch (_metric) {
      _Metric.calories => const Color(0xFFEF4444),
      _Metric.protein => MealTrackerTokens.macroProtein,
      _Metric.carbs => MealTrackerTokens.macroCarbs,
      _Metric.fats => const Color(0xFFFACC15), // solid yellow
    };

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Insights',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            _formatRange(_weekStart, weekEnd),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _setWeekStart(_weekStart.subtract(const Duration(days: 7))),
                      icon: Icon(Icons.chevron_left_rounded, color: textPrimary),
                    ),
                    IconButton(
                      onPressed: () =>
                          _setWeekStart(_weekStart.add(const Duration(days: 7))),
                      icon: Icon(Icons.chevron_right_rounded, color: textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      label: 'Calories',
                      selected: _metric == _Metric.calories,
                      onTap: () => _setMetric(_Metric.calories),
                      surface: surface,
                      textPrimary: textPrimary,
                    ),
                    _MetricChip(
                      label: 'Protein',
                      selected: _metric == _Metric.protein,
                      onTap: () => _setMetric(_Metric.protein),
                      surface: surface,
                      textPrimary: textPrimary,
                    ),
                    _MetricChip(
                      label: 'Carbs',
                      selected: _metric == _Metric.carbs,
                      onTap: () => _setMetric(_Metric.carbs),
                      surface: surface,
                      textPrimary: textPrimary,
                    ),
                    _MetricChip(
                      label: 'Fat',
                      selected: _metric == _Metric.fats,
                      onTap: () => _setMetric(_Metric.fats),
                      surface: surface,
                      textPrimary: textPrimary,
                    ),
                  ],
                ),
              ),
            ),
            // BEFORE trends: single selected-metric weekly total ring
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _t,
                        builder: (context, _) {
                          final tt = _t.value;
                          return _WeeklyTotalRing(
                            label: metricLabel,
                            value: totalForMetric,
                            unit: unit(),
                            goal: weeklyGoal,
                            color: metricColor,
                            t: tt,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            surface: pageBg,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap the chips to switch the total ring + trend',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$metricLabel Trend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatPill(
                              label: 'Avg',
                              value: '${formatValue(avgV)} ${unit()}',
                              surface: pageBg,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              label: 'Best',
                              value: '${formatValue(maxV)} ${unit()}',
                              surface: pageBg,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 220,
                        child: AnimatedBuilder(
                          animation: _t,
                          builder: (context, _) {
                            final tt = _t.value;
                            final floorY = (_metric == _Metric.calories ? 0.0 : 0.0);
                            final paddedMin = (minV - (maxV - minV) * 0.15)
                                .clamp(floorY, double.infinity);
                            final paddedMax = maxV + (maxV - minV) * 0.20;
                            final spots = series.asMap().entries.map((e) {
                              final y = paddedMin + (e.value - paddedMin) * tt;
                              return FlSpot(e.key.toDouble(), y);
                            }).toList();

                            return LineChart(
                              LineChartData(
                                minY: paddedMin,
                                maxY: paddedMax,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: textPrimary.withOpacity(0.08),
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 42,
                                      getTitlesWidget: (v, meta) => Text(
                                        _metric == _Metric.calories
                                            ? v.round().toString()
                                            : v.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      getTitlesWidget: (v, meta) {
                                        final i = v.toInt();
                                        if (i < 0 || i >= days.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final d = days[i];
                                        const w = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                        return Text(
                                          '${w[d.weekday - 1]} ${d.day}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: textSecondary,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: MealTrackerTokens.accent,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, bar, index) {
                                        final isBest = index == bestIndex;
                                        final isToday = todayIndex == index;
                                        final c = isToday
                                            ? MealTrackerTokens.accent
                                            : isBest
                                                ? MealTrackerTokens.macroFats
                                                : MealTrackerTokens.accent2;
                                        return FlDotCirclePainter(
                                          radius: isToday ? 5 : 3.2,
                                          color: c,
                                          strokeWidth: 2,
                                          strokeColor: surface,
                                        );
                                      },
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: MealTrackerTokens.accent
                                          .withValues(alpha: 0.10 * tt),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        todayIndex >= 0 ? 'Dot = Today • Yellow = Best day' : 'Yellow = Best day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // AFTER trends: extra useful info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WeeklySummaryTile(
                        pageBg: pageBg,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        caloriesByDay: _caloriesData,
                        calorieGoal: widget.goalCalories,
                        caloriesRange: '$minCalories–$maxCalories',
                        avgCalories: (totalCalories / 7).round(),
                        bestDayLabel:
                            '${days[bestCaloriesDayIndex].day}/${days[bestCaloriesDayIndex].month}',
                        bestDayValue: _caloriesData[bestCaloriesDayIndex],
                        lowDayLabel:
                            '${days[lowCaloriesDayIndex].day}/${days[lowCaloriesDayIndex].month}',
                        lowDayValue: _caloriesData[lowCaloriesDayIndex],
                        proteinAvg: totalProtein / 7,
                        carbsAvg: totalCarbs / 7,
                        fatsAvg: totalFats / 7,
                        goalProtein: widget.goalProtein.toDouble(),
                        goalCarbs: widget.goalCarbs.toDouble(),
                        goalFats: widget.goalFats.toDouble(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Common foods list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _CommonFoodsSection(
                    pageBg: pageBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    foods: _mergeFoods(widget.recentFoods, widget.commonFoods),
                  ),
                ),
              ),
            ),
            SliverPadding(padding: const EdgeInsets.only(bottom: 90)),
          ],
        ),
      ),
    );
  }
}

List<WeeklyFood> _mergeFoods(List<WeeklyFood> recent, List<WeeklyFood> common) {
  final out = <WeeklyFood>[];
  final seen = <String>{};
  for (final f in [...recent, ...common]) {
    final key = f.name.toLowerCase().trim();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add(f);
  }
  return out;
}

class _WeeklySummaryTile extends StatelessWidget {
  final Color pageBg;
  final Color textPrimary;
  final Color textSecondary;
  final List<int> caloriesByDay;
  final int calorieGoal;
  final String caloriesRange;
  final int avgCalories;
  final String bestDayLabel;
  final int bestDayValue;
  final String lowDayLabel;
  final int lowDayValue;
  final double proteinAvg;
  final double carbsAvg;
  final double fatsAvg;
  final double goalProtein;
  final double goalCarbs;
  final double goalFats;

  const _WeeklySummaryTile({
    required this.pageBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.caloriesByDay,
    required this.calorieGoal,
    required this.caloriesRange,
    required this.avgCalories,
    required this.bestDayLabel,
    required this.bestDayValue,
    required this.lowDayLabel,
    required this.lowDayValue,
    required this.proteinAvg,
    required this.carbsAvg,
    required this.fatsAvg,
    required this.goalProtein,
    required this.goalCarbs,
    required this.goalFats,
  });

  @override
  Widget build(BuildContext context) {
    final goalDays = caloriesByDay.where((v) => v <= calorieGoal).length;
    final overDays = 7 - goalDays;

    final totalMacros = (proteinAvg + carbsAvg + fatsAvg).clamp(0.0001, 999999);
    final pPct = (proteinAvg / totalMacros).clamp(0.0, 1.0);
    final cPct = (carbsAvg / totalMacros).clamp(0.0, 1.0);
    final fPct = (fatsAvg / totalMacros).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand-new dashboard header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: MealTrackerTokens.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Summary',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Consistency • Highlights • Macro split',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MealTrackerTokens.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: MealTrackerTokens.accent.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                '$goalDays/7 on goal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: MealTrackerTokens.accent2,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        // Consistency row (7 dots)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: textPrimary.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calorie consistency',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overDays == 0
                          ? 'Great — all days within goal'
                          : '$overDays day${overDays == 1 ? '' : 's'} over goal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  for (final v in caloriesByDay) ...[
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: v <= calorieGoal
                            ? MealTrackerTokens.accent
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        // Highlights (2 cards)
        Row(
          children: [
            Expanded(
              child: _SummaryHighlight(
                title: 'Avg/day',
                value: '$avgCalories kcal',
                icon: Icons.calendar_today_rounded,
                surface: pageBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryHighlight(
                title: 'Range',
                value: caloriesRange,
                icon: Icons.swap_vert_rounded,
                surface: pageBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryHighlight(
                title: 'Best day',
                value: '$bestDayLabel • $bestDayValue',
                icon: Icons.trending_up_rounded,
                surface: pageBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryHighlight(
                title: 'Lowest day',
                value: '$lowDayLabel • $lowDayValue',
                icon: Icons.trending_down_rounded,
                surface: pageBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        // Macro split (stacked bar) + per-day macro bars
        Text(
          'Macro split (avg/day)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              Expanded(
                flex: (pPct * 1000).round().clamp(1, 1000),
                child: Container(height: 12, color: MealTrackerTokens.macroProtein),
              ),
              Expanded(
                flex: (cPct * 1000).round().clamp(1, 1000),
                child: Container(height: 12, color: MealTrackerTokens.macroCarbs),
              ),
              Expanded(
                flex: (fPct * 1000).round().clamp(1, 1000),
                child: Container(height: 12, color: MealTrackerTokens.macroFats),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MacroBar(
          label: 'Protein',
          value: proteinAvg,
          goal: goalProtein,
          color: MealTrackerTokens.macroProtein,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 8),
        _MacroBar(
          label: 'Carbs',
          value: carbsAvg,
          goal: goalCarbs,
          color: MealTrackerTokens.macroCarbs,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 8),
        _MacroBar(
          label: 'Fats',
          value: fatsAvg,
          goal: goalFats,
          color: MealTrackerTokens.macroFats,
          textSecondary: textSecondary,
        ),
      ],
    );
  }
}

class _SummaryHighlight extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _SummaryHighlight({
    required this.title,
    required this.value,
    required this.icon,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textPrimary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: MealTrackerTokens.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon,
                color: MealTrackerTokens.accent2.withValues(alpha: 0.95),
                size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
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

class _CommonFoodsSection extends StatelessWidget {
  final Color pageBg;
  final Color textPrimary;
  final Color textSecondary;
  final List<WeeklyFood> foods;

  const _CommonFoodsSection({
    required this.pageBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.foods,
  });

  @override
  Widget build(BuildContext context) {
    final shown = foods.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: MealTrackerTokens.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.restaurant_rounded,
                  color: MealTrackerTokens.accent2, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Common foods',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Quickly reuse foods you add often',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pageBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: textPrimary.withValues(alpha: 0.06)),
            ),
            child: Text(
              'No foods yet — add foods during the week to see them here.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textSecondary,
              ),
            ),
          )
        else
          Column(
            children: [
              for (final f in shown) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ),
                if (f != shown.last)
                  Divider(
                    height: 1,
                    color: textPrimary.withValues(alpha: 0.08),
                  ),
              ],
            ],
          ),
      ],
    );
  }
}

enum _Metric { calories, protein, carbs, fats }

class _MetricChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color surface;
  final Color textPrimary;

  const _MetricChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.surface,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? MealTrackerTokens.primaryGradient : null,
          color: selected ? null : surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _StatPill({
    required this.label,
    required this.value,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textPrimary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyTotalRing extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double goal;
  final Color color;
  final double t;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;

  const _WeeklyTotalRing({
    required this.label,
    required this.value,
    required this.unit,
    required this.goal,
    required this.color,
    required this.t,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (goal <= 0 ? 0.0 : (value / goal)).clamp(0.0, 1.0) * t;
    final accent = color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress,
              color: accent,
              bgColor: textPrimary.withValues(alpha: 0.10),
              strokeWidth: 10,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.round().toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textSecondary,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: textPrimary.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${(progress / (t == 0 ? 1 : t) * 100).round()}% of weekly goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Goal: ${goal.round()} $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textPrimary.withValues(alpha: 0.80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweep = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Solid (no shader) ring arc.
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;
  final Color textSecondary;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, goal);
    final pct = goal <= 0 ? 0.0 : (v / goal);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            '${value.round()}g',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
