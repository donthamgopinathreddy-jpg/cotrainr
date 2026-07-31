import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/profile_repository.dart';
import '../../services/nutrition_goal_calculator.dart';
import '../../services/nutrition_planner_local_storage.dart';
import '../../services/user_goals_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class GoalsPreferencesPage extends StatefulWidget {
  const GoalsPreferencesPage({super.key});

  @override
  State<GoalsPreferencesPage> createState() => _GoalsPreferencesPageState();
}

class _GoalsPreferencesPageState extends State<GoalsPreferencesPage> {
  final _plannerStorage = NutritionPlannerLocalStorage();
  final _goalsService = UserGoalsService();
  final _profileRepo = ProfileRepository();

  bool _loading = true;
  SavedNutritionPlannerState? _planner;
  int _stepsGoal = 10000;
  double _waterGoal = 2.5;
  int _caloriesGoal = 2000;
  double? _weightKg;
  double? _targetWeightKg;
  String _goalType = '—';
  String _activityLevel = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final planner = await _plannerStorage.loadSavedState();
    final steps = await _goalsService.getStepsGoal();
    final water = await _goalsService.getWaterGoal();
    final calories = await _goalsService.getCaloriesGoal();
    final profile = await _profileRepo.fetchMyProfile();
    if (mounted) {
      setState(() {
        _planner = planner;
        _stepsGoal = steps;
        _waterGoal = water;
        _caloriesGoal = calories;
        _weightKg = (profile?['weight_kg'] as num?)?.toDouble() ??
            planner?.currentWeightKg;
        _targetWeightKg = planner?.targetWeightKg;
        _goalType = planner != null
            ? (NutritionGoalCalculator.goalTypeLabels[planner.goalType] ??
                planner.goalType)
            : 'Not set';
        _activityLevel = planner?.activityLevel.replaceAll('_', ' ') ?? 'Not set';
        _loading = false;
      });
    }
  }

  Future<void> _resetGoals() async {
    final ok = await showHubConfirmDialog(
      context,
      title: 'Reset Goals?',
      message: 'This clears locally saved nutrition planner targets. Activity goals remain until you edit them.',
      confirmLabel: 'Reset',
      isDanger: true,
    );
    if (!ok || !mounted) return;
    final prefs = await _plannerStorage.loadSavedState();
    if (prefs != null) {
      await _plannerStorage.savePlannerState(
        SavedNutritionPlannerState(
          goalCalories: 2000,
          goalProtein: 120,
          goalCarbs: 220,
          goalFats: 65,
          goalFiber: 25,
          goalWaterMl: 2500,
          bmr: prefs.bmr,
          maintenanceCalories: prefs.maintenanceCalories,
          goalType: 'maintenance',
          activityLevel: prefs.activityLevel,
          formulaVersion: prefs.formulaVersion,
          plannerAge: prefs.plannerAge,
          plannerGender: prefs.plannerGender,
          plannerHeightCm: prefs.plannerHeightCm,
          currentWeightKg: prefs.currentWeightKg,
          targetWeightKg: prefs.currentWeightKg,
          timelineDays: prefs.timelineDays,
          weeklyChangeKg: 0,
          savedAt: DateTime.now(),
        ),
      );
    }
    await _load();
    if (mounted) showHubSnackBar(context, 'Nutrition goals reset');
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Goals & Preferences'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: DesignTokens.accentOrange,
              backgroundColor: DesignTokens.surfaceOf(context),
              onRefresh: () => _load(showLoading: false),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                HubSectionCard(
                  title: 'Body & targets',
                  animationDelayMs: 0,
                  child: Column(
                    children: [
                      _GoalRow(
                        label: 'Current weight',
                        value: _weightKg != null
                            ? '${_weightKg!.toStringAsFixed(1)} kg'
                            : '—',
                        delayMs: 0,
                      ),
                      _GoalRow(
                        label: 'Goal weight',
                        value: _targetWeightKg != null
                            ? '${_targetWeightKg!.toStringAsFixed(1)} kg'
                            : '—',
                        delayMs: 40,
                      ),
                      _GoalRow(
                        label: 'Goal type',
                        value: _goalType,
                        delayMs: 80,
                      ),
                      _GoalRow(
                        label: 'Activity level',
                        value: _activityLevel,
                        delayMs: 120,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Daily targets',
                  animationDelayMs: 60,
                  child: Column(
                    children: [
                      _GoalRow(
                        label: 'Step goal',
                        value: '$_stepsGoal',
                        unit: 'steps',
                        delayMs: 0,
                      ),
                      _GoalRow(
                        label: 'Water goal',
                        value: _waterGoal.toStringAsFixed(1),
                        unit: 'L',
                        delayMs: 40,
                      ),
                      _GoalRow(
                        label: 'Calorie goal',
                        value: '$_caloriesGoal',
                        unit: 'kcal',
                        delayMs: 80,
                      ),
                      if (_planner != null) ...[
                        _GoalRow(
                          label: 'Protein',
                          value: '${_planner!.goalProtein}',
                          unit: 'g',
                          delayMs: 120,
                        ),
                        _GoalRow(
                          label: 'Carbs',
                          value: '${_planner!.goalCarbs}',
                          unit: 'g',
                          delayMs: 160,
                        ),
                        _GoalRow(
                          label: 'Fat',
                          value: '${_planner!.goalFats}',
                          unit: 'g',
                          delayMs: 200,
                        ),
                        _GoalRow(
                          label: 'Fiber',
                          value: '${_planner!.goalFiber}',
                          unit: 'g',
                          delayMs: 240,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                HubActionRow(
                  icon: Icons.edit_outlined,
                  title: 'Edit Goals',
                  iconColor: AccountHubTheme.goalsGreen,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/nutrition-goals');
                  },
                  animationDelayMs: 100,
                ),
                const SizedBox(height: 8),
                HubActionRow(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Open Nutrition Goal Planner',
                  iconColor: AccountHubTheme.goalsGreen,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/nutrition-goals');
                  },
                  animationDelayMs: 140,
                ),
                const SizedBox(height: 8),
                HubDangerButton(
                  label: 'Reset Goals',
                  onTap: _resetGoals,
                ),
              ],
            ),
            ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final int delayMs;

  const _GoalRow({
    required this.label,
    required this.value,
    this.unit,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AccountHubTheme.rowSubtitle(context)),
            ),
            RichText(
              text: TextSpan(
                style: AccountHubTheme.rowTitle(context),
                children: [
                  TextSpan(text: value),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: AccountHubTheme.rowSubtitle(context),
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
