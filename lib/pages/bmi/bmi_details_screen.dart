import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../profile/edit_profile_page.dart';

/// Args passed from Home BMI tile via go_router state.extra
class BmiDetailsArgs {
  final double bmi;
  final String bmiStatus;
  final double? heightCm;
  final double? weightKg;
  final String? gender;
  final int? age;

  const BmiDetailsArgs({
    required this.bmi,
    required this.bmiStatus,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.age,
  });
}

/// UI-only helper: compute BMI category from bmi value (no backend changes)
String _bmiCategoryFromValue(double bmi) {
  if (bmi == 0.0) return '';
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

/// UI-only: compute BMI from height and weight (for slider simulation)
double _simulateBmi(double heightCm, double weightKg) {
  if (heightCm <= 0 || weightKg <= 0) return 0.0;
  final h = heightCm / 100.0;
  return weightKg / (h * h);
}

class BmiDetailsScreen extends StatefulWidget {
  final BmiDetailsArgs args;

  const BmiDetailsScreen({super.key, required this.args});

  @override
  State<BmiDetailsScreen> createState() => _BmiDetailsScreenState();
}

class _BmiDetailsScreenState extends State<BmiDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _appBarAnimController;
  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;

  double _simulatedWeightKg = 0;
  int? _selectedMilestoneIndex;
  double? _goalWeightKg;

  @override
  void initState() {
    super.initState();
    final h = (widget.args.heightCm ?? 0) / 100.0;
    _simulatedWeightKg =
        widget.args.weightKg ?? (h > 0 ? 22 * h * h : 70);
    _appBarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _appBarFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _appBarAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _appBarSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _appBarAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _appBarAnimController.forward();
  }

  @override
  void dispose() {
    _appBarAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => context.pop(),
            ),
            title: null,
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _appBarFade,
              child: SlideTransition(
                position: _appBarSlide,
                child: _BmiAppBar(
                  onInfoTap: () => _showBmiInfoSheet(context),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _BmiFullScreenLayout(
              args: widget.args,
              simulatedWeightKg: _simulatedWeightKg,
              selectedMilestoneIndex: _selectedMilestoneIndex,
              goalWeightKg: _goalWeightKg,
              onWeightChanged: (w) =>
                  setState(() => _simulatedWeightKg = w),
              onMilestoneSelected: (idx, weightKg) {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedMilestoneIndex = idx;
                  _goalWeightKg = weightKg;
                });
              },
              onSetGoal: _handleSetGoal,
              onLogWeight: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfilePage(),
                ),
              ),
              onUpdateWeight: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfilePage(),
                ),
              ),
              onUpdateHeight: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfilePage(),
                ),
              ),
              onZoneTap: _showZoneSheet,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSetGoal() {
    final weight = _goalWeightKg ?? _simulatedWeightKg;
    if (weight <= 0) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Goal set: ${weight.toStringAsFixed(1)} kg'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBmiInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About BMI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Body Mass Index (BMI) is a measure of body fat based on height and weight. '
              'It provides a general indicator of whether your weight is healthy for your height.\n\n'
              '• Underweight: BMI below 18.5\n'
              '• Normal: BMI 18.5–24.9\n'
              '• Overweight: BMI 25–29.9\n'
              '• Obese: BMI 30 or above\n\n'
              'BMI is a screening tool and does not diagnose body fatness or health. '
              'Body composition, muscle mass, and other factors vary individually.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showZoneSheet(BuildContext context, int zoneIndex) {
    const zones = [
      ('Underweight', 'BMI below 18.5', 'Consider consulting a healthcare provider for nutrition guidance.'),
      ('Healthy', 'BMI 18.5–24.9', 'You\'re in the healthy range. Maintain balanced nutrition and activity.'),
      ('Overweight', 'BMI 25–29.9', 'Gradual weight loss through diet and exercise can improve health.'),
      ('Obese', 'BMI 30 or above', 'Consult a healthcare provider for a personalized plan.'),
    ];
    final z = zones[zoneIndex.clamp(0, 3)];
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              z.$1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              z.$2,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              z.$3,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── AppBar (minimal, modern) ───────────────────────────────────────────────

class _BmiAppBar extends StatelessWidget {
  final VoidCallback onInfoTap;

  const _BmiAppBar({required this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            'Body Mass Index',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryOf(context),
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onInfoTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 22,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BmiScaleBar (tappable zones) ─────────────────────────────────────────────

class BmiScaleBar extends StatefulWidget {
  final double progress;
  final double bmi;
  final void Function(int zoneIndex) onZoneTap;

  const BmiScaleBar({
    super.key,
    required this.progress,
    required this.bmi,
    required this.onZoneTap,
  });

  @override
  State<BmiScaleBar> createState() => _BmiScaleBarState();
}

class _BmiScaleBarState extends State<BmiScaleBar> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final indicatorLeft = widget.progress > 0 && widget.bmi > 0
                ? (barWidth * widget.progress.clamp(0.0, 1.0)) - 9
                : 0.0;

            return Column(
              children: [
                SizedBox(
                  height: 18,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
                        children: List.generate(4, (i) {
                          return Expanded(
                            child: _TapScaleZone(
                              onTap: () => widget.onZoneTap(i),
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: i < 3 ? 2 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: _zoneColor(i).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (widget.progress > 0 && widget.bmi > 0)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Positioned(
                              left: indicatorLeft * value,
                              top: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: _colorFromProgress(widget.progress),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _colorFromProgress(widget.progress).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TapLabel('<18.5', 0, context, widget.onZoneTap),
                    _TapLabel('18.5–24.9', 1, context, widget.onZoneTap),
                    _TapLabel('25–29.9', 2, context, widget.onZoneTap),
                    _TapLabel('≥30', 3, context, widget.onZoneTap),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Color _zoneColor(int i) {
    const colors = [
      Color(0xFF60A5FA), // blue
      Color(0xFF34D399), // emerald
      Color(0xFFFBBF24), // amber
      Color(0xFFF87171), // rose
    ];
    return colors[i.clamp(0, 3)];
  }
}

class _TapLabel extends StatefulWidget {
  final String text;
  final int zoneIndex;
  final BuildContext context;
  final void Function(int) onZoneTap;

  const _TapLabel(this.text, this.zoneIndex, this.context, this.onZoneTap);

  @override
  State<_TapLabel> createState() => _TapLabelState();
}

class _TapLabelState extends State<_TapLabel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => widget.onZoneTap(widget.zoneIndex),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

// ─── Tap scale feedback (micro-interaction) ──────────────────────────────────

class _TapScaleZone extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TapScaleZone({required this.onTap, required this.child});

  @override
  State<_TapScaleZone> createState() => _TapScaleZoneState();
}

class _TapScaleZoneState extends State<_TapScaleZone> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

// ─── Helper functions (used by BmiHeroCard, BmiScaleBar) ────────────────────

double _progressFromBmi(double bmi) {
  if (bmi < 18.5) {
    if (bmi <= 0) return 0.0;
    return (bmi / 18.5) * 0.25;
  } else if (bmi <= 24.9) {
    return 0.25 + ((bmi - 18.5) / (24.9 - 18.5)) * 0.25;
  } else if (bmi <= 29.9) {
    return 0.5 + ((bmi - 25.0) / (29.9 - 25.0)) * 0.25;
  } else {
    const maxBmi = 40.0;
    if (bmi >= maxBmi) return 1.0;
    return 0.75 + ((bmi - 30.0) / (maxBmi - 30.0)) * 0.25;
  }
}

Color _colorFromProgress(double progress) {
  const colors = [
    Color(0xFF60A5FA),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFF87171),
  ];
  const stops = [0.0, 0.25, 0.5, 0.75];
  final p = progress.clamp(0.0, 1.0);
  for (int i = 0; i < stops.length - 1; i++) {
    if (p <= stops[i + 1]) {
      final t = (p - stops[i]) / (stops[i + 1] - stops[i]);
      return Color.lerp(colors[i], colors[i + 1], t.clamp(0.0, 1.0))!;
    }
  }
  return colors.last;
}

String _formatHeight(double? heightCm) {
  if (heightCm == null || heightCm <= 0) return '--';
  final cm = heightCm.toInt();
  final totalInches = (heightCm / 2.54).round();
  final feet = totalInches ~/ 12;
  final inches = totalInches % 12;
  return '$cm cm / $feet\'$inches"';
}

String _formatWeight(double? weightKg) {
  if (weightKg == null || weightKg <= 0) return '--';
  final kg = weightKg.toStringAsFixed(1);
  final lbs = (weightKg / 0.453592).round();
  return '$kg kg / $lbs lbs';
}

// ─── Full-screen BMI layout (no 3D avatar) ────────────────────────────────────

class _BmiFullScreenLayout extends StatelessWidget {
  final BmiDetailsArgs args;
  final double simulatedWeightKg;
  final int? selectedMilestoneIndex;
  final double? goalWeightKg;
  final void Function(double) onWeightChanged;
  final void Function(int, double) onMilestoneSelected;
  final VoidCallback onSetGoal;
  final VoidCallback onLogWeight;
  final VoidCallback onUpdateWeight;
  final VoidCallback onUpdateHeight;
  final void Function(BuildContext, int) onZoneTap;

  const _BmiFullScreenLayout({
    required this.args,
    required this.simulatedWeightKg,
    required this.selectedMilestoneIndex,
    required this.goalWeightKg,
    required this.onWeightChanged,
    required this.onMilestoneSelected,
    required this.onSetGoal,
    required this.onLogWeight,
    required this.onUpdateWeight,
    required this.onUpdateHeight,
    required this.onZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _AnimatedSection(
            delay: 0,
            child: _BmiHeroFullWidth(
              args: args,
              onZoneTap: onZoneTap,
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedSection(
            delay: 80,
            child: _WeightSimulatorCard(
              args: args,
              simulatedWeightKg: simulatedWeightKg,
              onWeightChanged: onWeightChanged,
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedSection(
            delay: 160,
            child: HealthyRangeCard(
              args: args,
              selectedMilestoneIndex: selectedMilestoneIndex,
              goalWeightKg: goalWeightKg,
              simulatedWeightKg: simulatedWeightKg,
              onMilestoneSelected: onMilestoneSelected,
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedSection(
            delay: 240,
            child: TrendsCard(onLogWeightTap: onLogWeight),
          ),
          const SizedBox(height: 20),
          _AnimatedSection(
            delay: 320,
            child: QuickActionsGrid(
              args: args,
              goalWeightKg: goalWeightKg ?? simulatedWeightKg,
              selectedMilestoneIndex: selectedMilestoneIndex,
              onSetGoal: onSetGoal,
              onUpdateWeight: onUpdateWeight,
              onUpdateHeight: onUpdateHeight,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _AnimatedSection extends StatefulWidget {
  final int delay;
  final Widget child;

  const _AnimatedSection({required this.delay, required this.child});

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Opacity(
        opacity: _animation.value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - _animation.value)),
          child: widget.child,
        ),
      ),
    );
  }
}

class _BmiHeroFullWidth extends StatelessWidget {
  final BmiDetailsArgs args;
  final void Function(BuildContext, int) onZoneTap;

  const _BmiHeroFullWidth({
    required this.args,
    required this.onZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bmi = args.bmi;
    final progress = bmi > 0 ? _progressFromBmi(bmi) : 0.0;
    final statusColor = bmi > 0 ? _colorFromProgress(progress) : Colors.grey;
    final category =
        args.bmiStatus.isNotEmpty ? args.bmiStatus : _bmiCategoryFromValue(bmi);

    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card: gradient mesh, centered content
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: isDark ? 0.28 : 0.22),
                  statusColor.withValues(alpha: isDark ? 0.15 : 0.10),
                ],
              ),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Large display number
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: bmi > 0 ? bmi : 0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Semantics(
                    label: 'BMI value ${value.toStringAsFixed(1)}',
                    child: Text(
                      bmi > 0 ? value.toStringAsFixed(1) : '--',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        color: bmi > 0 ? statusColor : AppColors.textPrimaryOf(context),
                        height: 1.0,
                        letterSpacing: -3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (category.isNotEmpty)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, value, _) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: value,
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: statusColor.withValues(alpha: 0.95),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                BmiScaleBar(
                  progress: progress,
                  bmi: bmi,
                  onZoneTap: (idx) => onZoneTap(context, idx),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Bento-style metric row
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  icon: Icons.height_rounded,
                  label: 'Height',
                  value: _formatHeight(args.heightCm),
                  context: context,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricChip(
                  icon: Icons.monitor_weight_rounded,
                  label: 'Weight',
                  value: _formatWeight(args.weightKg),
                  context: context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightSimulatorCard extends StatefulWidget {
  final BmiDetailsArgs args;
  final double simulatedWeightKg;
  final void Function(double) onWeightChanged;

  const _WeightSimulatorCard({
    required this.args,
    required this.simulatedWeightKg,
    required this.onWeightChanged,
  });

  @override
  State<_WeightSimulatorCard> createState() => _WeightSimulatorCardState();
}

class _WeightSimulatorCardState extends State<_WeightSimulatorCard> {
  @override
  Widget build(BuildContext context) {
    final heightCm = widget.args.heightCm ?? 0;
    final heightM = heightCm / 100.0;
    final minKg = 40.0;
    final maxKg = heightM > 0
        ? (35 * heightM * heightM).clamp(60.0, 180.0)
        : 120.0;
    final rawWeight = (widget.simulatedWeightKg > 0
            ? widget.simulatedWeightKg
            : (heightM > 0 ? 22.0 * heightM * heightM : 70.0))
        .toDouble();
    final weight = rawWeight.clamp(minKg, maxKg);
    final simBmi = _simulateBmi(heightCm, weight);
    final simCategory = _bmiCategoryFromValue(simBmi);
    final progress = simBmi > 0 ? _progressFromBmi(simBmi) : 0.0;
    final simColor = _colorFromProgress(progress);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weight simulator',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                  letterSpacing: 0.2,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Container(
                  key: ValueKey(weight.toStringAsFixed(1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: simColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${weight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: simColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: simColor,
              inactiveTrackColor:
                  DesignTokens.textTertiaryOf(context).withValues(alpha: 0.25),
              thumbColor: simColor,
            ),
            child: Slider(
              value: weight,
              min: minKg,
              max: maxKg,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                widget.onWeightChanged(v);
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              'BMI ${simBmi.toStringAsFixed(1)} · $simCategory',
              key: ValueKey('$weight'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HealthyRangeCard ───────────────────────────────────────────────────────

class HealthyRangeCard extends StatelessWidget {
  final BmiDetailsArgs args;
  final int? selectedMilestoneIndex;
  final double? goalWeightKg;
  final double simulatedWeightKg;
  final void Function(int index, double weightKg) onMilestoneSelected;

  const HealthyRangeCard({
    super.key,
    required this.args,
    required this.selectedMilestoneIndex,
    required this.goalWeightKg,
    required this.simulatedWeightKg,
    required this.onMilestoneSelected,
  });

  @override
  Widget build(BuildContext context) {
    final heightCm = args.heightCm ?? 0;
    final heightM = heightCm / 100.0;

    if (heightM <= 0) {
      return _card(
        context,
        title: 'Healthy weight range',
        child: Text(
          'Add height to see your healthy weight range.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      );
    }

    final minKg = 18.5 * (heightM * heightM);
    final maxKg = 24.9 * (heightM * heightM);
    final midKg = 22.0 * (heightM * heightM);
    final leanKg = 20.0 * (heightM * heightM);
    final weight = args.weightKg ?? 0;

    String message;
    if (weight <= 0) {
      message =
          'Healthy range: ${minKg.toStringAsFixed(1)}–${maxKg.toStringAsFixed(1)} kg';
    } else if (weight < minKg) {
      final delta = minKg - weight;
      message = 'You are ${delta.toStringAsFixed(1)} kg below the healthy range';
    } else if (weight <= maxKg) {
      message = 'You are within the healthy range';
    } else {
      final delta = weight - maxKg;
      message = 'You are ${delta.toStringAsFixed(1)} kg above the healthy range';
    }

    final isUnderweight = (args.bmi > 0 && args.bmi < 18.5);
    final milestones = <({String label, double weightKg})>[
      (label: 'Reach 24.9 BMI', weightKg: maxKg),
      (label: 'Mid healthy (22 BMI)', weightKg: midKg),
      if (!isUnderweight) (label: 'Lean (20 BMI)', weightKg: leanKg),
    ];

    return _card(
      context,
      title: 'Healthy weight range',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${minKg.toStringAsFixed(1)}–${maxKg.toStringAsFixed(1)} kg',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Target ladder',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(milestones.length, (i) {
              final m = milestones[i];
              final isSelected = selectedMilestoneIndex == i;
              return _TapScaleZone(
                onTap: () => onMilestoneSelected(i, m.weightKg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.green.withValues(alpha: 0.2)
                        : DesignTokens.surfaceElevatedOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.green
                          : DesignTokens.borderColorOf(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${m.label} (${m.weightKg.toStringAsFixed(1)} kg)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context,
      {required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── TrendsCard ─────────────────────────────────────────────────────────────

class TrendsCard extends StatefulWidget {
  final VoidCallback onLogWeightTap;

  const TrendsCard({super.key, required this.onLogWeightTap});

  @override
  State<TrendsCard> createState() => _TrendsCardState();
}

class _TrendsCardState extends State<TrendsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bounceController.forward();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trends',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, value, _) {
                    return Transform.scale(
                      scale: value,
                      child: Icon(
                        Icons.show_chart,
                        size: 48,
                        color: DesignTokens.textTertiaryOf(context),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Log weight weekly to unlock trends',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onLogWeightTap,
                  icon: const Icon(Icons.add_chart_rounded, size: 20),
                  label: const Text('Log weight'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

// ─── QuickActionsGrid ────────────────────────────────────────────────────────

class QuickActionsGrid extends StatelessWidget {
  final BmiDetailsArgs args;
  final double goalWeightKg;
  final int? selectedMilestoneIndex;
  final VoidCallback onSetGoal;
  final VoidCallback onUpdateWeight;
  final VoidCallback onUpdateHeight;

  const QuickActionsGrid({
    super.key,
    required this.args,
    required this.goalWeightKg,
    required this.selectedMilestoneIndex,
    required this.onSetGoal,
    required this.onUpdateWeight,
    required this.onUpdateHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isOverweight = args.bmi >= 25;
    final isUnderweight = args.bmi > 0 && args.bmi < 18.5;

    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      if (isOverweight)
        (label: 'Set Healthy Target', icon: Icons.flag, onTap: onSetGoal)
      else if (isUnderweight)
        (label: 'Gain Weight Target', icon: Icons.trending_up, onTap: onSetGoal)
      else
        (label: 'Set Goal', icon: Icons.flag, onTap: onSetGoal),
      (label: 'Update Weight', icon: Icons.monitor_weight, onTap: onUpdateWeight),
      (label: 'Update Height', icon: Icons.height, onTap: onUpdateHeight),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryOf(context),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.map((a) {
            return _ActionButton(
              label: a.label,
              icon: a.icon,
              onTap: a.onTap,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: DesignTokens.interactionDuration,
        curve: DesignTokens.interactionCurve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: DesignTokens.borderColorOf(context),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 18, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _MetricChip (modern pill) ──────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final BuildContext context;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
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
