import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../repositories/nutrition_goal_planner_repository.dart';
import '../../services/nutrition_goal_calculator.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';

class NutritionGoalPlannerPage extends StatefulWidget {
  const NutritionGoalPlannerPage({super.key});

  @override
  State<NutritionGoalPlannerPage> createState() =>
      _NutritionGoalPlannerPageState();
}

class _NutritionGoalPlannerPageState extends State<NutritionGoalPlannerPage>
    with SingleTickerProviderStateMixin {
  static const _stepCount = 5;
  static const _timelinePresets = [30, 60, 90, 120, 180];

  final _repo = NutritionGoalPlannerRepository();
  final _pageController = PageController();
  int _step = 0;
  int _contentAnimSeed = 0;
  bool _loadingProfile = true;
  bool _saving = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _currentWeightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _timelineCtrl = TextEditingController(text: '84');
  String _gender = 'Male';

  String _goalType = 'fat_loss';
  String _activityLevel = 'moderately_active';
  bool _goalTypeTouched = false;

  NutritionGoalResult? _result;

  static const _goalTypeIcons = <String, IconData>{
    'fat_loss': Icons.trending_down_rounded,
    'weight_loss': Icons.monitor_weight_outlined,
    'muscle_gain': Icons.fitness_center_rounded,
    'lean_bulk': Icons.sports_gymnastics_rounded,
    'weight_gain': Icons.trending_up_rounded,
    'body_recomposition': Icons.sync_rounded,
    'maintenance': Icons.balance_rounded,
    'athletic_performance': Icons.emoji_events_outlined,
    'endurance_training': Icons.directions_run_rounded,
    'strength_training': Icons.fitness_center_outlined,
    'general_health': Icons.favorite_outline_rounded,
  };

  static const _activityLevels = [
    ('sedentary', 'Sedentary', 'Desk job, little exercise'),
    ('lightly_active', 'Lightly active', '1–3 workouts / week'),
    ('moderately_active', 'Moderately active', '3–5 workouts / week'),
    ('very_active', 'Very active', '6–7 workouts / week'),
    ('extra_active', 'Extra active', 'Athlete / physical job'),
  ];

  static const _nutritionGradient = LinearGradient(
    colors: [Color(0xFF3ED598), Color(0xFF65E6B3)],
  );

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _timelineCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final snap = await _repo.loadProfileSnapshot();
    if (!mounted) return;
    if (snap.age != null) _ageCtrl.text = '${snap.age}';
    if (snap.heightCm != null) {
      _heightCtrl.text = snap.heightCm!.toStringAsFixed(0);
    }
    if (snap.weightKg != null) {
      final w = snap.weightKg!.toStringAsFixed(1);
      _currentWeightCtrl.text = w;
      _targetWeightCtrl.text = w;
    }
    if (snap.gender != null && snap.gender!.isNotEmpty) {
      _gender = snap.gender!;
    }
    _syncSuggestedGoalType();
    setState(() => _loadingProfile = false);
  }

  bool get _bodyValid {
    final age = int.tryParse(_ageCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());
    return age != null &&
        age >= 14 &&
        age <= 100 &&
        h != null &&
        h > 0;
  }

  bool get _weightsValid {
    final current = double.tryParse(_currentWeightCtrl.text.trim());
    final target = double.tryParse(_targetWeightCtrl.text.trim());
    final days = int.tryParse(_timelineCtrl.text.trim());
    return current != null &&
        current > 0 &&
        target != null &&
        target > 0 &&
        days != null &&
        days >= 7 &&
        days <= 730;
  }

  WeightDirection? get _inferredDirection {
    final current = double.tryParse(_currentWeightCtrl.text.trim());
    final target = double.tryParse(_targetWeightCtrl.text.trim());
    if (current == null || target == null) return null;
    return NutritionGoalCalculator.inferDirection(
      currentWeightKg: current,
      targetWeightKg: target,
    );
  }

  void _syncSuggestedGoalType() {
    final dir = _inferredDirection;
    if (dir == null || _goalTypeTouched) return;
    _goalType = NutritionGoalCalculator.suggestGoalType(dir);
  }

  void _onWeightsChanged() {
    _syncSuggestedGoalType();
    setState(() {});
  }

  void _computeResults() {
    final age = int.parse(_ageCtrl.text.trim());
    final heightCm = double.parse(_heightCtrl.text.trim());
    final current = double.parse(_currentWeightCtrl.text.trim());
    final target = double.parse(_targetWeightCtrl.text.trim());
    final days = int.parse(_timelineCtrl.text.trim());

    _result = NutritionGoalCalculator.calculate(
      age: age,
      gender: _gender,
      heightCm: heightCm,
      currentWeightKg: current,
      targetWeightKg: target,
      timelineDays: days,
      activityLevel: _activityLevel,
      goalType: _goalType,
    );
  }

  void _bumpStepAnim() => setState(() => _contentAnimSeed++);

  void _nextStep() {
    if (_step == 0 && !_bodyValid) {
      _snack('Enter a valid age and height.');
      return;
    }
    if (_step == 1 && !_weightsValid) {
      _snack('Enter valid weights and timeline (7–730 days).');
      return;
    }
    if (_step == 3) {
      _computeResults();
    }
    if (_step >= _stepCount - 1) return;
    HapticFeedback.lightImpact();
    setState(() => _step++);
    _bumpStepAnim();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _backStep() {
    if (_step <= 0) {
      context.pop();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _step--);
    _bumpStepAnim();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveGoals() async {
    if (_result == null) return;
    var proceed = true;
    if (_result!.belowMinimumCalories || _result!.belowBmr) {
      final min = NutritionGoalCalculator.minCaloriesForGender(_gender);
      proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Safety notice'),
              content: Text(
                _result!.belowMinimumCalories
                    ? 'Your target is ${_result!.calories} kcal, below the '
                        'recommended minimum of $min kcal/day. '
                        'Save anyway?'
                    : 'Your target is below your estimated BMR (${_result!.bmr} kcal). '
                        'Save anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!proceed || !mounted) return;

    setState(() => _saving = true);
    try {
      await _repo.saveActiveGoal(
        result: _result!,
        age: int.parse(_ageCtrl.text.trim()),
        gender: _gender,
        heightCm: double.parse(_heightCtrl.text.trim()),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _snack('Daily nutrition targets saved.');
      context.pop();
    } catch (_) {
      if (mounted) _snack('Could not save targets. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _animated(Widget child, int delayMs) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${_contentAnimSeed}_$delayMs'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Transform.scale(
              scale: 0.99 + 0.01 * value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, String subtitle, bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => _nutritionGradient.createShader(b),
              child: const Icon(
                Icons.track_changes_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: _nutritionGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: HomePremiumTheme.primaryText(isLight),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: HomePremiumTheme.secondaryText(isLight),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? HomePremiumTheme.lightWarmBg : HomePremiumTheme.darkCharcoal;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Nutrition Goals',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight ? Colors.white : HomePremiumTheme.darkCard,
        foregroundColor: HomePremiumTheme.primaryText(isLight),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _backStep,
        ),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: List.generate(_stepCount, (i) {
                        final on = i <= _step;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            height: 4,
                            margin: EdgeInsets.only(right: i < _stepCount - 1 ? 6 : 0),
                            decoration: BoxDecoration(
                              gradient: on ? _nutritionGradient : null,
                              color: on
                                  ? null
                                  : HomePremiumTheme.secondaryText(isLight)
                                      .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _bodyStep(isLight),
                        _weightsStep(isLight),
                        _goalStep(isLight),
                        _activityStep(isLight),
                        _resultsStep(isLight),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : HomePremiumTheme.darkCard,
                      boxShadow: HomePremiumTheme.softCardShadow(isLight),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: _step < _stepCount - 1
                          ? _gradientButton(
                              label: _step == 3 ? 'See results' : 'Continue',
                              onPressed: _canContinue ? _nextStep : null,
                            )
                          : _gradientButton(
                              label: 'Save as my daily targets',
                              onPressed: _saving ? null : _saveGoals,
                              loading: _saving,
                            ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Targets are estimates based on standard nutrition formulas '
                      'and are not medical advice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _gradientButton({
    required String label,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? _nutritionGradient : null,
          color: enabled ? null : const Color(0xFFB0B8C4),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF3ED598).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _bodyValid;
      case 1:
        return _weightsValid;
      default:
        return true;
    }
  }

  Widget _bodyStep(bool isLight) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _animated(_sectionTitle(
          'Body details',
          'We pre-fill from your profile when available.',
          isLight,
        ), 0),
        const SizedBox(height: 20),
        _animated(_homeField('Age', _ageCtrl, TextInputType.number, isLight), 40),
        const SizedBox(height: 12),
        _animated(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gender',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: HomePremiumTheme.primaryText(isLight),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Male', label: Text('Male')),
                  ButtonSegment(value: 'Female', label: Text('Female')),
                  ButtonSegment(value: 'Other', label: Text('Other')),
                ],
                selected: {_gender},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() => _gender = s.first);
                },
              ),
            ],
          ),
          80,
        ),
        const SizedBox(height: 12),
        _animated(_homeField('Height (cm)', _heightCtrl, TextInputType.number, isLight), 120),
      ],
    );
  }

  Widget _weightsStep(bool isLight) {
    final dir = _inferredDirection;
    final preview = _timelinePreview();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _animated(_sectionTitle(
          'Weight & timeline',
          'We infer your goal direction from current vs target weight.',
          isLight,
        ), 0),
        const SizedBox(height: 20),
        _animated(
          _homeField(
            'Current weight (kg)',
            _currentWeightCtrl,
            const TextInputType.numberWithOptions(decimal: true),
            isLight,
            onChanged: (_) => _onWeightsChanged(),
          ),
          40,
        ),
        const SizedBox(height: 12),
        _animated(
          _homeField(
            'Target weight (kg)',
            _targetWeightCtrl,
            const TextInputType.numberWithOptions(decimal: true),
            isLight,
            onChanged: (_) => _onWeightsChanged(),
          ),
          80,
        ),
        const SizedBox(height: 16),
        _animated(
          Text(
            'Target timeline',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          100,
        ),
        const SizedBox(height: 10),
        _animated(_timelinePresetsRow(isLight), 120),
        const SizedBox(height: 12),
        _animated(
          _homeField(
            'Days',
            _timelineCtrl,
            TextInputType.number,
            isLight,
            onChanged: (_) => setState(() {}),
          ),
          160,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: dir == null
              ? const SizedBox.shrink(key: ValueKey('no-dir'))
              : _insightCard(
                  isLight,
                  key: ValueKey('dir-$dir-$preview'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        NutritionGoalCalculator.directionLabel(dir),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HomePremiumTheme.primaryText(isLight),
                        ),
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          style: TextStyle(
                            fontSize: 13,
                            color: HomePremiumTheme.secondaryText(isLight),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _timelinePresetsRow(bool isLight) {
    final selected = int.tryParse(_timelineCtrl.text.trim());
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _timelinePresets.map((days) {
        final on = selected == days;
        return PressableCard(
          borderRadius: 20,
          onTap: () {
            HapticFeedback.selectionClick();
            _timelineCtrl.text = '$days';
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: on ? _nutritionGradient : null,
              color: on
                  ? null
                  : (isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard),
              borderRadius: BorderRadius.circular(20),
              boxShadow: on ? HomePremiumTheme.softCardShadow(isLight) : null,
            ),
            child: Text(
              '$days d',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: on
                    ? Colors.white
                    : HomePremiumTheme.primaryText(isLight),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String? _timelinePreview() {
    final current = double.tryParse(_currentWeightCtrl.text.trim());
    final target = double.tryParse(_targetWeightCtrl.text.trim());
    final days = int.tryParse(_timelineCtrl.text.trim());
    if (current == null || target == null || days == null || days < 1) {
      return null;
    }
    final weekly = (target - current).abs() / (days / 7.0);
    final daily = (target - current).abs() / days;
    return 'Weekly change: ${weekly.toStringAsFixed(2)} kg/week · '
        '${(daily * 1000).toStringAsFixed(0)} g/day';
  }

  Widget _goalStep(bool isLight) {
    final entries = NutritionGoalCalculator.goalTypeLabels.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _animated(_sectionTitle(
          'Goal type',
          'Pick the goal that best matches your plan.',
          isLight,
        ), 0),
        const SizedBox(height: 16),
        ...entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final selected = _goalType == e.key;
          final icon = _goalTypeIcons[e.key] ?? Icons.flag_outlined;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _animated(
              _selectTile(
                isLight: isLight,
                selected: selected,
                icon: icon,
                title: e.value,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _goalType = e.key;
                    _goalTypeTouched = true;
                  });
                },
              ),
              30 + (i * 25).clamp(0, 200),
            ),
          );
        }),
      ],
    );
  }

  Widget _activityStep(bool isLight) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _animated(_sectionTitle(
          'Activity level',
          'Used to estimate your maintenance calories.',
          isLight,
        ), 0),
        const SizedBox(height: 16),
        ..._activityLevels.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          final selected = _activityLevel == a.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _animated(
              _selectTile(
                isLight: isLight,
                selected: selected,
                icon: Icons.directions_walk_rounded,
                title: a.$2,
                subtitle: a.$3,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activityLevel = a.$1);
                },
              ),
              30 + (i * 35).clamp(0, 220),
            ),
          );
        }),
      ],
    );
  }

  Widget _resultsStep(bool isLight) {
    final r = _result;
    if (r == null) {
      return const Center(child: Text('No results yet'));
    }

    final cards = [
      ('Target calories', '${r.calories} kcal', Icons.local_fire_department),
      ('Protein', '${r.proteinG} g', Icons.egg_alt_outlined),
      ('Carbs', '${r.carbsG} g', Icons.grain_rounded),
      ('Fats', '${r.fatG} g', Icons.water_drop_outlined),
      ('Fiber', '${r.fiberG} g', Icons.eco_outlined),
      ('Water', '${r.waterMl} ml', Icons.water_drop_rounded),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _animated(_sectionTitle(
          'Your daily targets',
          'BMR ${r.bmr} kcal · Maintenance ${r.maintenanceCalories} kcal',
          isLight,
        ), 0),
        const SizedBox(height: 12),
        _animated(_insightCard(isLight, child: _resultsSummary(r, isLight)), 40),
        if (r.aggressiveTimeline || r.warning != null) ...[
          const SizedBox(height: 12),
          _animated(_warningBanner(r), 80),
        ],
        const SizedBox(height: 16),
        ...cards.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _animated(
              _resultCard(e.value.$1, e.value.$2, e.value.$3, isLight),
              100 + e.key * 40,
            ),
          );
        }),
      ],
    );
  }

  Widget _resultsSummary(NutritionGoalResult r, bool isLight) {
    return Column(
      children: [
        _summaryRow('Current weight', '${r.currentWeightKg.toStringAsFixed(1)} kg', isLight),
        _summaryRow('Target weight', '${r.targetWeightKg.toStringAsFixed(1)} kg', isLight),
        _summaryRow('Timeline', '${r.timelineDays} days', isLight),
        _summaryRow(
          'Weekly change',
          '${r.weeklyChangeKg.toStringAsFixed(2)} kg/week',
          isLight,
        ),
        _summaryRow('Goal type', r.goalTypeLabel, isLight),
      ],
    );
  }

  Widget _warningBanner(NutritionGoalResult r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.warning ?? 'Your timeline may be aggressive for this goal.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(bool isLight, {Key? key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [
                  const Color(0xFF3ED598).withValues(alpha: 0.14),
                  HomePremiumTheme.lightCreamCard,
                ]
              : [
                  const Color(0xFF3ED598).withValues(alpha: 0.2),
                  HomePremiumTheme.darkCard,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: child,
    );
  }

  Widget _selectTile({
    required bool isLight,
    required bool selected,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return PressableCard(
      borderRadius: 14,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? _nutritionGradient : null,
          color: selected
              ? null
              : (isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard),
          borderRadius: BorderRadius.circular(14),
          boxShadow: HomePremiumTheme.softCardShadow(isLight),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF3ED598),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : HomePremiumTheme.primaryText(isLight),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : HomePremiumTheme.secondaryText(isLight),
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(String label, String value, IconData icon, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => _nutritionGradient.createShader(b),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeField(
    String label,
    TextEditingController ctrl,
    TextInputType type,
    bool isLight, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: TextStyle(color: HomePremiumTheme.primaryText(isLight)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isLight ? Colors.white : HomePremiumTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: HomePremiumTheme.secondaryText(isLight).withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3ED598), width: 1.5),
        ),
      ),
      onChanged: onChanged ?? (_) => setState(() {}),
    );
  }
}
