import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/metric_insight_types.dart';
import '../../repositories/metrics_repository.dart';
import '../../services/user_goals_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/insight_metric_theme.dart';
import '../../theme/text_styles.dart';
import '../../widgets/insights/insight_premium_widgets.dart';
import '../../widgets/insights/metric_goal_picker_sheet.dart';
import '../../widgets/insights/water_reminder_picker_sheet.dart';
import '../../services/water_reminder_service.dart';
import '../../services/water_intake_service.dart';

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
  String _waterReminderStatus = 'Reminder: Off';
  late List<double> _weekSeriesData;
  bool _weekSeriesLoading = true;
  final MetricsRepository _metricsRepo = MetricsRepository();

  static const _rangeDays = [7, 30, 90];
  static const _rangeLabels = ['Last 7 days', 'Last 30 days', 'Last 90 days'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekDates = _datesForDays(7, now);
    _weekSeriesData = List<double>.from(widget.args.w);
    _loadGoal();
    _loadWaterReminderStatus();
    _loadPreviousPeriodTotal(7);
    _reloadWeekSeries();
    if (widget.args.t == MetricType.water) {
      WaterIntakeService.revision.addListener(_onWaterIntakeRevision);
    }
  }

  void _onWaterIntakeRevision() {
    if (widget.args.t == MetricType.water) {
      _reloadWeekSeries();
    }
  }

  Future<void> _reloadWeekSeries() async {
    try {
      final rows = await _metricsRepo.getWeeklyMetrics();
      final map = <String, double>{};
      for (final row in rows) {
        final dateStr = row['date'] as String?;
        if (dateStr == null) continue;
        map[dateStr.split('T').first] =
            _metricValueFromRow(row, widget.args.t);
      }
      final data = _weekDates
          .map((d) => map[d.toIso8601String().split('T')[0]] ?? 0.0)
          .toList();

      // Water: always use shared local-first total (notification + in-app).
      if (widget.args.t == MetricType.water && data.isNotEmpty) {
        data[data.length - 1] =
            await WaterIntakeService.instance.getTodayLiters();
      } else if (data.isNotEmpty &&
          widget.args.w.isNotEmpty &&
          widget.args.w.last > data.last) {
        // Keep any higher today value already passed from home (live HC).
        data[data.length - 1] = widget.args.w.last;
      }

      if (!mounted) return;
      setState(() {
        _weekSeriesData = data;
        _weekSeriesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _weekSeriesLoading = false);
    }
  }

  @override
  void dispose() {
    if (widget.args.t == MetricType.water) {
      WaterIntakeService.revision.removeListener(_onWaterIntakeRevision);
    }
    super.dispose();
  }

  Future<void> _loadWaterReminderStatus() async {
    if (widget.args.t != MetricType.water) return;
    final label = await WaterReminderService.instance.statusLabel();
    if (mounted) setState(() => _waterReminderStatus = label);
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
      map[dateStr.split('T').first] = _metricValueFromRow(row, widget.args.t);
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
    final saved = await MetricGoalPickerSheet.show(
      context,
      metricType: widget.args.t,
      theme: theme,
      initialGoal: _currentGoal ?? widget.args.goal ?? 0.0,
    );
    if (saved == true && mounted) {
      await _loadGoal();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal updated')),
        );
      }
    }
  }

  Future<void> _showWaterReminderPicker(
    BuildContext context,
    InsightMetricTheme theme,
  ) async {
    final current = await WaterReminderService.instance.getIntervalMinutes();
    if (!context.mounted) return;
    final saved = await WaterReminderPickerSheet.show(
      context,
      theme: theme,
      initialMinutes: current > 0 ? current : 120,
    );
    if (saved == true && context.mounted) {
      await _loadWaterReminderStatus();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Water reminder updated')),
      );
    }
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
        return (
          data: _weekSeriesData,
          dates: _weekDates,
        );
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
    final selectedIndex = _selectedIndex ?? todayIndex;
    final selectedDate = dates[selectedIndex.clamp(0, dates.length - 1)];
    final selectedValue = data.isEmpty
        ? 0.0
        : data[selectedIndex.clamp(0, data.length - 1)];
    final selectedCompletion = goal != null && goal > 0
        ? (selectedValue / goal * 100).clamp(0.0, 999.0)
        : 0.0;
    final selectedDayLabel = formatInsightDayLabel(selectedDate);
    final selectedComparison =
        insightDayComparisonLabel(selectedIndex, data);
    final goalCompletion = _goalCompletionPct(data, goal);
    final comparisonLabel = _comparisonLabel(total, data);
    final aiBody = _aiInsightBody(theme, data, goal, comparisonLabel);

    final pageBg = InsightMetricTheme.pageBgOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: DesignTokens.accentOrange,
          backgroundColor: DesignTokens.surfaceOf(context),
          onRefresh: () async {
            await Future.wait([
              _loadGoal(),
              _loadWaterReminderStatus(),
              _reloadWeekSeries(),
              _loadPreviousPeriodTotal(_rangeDays[_rangeIndex]),
              _ensureRangeData(_rangeIndex),
            ]);
          },
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: isLight
                  ? ColoredBox(color: pageBg)
                  : ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: pageBg.withValues(alpha: 0.92),
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
                      style: AppTextStyles.screenTitle(context),
                    ),
                    Text(
                      _rangeLabels[_rangeIndex],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: DesignTokens.textSecondaryOf(context),
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
                        displayValue: selectedValue,
                        goal: goal,
                        completionPct: selectedCompletion,
                        comparisonLabel: selectedComparison,
                        dayLabel: selectedDayLabel,
                      ),
                    ),
                    if (theme.type == MetricType.water) ...[
                      const SizedBox(height: 10),
                      _WaterReminderRow(
                        theme: theme,
                        statusLabel: _waterReminderStatus,
                        onTap: () => _showWaterReminderPicker(context, theme),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await WaterReminderService.instance
                                  .showTestNotification();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Test water notification sent'
                                        : 'Notification permission denied',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bug_report_outlined, size: 18),
                            label: const Text('Send test water notification'),
                          ),
                        ),
                      ],
                    ],
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
                    if (widget.args.sourceNote != null &&
                        widget.args.sourceNote!.isNotEmpty &&
                        (theme.type == MetricType.calories ||
                            theme.type == MetricType.distance))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          widget.args.sourceNote!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: DesignTokens.textSecondaryOf(context),
                          ),
                        ),
                      ),
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
                    else if (_weekSeriesLoading && _rangeIndex == 0)
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
                          if (index == null) return;
                          if (_selectedIndex != index) {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedIndex = index);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedDayLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: DesignTokens.textPrimaryOf(context),
                                ),
                              ),
                            ),
                            Text(
                              insightValueWithUnit(theme.type, selectedValue),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              goal != null && goal > 0
                                  ? '${selectedCompletion.round()}%'
                                  : '—',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: DesignTokens.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      InsightDailyBreakdown(
                        theme: theme,
                        data: data,
                        dates: dates,
                        selectedIndex: selectedIndex.clamp(0, dates.length - 1),
                        onDaySelected: (index) {
                          if (_selectedIndex != index) {
                            setState(() => _selectedIndex = index);
                          }
                        },
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final inactive = DesignTokens.textSecondaryOf(context);
    final activeText = DesignTokens.textPrimaryOf(context);

    return InsightPremiumCard(
      radius: 22,
      color: InsightMetricTheme.surfaceCardOf(context),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _chip('Consumed', isConsumed, () => onChanged(true),
                isLight, inactive, activeText),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _chip('Burned', !isConsumed, () => onChanged(false),
                isLight, inactive, activeText),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    bool active,
    VoidCallback onTap,
    bool isLight,
    Color inactive,
    Color activeText,
  ) {
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
              color: active ? activeText : inactive,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterReminderRow extends StatelessWidget {
  final InsightMetricTheme theme;
  final String statusLabel;
  final VoidCallback onTap;

  const _WaterReminderRow({
    required this.theme,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final muted = DesignTokens.textSecondaryOf(context);
    final active = !statusLabel.toLowerCase().contains('off');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [
                      theme.accent.withValues(alpha: 0.14),
                      DesignTokens.lightMutedCardBackground,
                    ]
                  : const [
                      Color(0xFF163B5A),
                      Color(0xFF12263A),
                    ],
            ),
            border: Border.all(
              color: theme.accent.withValues(alpha: 0.28),
            ),
            boxShadow: InsightMetricTheme.cardShadowOf(context),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      theme.accent,
                      Color.lerp(theme.accent, Colors.white, 0.22)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Water reminder',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active ? statusLabel : 'Reminders are off',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? theme.accent.withValues(alpha: isLight ? 0.16 : 0.22)
                      : (isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? theme.accent.withValues(alpha: 0.45)
                        : InsightMetricTheme.borderColorOf(context),
                  ),
                ),
                child: Text(
                  active ? 'Edit' : 'Set up',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? theme.accent
                        : DesignTokens.textPrimaryOf(context),
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

