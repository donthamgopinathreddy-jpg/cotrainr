import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/metric_insight_types.dart';
import '../../theme/insight_metric_theme.dart';

// ─── Formatting helpers ───────────────────────────────────────────────────

String formatInsightValue(MetricType type, double value) {
  switch (type) {
    case MetricType.steps:
      return value.round().toString();
    case MetricType.water:
      return value.toStringAsFixed(1);
    case MetricType.calories:
      return value.round().toString();
    case MetricType.distance:
      return value.toStringAsFixed(1);
  }
}

String formatInsightGoal(MetricType type, double goal) {
  switch (type) {
    case MetricType.steps:
      return goal.round().toString();
    case MetricType.water:
      return '${goal.toStringAsFixed(1)} L';
    case MetricType.calories:
      return goal.round().toString();
    case MetricType.distance:
      return '${goal.toStringAsFixed(0)} km';
  }
}

String insightValueWithUnit(MetricType type, double value) {
  final v = formatInsightValue(type, value);
  return type == MetricType.water ? '$v L' : '$v ${InsightMetricTheme.from(type).unit}';
}

IconData metricInsightIcon(MetricType type) {
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

String weekdayLetter(int weekday) {
  const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return names[(weekday - 1).clamp(0, 6)];
}

// ─── Premium card shell ─────────────────────────────────────────────────────

class InsightPremiumCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final LinearGradient? gradient;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const InsightPremiumCard({
    super.key,
    required this.child,
    this.radius = 28,
    this.gradient,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (color ?? InsightMetricTheme.surfaceCard) : null,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: InsightMetricTheme.cardShadow(),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: padding,
      child: child,
    );
  }
}

// ─── Progress ring (Home-style, 700ms) ──────────────────────────────────────

class InsightProgressRing extends StatefulWidget {
  final double progress;
  final InsightMetricTheme theme;
  final IconData icon;
  final double size;

  const InsightProgressRing({
    super.key,
    required this.progress,
    required this.theme,
    required this.icon,
    this.size = 72,
  });

  @override
  State<InsightProgressRing> createState() => _InsightProgressRingState();
}

class _InsightProgressRingState extends State<InsightProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant InsightProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.theme.accent.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 6,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: ShaderMask(
                  shaderCallback: (r) =>
                      widget.theme.ringGradient.createShader(r),
                  child: CircularProgressIndicator(
                    value: _anim.value,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(widget.icon, color: widget.theme.accent, size: 22),
            ],
          ),
        );
      },
    );
  }
}

// ─── Hero card ──────────────────────────────────────────────────────────────

class InsightHeroCard extends StatelessWidget {
  final InsightMetricTheme theme;
  final double displayValue;
  final double? goal;
  final double completionPct;
  final String comparisonLabel;

  const InsightHeroCard({
    super.key,
    required this.theme,
    required this.displayValue,
    required this.goal,
    required this.completionPct,
    required this.comparisonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ringProgress = goal != null && goal! > 0
        ? (displayValue / goal!).clamp(0.0, 1.0)
        : 0.0;

    return InsightPremiumCard(
      gradient: theme.cardGradient,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: displayValue),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    return Text(
                      insightValueWithUnit(theme.type, v),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  goal != null
                      ? 'Goal: ${formatInsightGoal(theme.type, goal!)}'
                      : 'Goal: —',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${completionPct.round()}% Complete',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.accent.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  comparisonLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InsightProgressRing(
            progress: ringProgress,
            theme: theme,
            icon: metricInsightIcon(theme.type),
          ),
        ],
      ),
    );
  }
}

// ─── Range pills: 7D / 30D / 90D ───────────────────────────────────────────────

class InsightRangePills extends StatelessWidget {
  final int selectedIndex;
  final Color accent;
  final ValueChanged<int> onChanged;

  const InsightRangePills({
    super.key,
    required this.selectedIndex,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['7D', '30D', '90D'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: InsightMetricTheme.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                  border: selected
                      ? Border.all(color: accent.withValues(alpha: 0.35))
                      : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Graph card ─────────────────────────────────────────────────────────────

class InsightGraphCard extends StatelessWidget {
  final InsightMetricTheme theme;
  final List<double> data;
  final double? goal;
  final List<DateTime> dates;
  final int currentDayIndex;
  final int? selectedIndex;
  final ValueChanged<int?> onTouchIndex;

  const InsightGraphCard({
    super.key,
    required this.theme,
    required this.data,
    required this.goal,
    required this.dates,
    required this.currentDayIndex,
    required this.selectedIndex,
    required this.onTouchIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: theme.heroTag,
      child: InsightPremiumCard(
        radius: 24,
        color: InsightMetricTheme.graphCardBg,
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: SizedBox(
          height: 210,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return LineChart(
                _chartData(progress),
                duration: Duration.zero,
              );
            },
          ),
        ),
      ),
    );
  }

  LineChartData _chartData(double animProgress) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final y = data[i] * animProgress;
      spots.add(FlSpot(i.toDouble(), y));
    }
    final maxVal = data.isEmpty ? 1.0 : data.reduce(math.max);
    final yMax = math.max(maxVal, goal ?? 0) * 1.2;
    final yMaxLabel = yMax >= 1000
        ? '${(yMax / 1000).toStringAsFixed(1)}k'
        : yMax.toStringAsFixed(yMax < 10 ? 1 : 0);
    final highlight = selectedIndex ?? currentDayIndex;

    return LineChartData(
      minX: 0,
      maxX: math.max(data.length - 1, 1).toDouble(),
      minY: 0,
      maxY: yMax > 0 ? yMax : 1,
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (event, response) {
          onTouchIndex(response?.lineBarSpots?.firstOrNull?.spotIndex);
        },
        getTouchedSpotIndicator: (_, indexes) => indexes.map((index) {
          return TouchedSpotIndicatorData(
            FlLine(color: theme.accent.withValues(alpha: 0.35), strokeWidth: 1.5),
            FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 5,
                color: theme.accent,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
          );
        }).toList(),
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: const Color(0xFF232836),
          getTooltipItems: (touched) => touched.map((spot) {
            final idx = spot.x.toInt().clamp(0, dates.length - 1);
            final d = dates[idx];
            return LineTooltipItem(
              '${formatInsightValue(theme.type, spot.y)} ${theme.unit}\n${d.day}/${d.month}',
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yMax / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Colors.white.withValues(alpha: 0.06),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: yMax,
            getTitlesWidget: (v, _) {
              if ((v - yMax).abs() > 0.01) return const SizedBox.shrink();
              return Text(
                yMaxLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: data.length <= 14,
            interval: data.length > 14 ? 7 : 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= dates.length) return const SizedBox.shrink();
              final isToday = i == currentDayIndex;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${dates[i].day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday
                        ? theme.accent
                        : Colors.white.withValues(alpha: 0.4),
                  ),
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
          color: theme.accent,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, _, index) {
              final active = index == highlight;
              return FlDotCirclePainter(
                radius: active ? 4 : 0,
                color: active ? theme.accent : Colors.transparent,
                strokeWidth: active ? 2 : 0,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.accent.withValues(alpha: 0.22),
                theme.accent.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ],
      extraLinesData: goal == null
          ? ExtraLinesData()
          : ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: goal!,
                  color: theme.accent.withValues(alpha: 0.35),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.accent.withValues(alpha: 0.7),
                    ),
                    labelResolver: (_) => 'Goal',
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Daily breakdown bars ───────────────────────────────────────────────────

class InsightDailyBreakdown extends StatefulWidget {
  final InsightMetricTheme theme;
  final List<double> weekData;
  final List<DateTime> weekDates;
  final int highlightIndex;

  const InsightDailyBreakdown({
    super.key,
    required this.theme,
    required this.weekData,
    required this.weekDates,
    required this.highlightIndex,
  });

  @override
  State<InsightDailyBreakdown> createState() => _InsightDailyBreakdownState();
}

class _InsightDailyBreakdownState extends State<InsightDailyBreakdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.weekData.isEmpty
        ? 1.0
        : widget.weekData.reduce(math.max).clamp(0.001, double.infinity);

    return InsightPremiumCard(
      radius: 22,
      color: InsightMetricTheme.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.weekDates.length.clamp(0, 7), (i) {
          final frac = (widget.weekData.length > i ? widget.weekData[i] : 0) / max;
          final active = widget.weekData.length > i && widget.weekData[i] > 0;
          final highlighted = i == widget.highlightIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Text(
                    weekdayLetter(widget.weekDates[i].weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: highlighted
                          ? widget.theme.accent
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final h = 48 * frac * _ctrl.value;
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 10,
                          height: h.clamp(4, 48),
                          decoration: BoxDecoration(
                            color: active
                                ? widget.theme.accent.withValues(
                                    alpha: highlighted ? 1.0 : 0.55,
                                  )
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: highlighted && active
                                ? [
                                    BoxShadow(
                                      color: widget.theme.accent
                                          .withValues(alpha: 0.35),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Stats 2x2 ──────────────────────────────────────────────────────────────

class InsightStatsGrid extends StatelessWidget {
  final InsightMetricTheme theme;
  final double average;
  final double peak;
  final double total;
  final double goalCompletionPct;

  const InsightStatsGrid({
    super.key,
    required this.theme,
    required this.average,
    required this.peak,
    required this.total,
    required this.goalCompletionPct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                theme: theme,
                label: 'Average',
                value: formatInsightValue(theme.type, average),
                unit: theme.unit,
                delayMs: 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                theme: theme,
                label: 'Best Day',
                value: formatInsightValue(theme.type, peak),
                unit: theme.unit,
                delayMs: 80,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                theme: theme,
                label: 'Total',
                value: formatInsightValue(theme.type, total),
                unit: theme.unit,
                delayMs: 160,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                theme: theme,
                label: 'Goal Completion',
                value: '${goalCompletionPct.round()}',
                unit: '%',
                delayMs: 240,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final InsightMetricTheme theme;
  final String label;
  final String value;
  final String unit;
  final int delayMs;

  const _StatTile({
    required this.theme,
    required this.label,
    required this.value,
    required this.unit,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: InsightPremiumCard(
        radius: 20,
        color: InsightMetricTheme.surfaceCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 14,
              color: theme.accent.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
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

// ─── AI insight card ──────────────────────────────────────────────────────────

class InsightAiSummaryCard extends StatelessWidget {
  final InsightMetricTheme theme;
  final String body;

  const InsightAiSummaryCard({
    super.key,
    required this.theme,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: InsightPremiumCard(
        radius: 22,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.accent.withValues(alpha: 0.12),
            InsightMetricTheme.surfaceCard,
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 16, color: theme.accent),
                const SizedBox(width: 8),
                const Text(
                  'Weekly Insight',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class InsightEmptyState extends StatelessWidget {
  final InsightMetricTheme theme;

  const InsightEmptyState({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InsightPremiumCard(
      gradient: theme.cardGradient,
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              metricInsightIcon(theme.type),
              size: 36,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            const Text(
              'No data yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start tracking to unlock weekly insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
