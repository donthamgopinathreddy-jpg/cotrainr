import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/metric_insight_types.dart';
import '../../repositories/metrics_repository.dart';
import '../../services/user_goals_service.dart';
import '../../theme/insight_metric_theme.dart';
import '../../widgets/insights/insight_premium_widgets.dart';

export '../../models/metric_insight_types.dart';

class InsightsDetailPage extends StatefulWidget {
  final InsightArgs args;

  const InsightsDetailPage({super.key, required this.args});

  @override
  State<InsightsDetailPage> createState() => _InsightsDetailPageState();
}

class _InsightsDetailPageState extends State<InsightsDetailPage>
    with TickerProviderStateMixin {
  int _rangeIndex = 0;
  int? _selectedIndex;
  bool _caloriesConsumed = true;
  late final List<DateTime> _weekDates;
  List<double>? _monthData;
  List<double>? _quarterData;
  List<DateTime>? _monthDates;
  List<DateTime>? _quarterDates;
  bool _isLoadingExtended = false;
  double? _currentGoal;
  double? _previousPeriodTotal;
  final MetricsRepository _metricsRepo = MetricsRepository();

  static const _rangeDays = [7, 30, 90];
  static const _rangeLabels = ['Last 7 days', 'Last 30 days', 'Last 90 days'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekDates = _datesForDays(7, now);
    _loadGoal();
    _loadPreviousPeriodTotal(7);
  }

  List<DateTime> _datesForDays(int days, DateTime now) {
    return List.generate(days, (index) {
      final day = now.subtract(Duration(days: days - 1 - index));
      return DateTime(day.year, day.month, day.day);
    });
  }

  List<double> _buildDataFromMetrics(
    List<Map<String, dynamic>> metrics,
    List<DateTime> dates,
  ) {
    final map = <String, double>{};
    for (final row in metrics) {
      final dateStr = row['date'] as String?;
      if (dateStr == null) continue;
      map[dateStr] = _metricValueFromRow(row, widget.args.t);
    }
    return dates
        .map((d) => map[d.toIso8601String().split('T')[0]] ?? 0.0)
        .toList();
  }

  Future<void> _loadPreviousPeriodTotal(int days) async {
    try {
      final today = DateTime.now();
      final prevEnd = today.subtract(Duration(days: days));
      final prevStart = today.subtract(Duration(days: days * 2 - 1));
      final metrics = await _metricsRepo.getMetricsForDays(days * 2);
      double total = 0;
      for (final m in metrics) {
        final dateStr = m['date'] as String?;
        if (dateStr == null) continue;
        final d = DateTime.tryParse(dateStr);
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        final start = DateTime(prevStart.year, prevStart.month, prevStart.day);
        final end = DateTime(prevEnd.year, prevEnd.month, prevEnd.day);
        if (day.isBefore(start) || day.isAfter(end)) continue;
        total += _metricValueFromRow(m, widget.args.t);
      }
      if (mounted) setState(() => _previousPeriodTotal = total);
    } catch (_) {
      if (mounted) setState(() => _previousPeriodTotal = null);
    }
  }

  Future<void> _ensureRangeData(int rangeIndex) async {
    if (rangeIndex == 0 || _isLoadingExtended) return;
    final days = _rangeDays[rangeIndex];
    final cached = rangeIndex == 1 ? _monthData : _quarterData;
    if (cached != null) return;

    if (!mounted) return;
    setState(() => _isLoadingExtended = true);
    try {
      final now = DateTime.now();
      final dates = _datesForDays(days, now);
      final metrics = await _metricsRepo.getMetricsForDays(days);
      final data = _buildDataFromMetrics(metrics, dates);
      if (mounted) {
        setState(() {
          if (rangeIndex == 1) {
            _monthDates = dates;
            _monthData = data;
          } else {
            _quarterDates = dates;
            _quarterData = data;
          }
          _isLoadingExtended = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (rangeIndex == 1) {
            _monthDates = _datesForDays(30, DateTime.now());
            _monthData = List.filled(30, 0.0);
          } else {
            _quarterDates = _datesForDays(90, DateTime.now());
            _quarterData = List.filled(90, 0.0);
          }
          _isLoadingExtended = false;
        });
      }
    }
  }

  void _onRangeChanged(int index) {
    if (_rangeIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _rangeIndex = index;
      _selectedIndex = null;
    });
    _loadPreviousPeriodTotal(_rangeDays[index]);
    _ensureRangeData(index);
  }

  static double _metricValueFromRow(Map<String, dynamic> row, MetricType type) {
    switch (type) {
      case MetricType.steps:
        return (row['steps'] as num?)?.toDouble() ?? 0;
      case MetricType.water:
        return (row['water_intake_liters'] as num?)?.toDouble() ?? 0;
      case MetricType.calories:
        return (row['calories_burned'] as num?)?.toDouble() ?? 0;
      case MetricType.distance:
        return (row['distance_km'] as num?)?.toDouble() ?? 0;
    }
  }

  static bool _hasMeaningfulData(List<double> data) =>
      data.any((v) => v > 0.001);

  String _comparisonLabel(double periodTotal, List<double> data) {
    if (!_hasMeaningfulData(data)) return 'No comparison yet';
    final prev = _previousPeriodTotal;
    if (prev == null || prev <= 0) return 'No comparison yet';
    final pct = (((periodTotal - prev) / prev) * 100).round();
    if (pct == 0) return 'Same as last period';
    final sign = pct > 0 ? '+' : '';
    final period = _rangeIndex == 0 ? 'Last Week' : 'Last Period';
    return '$sign$pct% vs $period';
  }

  static int _todayIndexInDates(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = dates.length - 1; i >= 0; i--) {
      final d = dates[i];
      if (DateTime(d.year, d.month, d.day) == today) return i;
    }
    return dates.isEmpty ? 0 : dates.length - 1;
  }

  static int _goalDaysMet(List<double> data, double? goal) {
    if (goal == null || goal <= 0) return 0;
    return data.where((v) => v >= goal).length;
  }

  static double _goalCompletionPct(List<double> data, double? goal) {
    if (goal == null || goal <= 0 || data.isEmpty) return 0;
    return (_goalDaysMet(data, goal) / data.length * 100).clamp(0.0, 100.0);
  }

  String _aiInsightBody(
    InsightMetricTheme theme,
    List<double> data,
    double? goal,
    String comparisonLabel,
  ) {
    final metricName = switch (theme.type) {
      MetricType.water => 'water',
      MetricType.steps => 'steps',
      MetricType.calories => 'calorie',
      MetricType.distance => 'distance',
    };
    final days = data.length;
    final met = _goalDaysMet(data, goal);
    final periodLabel = _rangeIndex == 0 ? '7 days' : '$days days';

    final buffer = StringBuffer();
    if (goal != null && goal > 0) {
      buffer.writeln(
        'You achieved your $metricName goal on $met of the last $periodLabel.',
      );
    } else {
      buffer.writeln(
        'You logged $metricName activity on ${_hasMeaningfulData(data) ? days : 0} of the last $periodLabel.',
      );
    }

    if (comparisonLabel.contains('%')) {
      final trend = comparisonLabel.startsWith('+')
          ? 'increased'
          : comparisonLabel.startsWith('-')
              ? 'decreased'
              : 'held steady';
      if (trend == 'held steady') {
        buffer.write('Your totals stayed consistent compared to the prior period.');
      } else {
        final pct = comparisonLabel.split('%').first.replaceAll(RegExp(r'[^\d\-+]'), '');
        buffer.write(
          'Your $metricName totals $trend ${pct.replaceAll('-', '')}% compared to the prior period.',
        );
      }
    } else {
      buffer.write('Keep tracking to unlock richer trends over time.');
    }
    return buffer.toString().trim();
  }

  Future<void> _loadGoal() async {
    final goalsService = UserGoalsService();
    double? goal;
    switch (widget.args.t) {
      case MetricType.steps:
        goal = (await goalsService.getStepsGoal()).toDouble();
        break;
      case MetricType.water:
        goal = await goalsService.getWaterGoal();
        break;
      case MetricType.calories:
        goal = (await goalsService.getCaloriesGoal()).toDouble();
        break;
      case MetricType.distance:
        goal = await goalsService.getDistanceGoal();
        break;
    }
    if (mounted) setState(() => _currentGoal = goal);
  }

  Future<void> _showGoalPicker(BuildContext context, InsightMetricTheme theme) async {
    final goal = _currentGoal ?? widget.args.goal ?? 0.0;
    final goalsService = UserGoalsService();

    final List<double> commonGoals;
    final String unit;
    final String hintText;

    switch (widget.args.t) {
      case MetricType.steps:
        commonGoals = [5000, 7500, 10000, 12000, 15000];
        unit = 'steps';
        hintText = 'Enter custom steps';
        break;
      case MetricType.water:
        commonGoals = [1.5, 2.0, 2.5, 3.0, 3.5];
        unit = 'L';
        hintText = 'Enter custom liters';
        break;
      case MetricType.calories:
        commonGoals = [1500, 1800, 2000, 2200, 2500];
        unit = 'calories';
        hintText = 'Enter custom calories';
        break;
      case MetricType.distance:
        commonGoals = [3.0, 5.0, 7.0, 10.0, 12.0];
        unit = 'km';
        hintText = 'Enter custom kilometers';
        break;
    }

    final customGoalController = TextEditingController(
      text: !commonGoals.contains(goal)
          ? (widget.args.t == MetricType.steps ||
                  widget.args.t == MetricType.calories
              ? goal.toInt().toString()
              : goal.toStringAsFixed(1))
          : '',
    );

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double? selectedGoal = goal;
          var isCustom = !commonGoals.contains(goal);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: InsightMetricTheme.surfaceCard,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Daily ${theme.title.replaceAll(' Insights', '')} Goal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...commonGoals.map((g) => ListTile(
                          title: Text(
                            widget.args.t == MetricType.steps ||
                                    widget.args.t == MetricType.calories
                                ? '${g.toInt()} $unit'
                                : '${g.toStringAsFixed(1)} $unit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          trailing: !isCustom && selectedGoal == g
                              ? Icon(Icons.check_rounded, color: theme.accent)
                              : null,
                          onTap: () {
                            setModalState(() {
                              selectedGoal = g;
                              isCustom = false;
                              customGoalController.clear();
                            });
                          },
                        )),
                    const SizedBox(height: 8),
                    Text(
                      'Custom',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customGoalController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        suffixIcon: customGoalController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.check_rounded,
                                  color: isCustom && selectedGoal != null
                                      ? theme.accent
                                      : Colors.white.withValues(alpha: 0.4),
                                ),
                                onPressed: () {
                                  final value =
                                      double.tryParse(customGoalController.text);
                                  if (value != null && value > 0) {
                                    setModalState(() {
                                      selectedGoal = value;
                                      isCustom = true;
                                    });
                                  }
                                },
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.accent, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          if (value.isEmpty) {
                            isCustom = false;
                          } else {
                            final parsed = double.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              selectedGoal = parsed;
                              isCustom = true;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              customGoalController.dispose();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedGoal == null
                                ? null
                                : () async {
                                    final finalGoal = selectedGoal!;
                                    customGoalController.dispose();
                                    Navigator.pop(context);
                                    var success = false;
                                    switch (widget.args.t) {
                                      case MetricType.steps:
                                        success = await goalsService
                                            .setStepsGoal(finalGoal.toInt());
                                        break;
                                      case MetricType.water:
                                        success = await goalsService
                                            .setWaterGoal(finalGoal);
                                        break;
                                      case MetricType.calories:
                                        success = await goalsService
                                            .setCaloriesGoal(finalGoal.toInt());
                                        break;
                                      case MetricType.distance:
                                        success = await goalsService
                                            .setDistanceGoal(finalGoal);
                                        break;
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Goal updated'
                                                : 'Failed to save goal',
                                          ),
                                        ),
                                      );
                                      await _loadGoal();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: theme.accent,
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

  ({List<double> data, List<DateTime> dates}) _activeRange() {
    switch (_rangeIndex) {
      case 1:
        return (
          data: _monthData ?? List.filled(30, 0.0),
          dates: _monthDates ?? _datesForDays(30, DateTime.now()),
        );
      case 2:
        return (
          data: _quarterData ?? List.filled(90, 0.0),
          dates: _quarterDates ?? _datesForDays(90, DateTime.now()),
        );
      default:
        return (data: widget.args.w, dates: _weekDates);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = InsightMetricTheme.from(widget.args.t);

    final range = _activeRange();
    final data = range.data;
    final dates = range.dates;
    final goal = _currentGoal ?? widget.args.goal;
    final total = data.isEmpty ? 0.0 : data.fold<double>(0, (a, b) => a + b);
    final average = data.isEmpty ? 0.0 : total / data.length;
    final peak = data.isEmpty ? 0.0 : data.reduce((a, b) => a > b ? a : b);
    final hasData = _hasMeaningfulData(data);
    final todayIndex = _todayIndexInDates(dates);
    final weekTodayIndex = _todayIndexInDates(_weekDates);
    final todayValue = widget.args.w.isEmpty
        ? 0.0
        : widget.args.w[weekTodayIndex.clamp(0, widget.args.w.length - 1)];
    final todayCompletion = goal != null && goal > 0
        ? (todayValue / goal * 100).clamp(0.0, 999.0)
        : 0.0;
    final goalCompletion = _goalCompletionPct(data, goal);
    final comparisonLabel = _comparisonLabel(total, data);
    final aiBody = _aiInsightBody(theme, data, goal, comparisonLabel);

    final breakdownCount = 7;
    final breakdownDates = dates.length >= breakdownCount
        ? dates.sublist(dates.length - breakdownCount)
        : dates;
    final breakdownData = data.length >= breakdownCount
        ? data.sublist(data.length - breakdownCount)
        : data;
    final breakdownOffset = dates.length - breakdownCount;
    final breakdownHighlight = breakdownDates.isEmpty
        ? 0
        : (_selectedIndex != null && _selectedIndex! >= breakdownOffset
            ? _selectedIndex! - breakdownOffset
            : _todayIndexInDates(breakdownDates));

    return Scaffold(
      backgroundColor: InsightMetricTheme.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: InsightMetricTheme.pageBg.withValues(alpha: 0.92),
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
                      theme.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _rangeLabels[_rangeIndex],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => _showGoalPicker(context, theme),
                  child: Text(
                    'Set goal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.accent,
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
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) {
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - t)),
                            child: child,
                          ),
                        );
                      },
                      child: InsightHeroCard(
                        theme: theme,
                        displayValue: todayValue,
                        goal: goal,
                        completionPct: todayCompletion,
                        comparisonLabel: comparisonLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InsightRangePills(
                      selectedIndex: _rangeIndex,
                      accent: theme.accent,
                      onChanged: _onRangeChanged,
                    ),
                    const SizedBox(height: 12),
                    if (theme.type == MetricType.calories)
                      _CaloriesModeToggle(
                        accent: theme.accent,
                        isConsumed: _caloriesConsumed,
                        onChanged: (v) => setState(() => _caloriesConsumed = v),
                      ),
                    if (theme.type == MetricType.calories)
                      const SizedBox(height: 12),
                    if (_isLoadingExtended && _rangeIndex > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: theme.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (!hasData)
                      InsightEmptyState(theme: theme)
                    else ...[
                      InsightGraphCard(
                        theme: theme,
                        data: data,
                        goal: goal,
                        dates: dates,
                        currentDayIndex: todayIndex,
                        selectedIndex: _selectedIndex,
                        onTouchIndex: (index) {
                          if (_selectedIndex != index) {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedIndex = index);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InsightDailyBreakdown(
                        theme: theme,
                        weekData: breakdownData,
                        weekDates: breakdownDates,
                        highlightIndex: breakdownHighlight.clamp(
                          0,
                          breakdownDates.length - 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InsightStatsGrid(
                        theme: theme,
                        average: average,
                        peak: peak,
                        total: total,
                        goalCompletionPct: goalCompletion,
                      ),
                      const SizedBox(height: 12),
                      InsightAiSummaryCard(theme: theme, body: aiBody),
                    ],
                    SizedBox(
                      height: 24 + MediaQuery.paddingOf(context).bottom,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaloriesModeToggle extends StatelessWidget {
  final Color accent;
  final bool isConsumed;
  final ValueChanged<bool> onChanged;

  const _CaloriesModeToggle({
    required this.accent,
    required this.isConsumed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InsightPremiumCard(
      radius: 22,
      color: InsightMetricTheme.surfaceCard,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _chip('Consumed', isConsumed, () => onChanged(true)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _chip('Burned', !isConsumed, () => onChanged(false)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: active
              ? Border.all(color: accent.withValues(alpha: 0.35))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
