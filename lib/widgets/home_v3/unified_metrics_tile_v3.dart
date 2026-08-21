import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../common/animated_number.dart';
import '../common/shimmer_skeleton.dart';
import 'home_premium_theme.dart';
import 'metric_center_widget.dart';

/// One of four home metrics (order: steps, calories, water, distance).
class UnifiedMetricViewModel {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final LinearGradient ringGradient;
  final Color barColor;
  final double progress;
  final String mainValue;
  final String subValue;
  final String? sourceNote;
  final List<double> weekly;
  /// Numeric today value (for weekly day tap display).
  final double todayValue;
  /// Numeric goal (same unit as [todayValue] / weekly entries).
  final double goalValue;

  const UnifiedMetricViewModel({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.ringGradient,
    required this.barColor,
    required this.progress,
    required this.mainValue,
    required this.subValue,
    this.sourceNote,
    required this.weekly,
    required this.todayValue,
    required this.goalValue,
  });
}

/// Premium centered metrics carousel + weekly chart (WHOOP / Runna–style focus).
class UnifiedMetricsTileV3 extends StatefulWidget {
  final List<UnifiedMetricViewModel> metrics;
  final ValueChanged<int> onMetricTap;
  final VoidCallback? onAddWater;
  final bool goalsLoading;

  const UnifiedMetricsTileV3({
    super.key,
    required this.metrics,
    required this.onMetricTap,
    this.onAddWater,
    this.goalsLoading = false,
  }) : assert(metrics.length == 4);

  @override
  State<UnifiedMetricsTileV3> createState() => _UnifiedMetricsTileV3State();
}

class _UnifiedMetricsTileV3State extends State<UnifiedMetricsTileV3> {
  static const int _kLoopLength = 40000;
  static const int _kInitialPage = 20000;
  static const double _chartBarInset = 4.0;
  static const int _chartDayCount = 7;
  static const double _defaultBarWidth = 6.0;
  static const double _todayBarWidth = 7.0;
  /// Nudges ring left from Sunday bar center in the metrics row.
  static const double _ringShiftLeft = 36.0;

  static double _chartBarWidth(int dayIndex, int todayIndex) =>
      dayIndex == todayIndex ? _todayBarWidth : _defaultBarWidth;

  /// Horizontal center of a day column bar (matches [_WeeklyBarChart] layout).
  static double _chartBarCenterX(double chartWidth, int dayIndex, int todayIndex) {
    final cell = chartWidth / _chartDayCount;
    final inner = cell - 2 * _chartBarInset;
    return dayIndex * cell + _chartBarInset + inner / 2;
  }

  static double _chartBarLeftX(double chartWidth, int dayIndex, int todayIndex) =>
      _chartBarCenterX(chartWidth, dayIndex, todayIndex) -
      _chartBarWidth(dayIndex, todayIndex) / 2;

  late final PageController _pageController;
  int? _selectedWeekDayIndex;
  int _lastFocusMetric = 0;

  @override
  void initState() {
    super.initState();
    assert(_kInitialPage % 4 == 0);
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: _kInitialPage,
      keepPage: true,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _page => _pageController.hasClients
      ? (_pageController.page ?? _kInitialPage.toDouble())
      : _kInitialPage.toDouble();

  static int _focusMetricIndex(double page) {
    final r = page.round();
    return ((r % 4) + 4) % 4;
  }

  static double _metricPhase(double page) {
    var x = page % 4.0;
    if (x < 0) x += 4.0;
    return x;
  }

  LinearGradient _tileGradientForPage(double page, bool isLight) {
    final phase = _metricPhase(page);
    final accents = List.generate(
      4,
      (i) => HomePremiumTheme.metricPalette(i, isLight).accent,
    );
    return HomePremiumTheme.metricsTileGradient(
      _focusMetricIndex(page),
      phase,
      accents,
      isLight,
    );
  }

  void _realignLoopIfNeeded(int page) {
    const margin = 800;
    if (page >= margin && page < _kLoopLength - margin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final logical = ((page % 4) + 4) % 4;
      final mid = _kLoopLength ~/ 2;
      final aligned = mid - (mid % 4) + logical;
      _pageController.jumpToPage(aligned);
    });
  }

  void _animateToLogicalMetric(int logicalIndex) {
    setState(() => _selectedWeekDayIndex = null);
    final pos = _pageController.page ?? _pageController.initialPage.toDouble();
    final p = pos.round();
    final at = ((p % 4) + 4) % 4;
    final alignedBase = p - at;
    final target = alignedBase + logicalIndex;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Smooth t: 1 at center, ~0 far — tuned for premium focus (not linear).
  static double _focusT(double dist) {
    final x = (1.0 - (dist * 1.35).clamp(0.0, 1.0));
    return Curves.easeInOutCubic.transform(x);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.goalsLoading) {
      return const ShimmerBox(height: 248, radius: 28);
    }

    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, _) {
          final page = _page;
          final focus = _focusMetricIndex(page);
          final m = widget.metrics[focus];
          final weekly = _normalizeSeven(m.weekly);
          final focusDisplay = _displayForMetric(
            m,
            focus,
            dayIndex: _selectedWeekDayIndex,
          );
          final chartHighlight =
              _selectedWeekDayIndex ?? _todayWeekIndex();
          final tileGradient = _tileGradientForPage(page, isLight);
          final focusPalette = HomePremiumTheme.metricPalette(focus, isLight);

          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: isLight ? 2 : 14,
                sigmaY: isLight ? 2 : 14,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: tileGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chartW = constraints.maxWidth;
                      final today = _todayWeekIndex();
                      final mondayLeft = _chartBarLeftX(chartW, 0, today);
                      return Padding(
                        padding: EdgeInsets.only(left: mondayLeft),
                        child: Text(
                          'Last 7 days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: HomePremiumTheme.secondaryText(isLight),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chartW = constraints.maxWidth;
                      final today = _todayWeekIndex();
                      final mondayLeft = _chartBarLeftX(chartW, 0, today);
                      final sundayCenter = _chartBarCenterX(chartW, 6, today);

                      return SizedBox(
                        height: 96,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _kLoopLength,
                          padEnds: false,
                          clipBehavior: Clip.hardEdge,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (page) {
                            final newFocus = _focusMetricIndex(page.toDouble());
                            if (newFocus != _lastFocusMetric) {
                              setState(() {
                                _lastFocusMetric = newFocus;
                                _selectedWeekDayIndex = null;
                              });
                            }
                            _realignLoopIfNeeded(page);
                          },
                          itemBuilder: (context, index) {
                            final logical = index % 4;
                            final item = widget.metrics[logical];
                            final dist = (page - index).abs();
                            final t = _focusT(dist);
                            final opacity = lerpDouble(0.45, 1.0, t)!;
                            final isSelected = dist < 0.48;
                            final displayIcon = isSelected
                                ? (item.selectedIcon ?? item.icon)
                                : item.icon;
                            final ringSize = isSelected ? 92.0 : 72.0;
                            final display = isSelected && logical == focus
                                ? focusDisplay
                                : (
                                    mainValue: item.mainValue,
                                    subValue: item.subValue,
                                    progress: item.progress,
                                    progressPercent: item.goalValue > 0
                                        ? (item.todayValue / item.goalValue) *
                                            100
                                        : 0.0,
                                    sourceNote: item.sourceNote,
                                    numericValue: item.todayValue,
                                  );

                            return Opacity(
                              opacity: opacity,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (isSelected) {
                                      widget.onMetricTap(logical);
                                    } else {
                                      _animateToLogicalMetric(logical);
                                    }
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: mondayLeft,
                                        right: chartW -
                                            sundayCenter +
                                            ringSize / 2 -
                                            _ringShiftLeft +
                                            8,
                                        top: 4,
                                        bottom: 4,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      isSelected ? 13 : 12,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.6,
                                                  color: HomePremiumTheme
                                                      .secondaryText(isLight),
                                                ),
                                              ),
                                              SizedBox(
                                                  height: isSelected ? 4 : 3),
                                              display.mainValue == '—' ||
                                                      display.mainValue == '--'
                                                  ? Text(
                                                      display.mainValue,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: isSelected
                                                            ? 26
                                                            : 22,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        height: 1.0,
                                                        letterSpacing: -0.5,
                                                        color: HomePremiumTheme
                                                            .primaryText(
                                                                isLight),
                                                      ),
                                                    )
                                                  : AnimatedNumber(
                                                      value:
                                                          display.numericValue,
                                                      format: (v) =>
                                                          _formatMainValue(
                                                              logical, v),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: isSelected
                                                            ? 26
                                                            : 22,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        height: 1.0,
                                                        letterSpacing: -0.5,
                                                        color: HomePremiumTheme
                                                            .primaryText(
                                                                isLight),
                                                      ),
                                                    ),
                                              SizedBox(
                                                  height: isSelected ? 3 : 2),
                                              Text(
                                                display.subValue,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      isSelected ? 12 : 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: HomePremiumTheme
                                                      .secondaryText(isLight),
                                                ),
                                              ),
                                              if (display.sourceNote != null &&
                                                  display
                                                      .sourceNote!.isNotEmpty) ...[
                                                SizedBox(
                                                    height:
                                                        isSelected ? 2 : 1),
                                                Text(
                                                  display.sourceNote!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSelected ? 10 : 9,
                                                    fontWeight: FontWeight.w500,
                                                  color: HomePremiumTheme
                                                      .secondaryText(isLight)
                                                      .withValues(alpha: 0.75),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        ),
                                      ),
                                      Positioned(
                                        left: sundayCenter -
                                            ringSize / 2 -
                                            _ringShiftLeft,
                                        top: (96 - ringSize) / 2,
                                        width: ringSize,
                                        height: ringSize,
                                        child: MetricCenterWidget(
                                          metricIndex: logical,
                                          icon: displayIcon,
                                          progressPercent: isSelected &&
                                                  logical == focus
                                              ? focusDisplay.progressPercent
                                              : (item.goalValue > 0
                                                  ? (item.todayValue /
                                                          item.goalValue) *
                                                      100
                                                  : 0.0),
                                          selected: isSelected,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _WeeklyBarChart(
                    key: ValueKey<int>(focus),
                    values: weekly,
                    barColor: focusPalette.accent,
                    trackColor: HomePremiumTheme.weeklyTrackColor(isLight),
                    labelColor: HomePremiumTheme.secondaryText(isLight),
                    highlightDayIndex: chartHighlight,
                    selectedDayIndex: _selectedWeekDayIndex,
                    isLight: isLight,
                    onDayTap: (dayIndex) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedWeekDayIndex == dayIndex) {
                          _selectedWeekDayIndex = null;
                        } else {
                          _selectedWeekDayIndex = dayIndex;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _MetricPageDots(
                    count: 4,
                    activeIndex: focus,
                    color: HomePremiumTheme.secondaryText(isLight),
                    accent: focusPalette.accent,
                  ),
                  if (focus == 2) ...[
                    const SizedBox(height: 10),
                    _AddWaterChip(
                      onTap: widget.onAddWater,
                      colorScheme: cs,
                    ),
                  ],
                ],
              ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Rolling last-7 series: index 0 = 6 days ago, index 6 = today.
  static int _todayWeekIndex() => 6;

  /// Weekday short labels aligned to rolling last-7 data (not calendar Mon–Sun).
  static List<String> _rollingWeekDayLabels() {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return names[d.weekday - 1];
    });
  }

  static List<String> _rollingWeekDayInitials() {
    const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return initials[d.weekday - 1];
    });
  }

  static String _formatMainValue(int metricIndex, double value) {
    switch (metricIndex) {
      case 0:
        final steps = value.round();
        return steps >= 1000
            ? '${(steps / 1000).toStringAsFixed(1)}k'
            : '$steps';
      case 1:
        return value.round().toString();
      case 2:
      case 3:
        return value.toStringAsFixed(1);
      default:
        return value.toStringAsFixed(0);
    }
  }

  static String _formatGoalFragment(int metricIndex, double goal) {
    switch (metricIndex) {
      case 0:
        final g = goal.round();
        return g >= 1000 ? '${(g / 1000).toStringAsFixed(1)}k' : '$g';
      case 1:
        return goal.round().toString();
      case 2:
      case 3:
        return goal.toStringAsFixed(1);
      default:
        return goal.toStringAsFixed(0);
    }
  }

  static String _subValueForDay(
    UnifiedMetricViewModel item,
    int metricIndex,
    int dayIndex,
    double dayValue,
  ) {
    final label = _rollingWeekDayLabels()[dayIndex.clamp(0, 6)];
    final goalFrag = _formatGoalFragment(metricIndex, item.goalValue);
    switch (metricIndex) {
      case 0:
        return '$label · of $goalFrag steps';
      case 1:
        return '$label · $goalFrag kcal goal';
      case 2:
        return '$label · of $goalFrag L';
      case 3:
        return '$label · $goalFrag km goal';
      default:
        return label;
    }
  }

  ({
    String mainValue,
    String subValue,
    double progress,
    double progressPercent,
    String? sourceNote,
    double numericValue,
  }) _displayForMetric(
    UnifiedMetricViewModel item,
    int metricIndex, {
    int? dayIndex,
  }) {
    final today = _todayWeekIndex();
    if (dayIndex == null) {
      final pct = item.goalValue > 0
          ? (item.todayValue / item.goalValue) * 100
          : 0.0;
      return (
        mainValue: item.mainValue,
        subValue: item.subValue,
        progress: item.progress,
        progressPercent: pct,
        sourceNote: item.sourceNote,
        numericValue: item.todayValue,
      );
    }

    final weekly = _normalizeSeven(item.weekly);
    final value = weekly[dayIndex.clamp(0, 6)];
    final progress = item.goalValue > 0
        ? (value / item.goalValue).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = item.goalValue > 0
        ? (value / item.goalValue) * 100
        : 0.0;

    return (
      mainValue: _formatMainValue(metricIndex, value),
      subValue: _subValueForDay(item, metricIndex, dayIndex, value),
      progress: progress,
      progressPercent: progressPercent,
      sourceNote: dayIndex == today ? item.sourceNote : null,
      numericValue: value,
    );
  }

  static List<double> _normalizeSeven(List<double> raw) {
    if (raw.isEmpty) return List.filled(7, 0);
    final copy = List<double>.from(raw);
    while (copy.length < 7) {
      copy.insert(0, 0);
    }
    if (copy.length > 7) {
      return copy.sublist(copy.length - 7);
    }
    return copy;
  }
}

class _MetricPageDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final Color color;
  final Color accent;

  const _MetricPageDots({
    required this.count,
    required this.activeIndex,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: on ? accent : color.withValues(alpha: 0.28),
          ),
        );
      }),
    );
  }
}

class _WeeklyBarChart extends StatefulWidget {
  final List<double> values;
  final Color barColor;
  final Color trackColor;
  final Color labelColor;
  final int highlightDayIndex;
  final int? selectedDayIndex;
  final bool isLight;
  final ValueChanged<int>? onDayTap;

  const _WeeklyBarChart({
    super.key,
    required this.values,
    required this.barColor,
    required this.trackColor,
    required this.labelColor,
    required this.highlightDayIndex,
    this.selectedDayIndex,
    required this.isLight,
    this.onDayTap,
  });

  @override
  State<_WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<_WeeklyBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _WeeklyBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values ||
        oldWidget.barColor != widget.barColor) {
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = _UnifiedMetricsTileV3State._rollingWeekDayInitials();
    final maxV = widget.values.isEmpty
        ? 1.0
        : widget.values.reduce((a, b) => a > b ? a : b).clamp(0.001, double.infinity);
    const chartHeight = 62.0;
    const minBar = 4.0;
    const usable = chartHeight - minBar;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final k = Curves.easeOutCubic.transform(_anim.value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final v = i < widget.values.length ? widget.values[i] : 0.0;
                  final targetH =
                      minBar + (usable * (v / maxV)).clamp(0.0, usable);
                  final h = targetH * k;
                  final isToday = i == widget.highlightDayIndex;
                  final isSelected = widget.selectedDayIndex == i;
                  final barWidth = isSelected || isToday ? 7.0 : 6.0;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onDayTap == null
                          ? null
                          : () => widget.onDayTap!(i),
                      child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _UnifiedMetricsTileV3State._chartBarInset,
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: barWidth,
                              height: chartHeight,
                              decoration: BoxDecoration(
                                color: widget.trackColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Container(
                              width: barWidth,
                              height: h.clamp(minBar, chartHeight),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    widget.barColor.withValues(alpha: 0.88),
                                    widget.barColor.withValues(alpha: 0.55),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                  bottom: Radius.circular(3),
                                ),
                                boxShadow: isSelected || isToday
                                    ? [
                                        BoxShadow(
                                          color: widget.barColor.withValues(
                                            alpha: widget.isLight ? 0.28 : 0.38,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(7, (i) {
                final isToday = i == widget.highlightDayIndex &&
                    widget.selectedDayIndex == null;
                final isSelected = widget.selectedDayIndex == i;
                final emphasized = isToday || isSelected;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDayTap == null
                        ? null
                        : () => widget.onDayTap!(i),
                    child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: emphasized ? 11 : 10,
                      fontWeight:
                          emphasized ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.15,
                      color: emphasized
                          ? widget.barColor
                          : widget.labelColor.withValues(alpha: 0.82),
                    ),
                  ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _AddWaterChip extends StatelessWidget {
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _AddWaterChip({
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.blue.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: AppColors.blue),
                const SizedBox(width: 6),
                Text(
                  '250 ml',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
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
