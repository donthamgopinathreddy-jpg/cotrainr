import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
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
  final List<double> weekly;

  const UnifiedMetricViewModel({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.ringGradient,
    required this.barColor,
    required this.progress,
    required this.mainValue,
    required this.subValue,
    required this.weekly,
  });
}

/// Premium centered metrics carousel + weekly chart (WHOOP / Runna–style focus).
class UnifiedMetricsTileV3 extends StatefulWidget {
  final List<UnifiedMetricViewModel> metrics;
  final ValueChanged<int> onMetricTap;
  final VoidCallback? onAddWater;

  const UnifiedMetricsTileV3({
    super.key,
    required this.metrics,
    required this.onMetricTap,
    this.onAddWater,
  }) : assert(metrics.length == 4);

  @override
  State<UnifiedMetricsTileV3> createState() => _UnifiedMetricsTileV3State();
}

class _UnifiedMetricsTileV3State extends State<UnifiedMetricsTileV3> {
  static const int _kLoopLength = 40000;
  static const int _kInitialPage = 20000;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    assert(_kInitialPage % 4 == 0);
    _pageController = PageController(
      viewportFraction: 0.78,
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
          final tileGradient = _tileGradientForPage(page, isLight);
          final focusPalette = HomePremiumTheme.metricPalette(focus, isLight);

          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: isLight ? 6 : 14,
                sigmaY: isLight ? 6 : 14,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: tileGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This week',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: HomePremiumTheme.secondaryText(isLight),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onMetricTap(_focusMetricIndex(_page));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.label,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      letterSpacing: -0.35,
                                      color: HomePremiumTheme.primaryText(isLight),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.mainValue} ${m.subValue}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: HomePremiumTheme.secondaryText(isLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurfaceVariant,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, c) {
                      final h = (c.maxWidth * 0.32).clamp(90.0, 108.0);
                      return SizedBox(
                        height: h,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _kLoopLength,
                          padEnds: true,
                          clipBehavior: Clip.hardEdge,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: _realignLoopIfNeeded,
                          itemBuilder: (context, index) {
                            final logical = index % 4;
                            final item = widget.metrics[logical];
                            final dist = (page - index).abs();
                            final t = _focusT(dist);
                            final scale = lerpDouble(0.78, 1.0, t)!;
                            final opacity = lerpDouble(0.32, 1.0, t)!;
                            final isSelected = dist < 0.48;
                            final displayIcon = isSelected
                                ? (item.selectedIcon ?? item.icon)
                                : item.icon;
                            final blur = ((1.0 - t) * 3.2).clamp(0.0, 4.0);
                            final slideY = (1.0 - t) * 10.0;

                            Widget core = GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _animateToLogicalMetric(logical);
                              },
                              child: Center(
                                child: Transform.translate(
                                  offset: Offset(0, slideY),
                                  child: Transform.scale(
                                    scale: scale,
                                    alignment: Alignment.center,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: MetricCenterWidget(
                                        metricIndex: logical,
                                        icon: displayIcon,
                                        progress:
                                            item.progress.clamp(0.0, 1.0),
                                        label: item.label,
                                        mainValue: item.mainValue,
                                        subValue: item.subValue,
                                        selected: isSelected,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                            if (blur > 0.5) {
                              core = ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blur,
                                  sigmaY: blur,
                                ),
                                child: core,
                              );
                            }
                            return core;
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
                    highlightDayIndex: _todayWeekIndex(),
                    isLight: isLight,
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

  /// Monday-first row M…S → index 0 = Monday.
  static int _todayWeekIndex() {
    final w = DateTime.now().weekday;
    return w - 1;
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
  final bool isLight;

  const _WeeklyBarChart({
    super.key,
    required this.values,
    required this.barColor,
    required this.trackColor,
    required this.labelColor,
    required this.highlightDayIndex,
    required this.isLight,
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
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: isToday ? 7 : 6,
                              height: chartHeight,
                              decoration: BoxDecoration(
                                color: widget.trackColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Container(
                              width: isToday ? 7 : 6,
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
                                boxShadow: isToday
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
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(7, (i) {
                final isToday = i == widget.highlightDayIndex;
                return Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isToday ? 11 : 10,
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.15,
                      color: isToday
                          ? widget.barColor
                          : widget.labelColor.withValues(alpha: 0.82),
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
