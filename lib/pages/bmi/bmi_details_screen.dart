import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/home_v3/bmi_card_v3.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../theme/text_styles.dart';

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

// ─── BMI helpers ─────────────────────────────────────────────────────────────

String bmiCategoryFromValue(double bmi) {
  if (bmi <= 0) return '';
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

double bmiFromHeightWeight(double heightCm, double weightKg) {
  if (heightCm <= 0 || weightKg <= 0) return 0;
  final h = heightCm / 100.0;
  return weightKg / (h * h);
}

double bmiProgress(double bmi) {
  if (bmi < 18.5) return bmi <= 0 ? 0 : (bmi / 18.5) * 0.25;
  if (bmi <= 24.9) return 0.25 + ((bmi - 18.5) / 6.4) * 0.25;
  if (bmi <= 29.9) return 0.5 + ((bmi - 25.0) / 4.9) * 0.25;
  const maxBmi = 40.0;
  if (bmi >= maxBmi) return 1.0;
  return 0.75 + ((bmi - 30.0) / 10.0) * 0.25;
}

({double minKg, double maxKg, double targetKg}) healthyWeights(double heightCm) {
  final h = heightCm / 100.0;
  final minKg = 18.5 * h * h;
  final maxKg = 24.9 * h * h;
  return (minKg: minKg, maxKg: maxKg, targetKg: maxKg);
}

String formatHeight(double? cm) {
  if (cm == null || cm <= 0) return '--';
  final totalIn = (cm / 2.54).round();
  return '${cm.round()} cm / ${totalIn ~/ 12}\'${totalIn % 12}"';
}

String formatWeightKg(double? kg) {
  if (kg == null || kg <= 0) return '--';
  return '${kg.toStringAsFixed(1)} kg';
}

String healthyRangeMessage(double bmi, double weightKg, double minKg, double maxKg) {
  if (weightKg <= 0) return 'Add weight to see your progress';
  if (bmi >= 18.5 && bmi <= 24.9) return 'You are in the healthy range';
  if (weightKg > maxKg) {
    return '${(weightKg - maxKg).toStringAsFixed(1)} kg away from healthy range';
  }
  return '${(minKg - weightKg).toStringAsFixed(1)} kg away from healthy range';
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class BmiDetailsScreen extends StatefulWidget {
  final BmiDetailsArgs args;

  const BmiDetailsScreen({super.key, required this.args});

  @override
  State<BmiDetailsScreen> createState() => _BmiDetailsScreenState();
}

class _BmiDetailsScreenState extends State<BmiDetailsScreen>
    with SingleTickerProviderStateMixin {
  late double _simWeightKg;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _simWeightKg = widget.args.weightKg ?? 0;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    );
    _pulseAnim = const AlwaysStoppedAnimation<double>(1);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? HomePremiumTheme.lightWarmBg : HomePremiumTheme.darkCharcoal;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: bg.withValues(alpha: 0.92),
            elevation: 0,
            leading: CotrainrBackButton(
              color: HomePremiumTheme.primaryText(isLight),
            ),
            title: Text(
              'BMI Details',
              style: AppTextStyles.screenTitle(
                context,
                color: HomePremiumTheme.primaryText(isLight),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _BmiHeroCard(args: widget.args, pulseAnim: _pulseAnim),
                const SizedBox(height: 12),
                _BmiRangeVisual(
                  bmi: widget.args.bmi,
                  pulseAnim: _pulseAnim,
                ),
                const SizedBox(height: 12),
                _BodyInfoRow(args: widget.args),
                const SizedBox(height: 12),
                _HealthyRangeCard(args: widget.args),
                const SizedBox(height: 12),
                if ((widget.args.weightKg ?? 0) > 0 &&
                    (widget.args.heightCm ?? 0) > 0) ...[
                  _WeightGoalSimulator(
                    args: widget.args,
                    simWeightKg: _simWeightKg,
                    onWeightChanged: (w) {
                      HapticFeedback.selectionClick();
                      setState(() => _simWeightKg = w);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const _BmiEducationAccordion(),
                const SizedBox(height: 12),
                const _BmiDisclaimerCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Premium card shell ────────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;
  final int delayMs;

  const _PremiumCard({
    required this.child,
    this.gradient,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null
              ? (isLight
                  ? HomePremiumTheme.lightCreamCard
                  : HomePremiumTheme.darkCard)
              : null,
          borderRadius: BorderRadius.circular(28),
          boxShadow: HomePremiumTheme.softCardShadow(isLight),
          border: Border.all(
            color: isLight
                ? HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─── Section 1: Hero ─────────────────────────────────────────────────────────

class _BmiHeroCard extends StatelessWidget {
  final BmiDetailsArgs args;
  final Animation<double> pulseAnim;

  const _BmiHeroCard({required this.args, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bmi = args.bmi;
    final progress = bmi > 0 ? bmiProgress(bmi) : 0.0;
    final accent = bmi > 0
        ? BmiMeterColors.fromProgress(progress)
        : HomePremiumTheme.secondaryText(isLight);
    final status = args.bmiStatus.isNotEmpty
        ? args.bmiStatus
        : bmiCategoryFromValue(bmi);

    final heightCm = args.heightCm ?? 0;
    final weightKg = args.weightKg ?? 0;
    String subline = '';
    if (heightCm > 0 && weightKg > 0) {
      final range = healthyWeights(heightCm);
      subline = healthyRangeMessage(bmi, weightKg, range.minKg, range.maxKg);
    }

    return _PremiumCard(
      delayMs: 0,
      gradient: HomePremiumTheme.bmiTileGradient(isLight, accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BMI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomePremiumTheme.secondaryText(isLight),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: bmi > 0 ? bmi : 0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return Text(
                bmi > 0 ? v.toStringAsFixed(1) : '--',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: HomePremiumTheme.primaryText(isLight),
                  height: 1.0,
                  letterSpacing: -1.5,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (status.isNotEmpty)
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          if (subline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section 2: Range visual ─────────────────────────────────────────────────

class _BmiRangeVisual extends StatelessWidget {
  final double bmi;
  final Animation<double> pulseAnim;

  const _BmiRangeVisual({required this.bmi, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return _PremiumCard(
      delayMs: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BMI Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          const SizedBox(height: 16),
          _BmiRangeBar(
            bmi: bmi,
            pulseAnim: pulseAnim,
            showYouLabel: true,
          ),
        ],
      ),
    );
  }
}

class _BmiRangeBar extends StatelessWidget {
  final double bmi;
  final Animation<double> pulseAnim;
  final bool showYouLabel;
  final bool animateDot;

  const _BmiRangeBar({
    required this.bmi,
    required this.pulseAnim,
    this.showYouLabel = true,
    this.animateDot = true,
  });

  static const _zones = ['Underweight', 'Normal', 'Overweight', 'Obese'];
  static const _zoneColors = [
    Color(0xFF3FA9F5),
    Color(0xFF22C55E),
    Color(0xFFFACC15),
    Color(0xFFFF5A5A),
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final progress = bmi > 0 ? bmiProgress(bmi) : 0.0;
    final dotColor = bmi > 0
        ? BmiMeterColors.fromProgress(progress)
        : Colors.grey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final dotLeft = (w * progress.clamp(0.02, 0.98)) - 8;

        return Column(
          children: [
            SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: List.generate(4, (i) {
                      return Expanded(
                        child: Container(
                          height: 14,
                          margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
                          decoration: BoxDecoration(
                            color: _zoneColors[i].withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (bmi > 0)
                    animateDot
                        ? TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: dotLeft),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, left, _) =>
                                _buildDot(left, dotColor, pulseAnim),
                          )
                        : _buildDot(dotLeft, dotColor, pulseAnim),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(4, (i) {
                return Expanded(
                  child: Text(
                    _zones[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: HomePremiumTheme.secondaryText(isLight),
                    ),
                  ),
                );
              }),
            ),
            if (showYouLabel && bmi > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You · Current BMI: ${bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HomePremiumTheme.primaryText(isLight),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDot(double left, Color dotColor, Animation<double> pulse) {
    return Positioned(
      left: left,
      top: -3,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return Transform.scale(scale: pulse.value, child: child);
        },
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section 3: Body info ────────────────────────────────────────────────────

class _BodyInfoRow extends StatelessWidget {
  final BmiDetailsArgs args;

  const _BodyInfoRow({required this.args});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      delayMs: 120,
      child: Row(
        children: [
          Expanded(
            child: _MiniMetricTile(
              icon: Icons.height_rounded,
              label: 'Height',
              value: formatHeight(args.heightCm),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniMetricTile(
              icon: Icons.monitor_weight_outlined,
              label: 'Weight',
              value: formatWeightKg(args.weightKg),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLight
              ? HomePremiumTheme.lightCharcoalText.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: HomePremiumTheme.secondaryText(isLight)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section 4: Healthy range ────────────────────────────────────────────────

class _HealthyRangeCard extends StatelessWidget {
  final BmiDetailsArgs args;

  const _HealthyRangeCard({required this.args});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final heightCm = args.heightCm ?? 0;
    if (heightCm <= 0) {
      return _PremiumCard(
        delayMs: 180,
        child: Text(
          'Add height in your profile to see healthy weight range.',
          style: TextStyle(
            fontSize: 13,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
        ),
      );
    }

    final range = healthyWeights(heightCm);
    final weight = args.weightKg ?? 0;
    final needToChange = weight > range.maxKg
        ? weight - range.maxKg
        : weight < range.minKg
            ? range.minKg - weight
            : 0.0;
    final isAbove = weight > range.maxKg;

    return _PremiumCard(
      delayMs: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Healthy Weight Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${range.minKg.toStringAsFixed(1)} kg – ${range.maxKg.toStringAsFixed(1)} kg',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 14),
          _RangeStatRow(
            label: 'Target Weight',
            value: '${range.targetKg.toStringAsFixed(1)} kg',
            color: const Color(0xFF22C55E),
          ),
          if (needToChange > 0) ...[
            const SizedBox(height: 8),
            _RangeStatRow(
              label: isAbove ? 'Need to Lose' : 'Need to Gain',
              value: '${needToChange.toStringAsFixed(1)} kg',
              color: const Color(0xFFF59E0B),
            ),
          ] else if (weight > 0) ...[
            const SizedBox(height: 8),
            Text(
              'You are within the healthy range',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF22C55E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RangeStatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Section 5: Weight simulator ───────────────────────────────────────────

class _WeightGoalSimulator extends StatelessWidget {
  final BmiDetailsArgs args;
  final double simWeightKg;
  final ValueChanged<double> onWeightChanged;

  const _WeightGoalSimulator({
    required this.args,
    required this.simWeightKg,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final heightCm = args.heightCm ?? 0;
    final heightM = heightCm / 100.0;

    if (heightM <= 0) {
      return _PremiumCard(
        delayMs: 240,
        child: Text(
          'Add height to use the weight goal simulator.',
          style: TextStyle(
            fontSize: 13,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
        ),
      );
    }

    final range = healthyWeights(heightCm);
    final rawMin = range.minKg * 0.85;
    final rawMax = math.min(range.maxKg * 1.35, 160.0);
    final minKg = math.min(rawMin, rawMax - 0.5);
    final maxKg = math.max(rawMax, minKg + 0.5);
    final weight = simWeightKg.clamp(minKg, maxKg);
    final currentBmi = args.bmi;
    final simBmi = bmiFromHeightWeight(heightCm, weight);
    final simStatus = bmiCategoryFromValue(simBmi);
    final simProgress = bmiProgress(simBmi);
    final simColor = BmiMeterColors.fromProgress(simProgress);
    final targetKg = range.targetKg;
    final targetBmi = 24.9;

    return _PremiumCard(
      delayMs: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight Goal Simulator',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SimValueBlock(
                  label: 'Current Weight',
                  value: formatWeightKg(args.weightKg),
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: HomePremiumTheme.secondaryText(isLight)),
              Expanded(
                child: _SimValueBlock(
                  label: 'Target Weight',
                  value: '${targetKg.toStringAsFixed(1)} kg',
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${weight.toStringAsFixed(1)} kg → ${targetKg.toStringAsFixed(1)} kg',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'BMI: ${currentBmi > 0 ? currentBmi.toStringAsFixed(1) : '--'} → ${simBmi.toStringAsFixed(1)} (target ${targetBmi.toStringAsFixed(1)})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: simColor,
            ),
            child: Text(simStatus),
          ),
          const SizedBox(height: 12),
          _BmiRangeBar(
            bmi: simBmi,
            pulseAnim: const AlwaysStoppedAnimation<double>(1.0),
            showYouLabel: false,
            animateDot: false,
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: simColor,
              inactiveTrackColor:
                  HomePremiumTheme.secondaryText(isLight).withValues(alpha: 0.2),
              thumbColor: simColor,
              overlayColor: simColor.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: weight,
              min: minKg,
              max: maxKg,
              onChanged: onWeightChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimValueBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _SimValueBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: HomePremiumTheme.primaryText(isLight),
          ),
        ),
      ],
    );
  }
}

// ─── Section 6: Education accordion ─────────────────────────────────────────

class _BmiEducationAccordion extends StatefulWidget {
  const _BmiEducationAccordion();

  @override
  State<_BmiEducationAccordion> createState() => _BmiEducationAccordionState();
}

class _BmiEducationAccordionState extends State<_BmiEducationAccordion> {
  bool _expanded = false;

  static const _categories = [
    ('Underweight', 'Below 18.5'),
    ('Normal', '18.5 – 24.9'),
    ('Overweight', '25 – 29.9'),
    ('Obese', '30+'),
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return _PremiumCard(
      delayMs: 300,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'BMI Categories',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: HomePremiumTheme.primaryText(isLight),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: HomePremiumTheme.secondaryText(isLight),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: _categories.map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: HomePremiumTheme.primaryText(isLight),
                            ),
                          ),
                        ),
                        Text(
                          c.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HomePremiumTheme.secondaryText(isLight),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

// ─── Section 7: Disclaimer ───────────────────────────────────────────────────

class _BmiDisclaimerCard extends StatelessWidget {
  const _BmiDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return _PremiumCard(
      delayMs: 360,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'BMI is a general health screening tool based on height and weight. '
              'It does not account for muscle mass, body composition, age, gender, '
              'or medical conditions. Consult a healthcare professional for '
              'personalized health advice.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
