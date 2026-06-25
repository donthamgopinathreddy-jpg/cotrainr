import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/metric_insight_types.dart';
import '../../services/user_goals_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/insight_metric_theme.dart';

/// Bottom sheet for setting daily metric goals (steps, water, calories, distance).
class MetricGoalPickerSheet extends StatefulWidget {
  final MetricType metricType;
  final InsightMetricTheme theme;
  final double initialGoal;

  const MetricGoalPickerSheet({
    super.key,
    required this.metricType,
    required this.theme,
    required this.initialGoal,
  });

  static Future<bool?> show(
    BuildContext context, {
    required MetricType metricType,
    required InsightMetricTheme theme,
    required double initialGoal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MetricGoalPickerSheet(
        metricType: metricType,
        theme: theme,
        initialGoal: initialGoal,
      ),
    );
  }

  @override
  State<MetricGoalPickerSheet> createState() => _MetricGoalPickerSheetState();
}

class _MetricGoalPickerSheetState extends State<MetricGoalPickerSheet> {
  late double? _selectedGoal;
  late bool _isCustom;
  late final TextEditingController _customController;
  late final _GoalPickerConfig _config;

  @override
  void initState() {
    super.initState();
    _config = _GoalPickerConfig.forMetric(widget.metricType);
    _isCustom = !_config.matchesPreset(widget.initialGoal);
    _selectedGoal = widget.initialGoal > 0 ? widget.initialGoal : null;
    _customController = TextEditingController(
      text: _isCustom && widget.initialGoal > 0
          ? _config.formatCustomValue(widget.initialGoal)
          : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double? get _effectiveGoal {
    if (_isCustom) {
      final text = _customController.text.trim();
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }
    return _selectedGoal;
  }

  bool get _canSave {
    final goal = _effectiveGoal;
    if (goal == null || goal <= 0) return false;
    if (!_config.allowDecimals && goal != goal.roundToDouble()) return false;
    return true;
  }

  Future<void> _save() async {
    final goal = _effectiveGoal;
    if (goal == null || goal <= 0) return;

    final goalsService = UserGoalsService();
    final success = switch (widget.metricType) {
      MetricType.steps => await goalsService.setStepsGoal(goal.toInt()),
      MetricType.water => await goalsService.setWaterGoal(goal),
      MetricType.calories => await goalsService.setCaloriesGoal(goal.toInt()),
      MetricType.distance => await goalsService.setDistanceGoal(goal),
    };

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save goal')),
      );
    }
  }

  void _selectPreset(double value) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGoal = value;
      _isCustom = false;
      _customController.clear();
    });
  }

  void _selectCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      _isCustom = true;
      if (_customController.text.isEmpty && _selectedGoal != null) {
        _customController.text = _config.formatCustomValue(_selectedGoal!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final sheetBg = isLight
        ? DesignTokens.lightCardBackground
        : InsightMetricTheme.surfaceCard;
    final titleColor = DesignTokens.textPrimaryOf(context);
    final subtitleColor = DesignTokens.textSecondaryOf(context);
    final borderColor = isLight
        ? DesignTokens.lightBorder
        : Colors.white.withValues(alpha: 0.12);
    final pillBg = InsightMetricTheme.surfaceCardOf(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _config.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._config.presets.map((value) {
                    final selected = !_isCustom && _selectedGoal == value;
                    return _GoalPickerPill(
                      label: _config.formatPreset(value),
                      selected: selected,
                      accent: widget.theme.accent,
                      selectedTextColor: Colors.white,
                      unselectedBg: pillBg,
                      unselectedTextColor: titleColor,
                      borderColor: borderColor,
                      onTap: () => _selectPreset(value),
                    );
                  }),
                  _GoalPickerPill(
                    label: 'Custom',
                    selected: _isCustom,
                    accent: widget.theme.accent,
                    selectedTextColor: Colors.white,
                    unselectedBg: pillBg,
                    unselectedTextColor: titleColor,
                    borderColor: borderColor,
                    onTap: _selectCustom,
                  ),
                ],
              ),
              if (_isCustom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customController,
                  autofocus: true,
                  keyboardType: _config.allowDecimals
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: _config.allowDecimals
                      ? null
                      : [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  decoration: InputDecoration(
                    hintText: _config.customPlaceholder,
                    hintStyle: TextStyle(color: subtitleColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: widget.theme.accent, width: 2),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: widget.theme.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            widget.theme.accent.withValues(alpha: 0.35),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.7),
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
  }
}

class _GoalPickerPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color selectedTextColor;
  final Color unselectedBg;
  final Color unselectedTextColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _GoalPickerPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.selectedTextColor,
    required this.unselectedBg,
    required this.unselectedTextColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : unselectedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}

class _GoalPickerConfig {
  final String title;
  final List<double> presets;
  final String customPlaceholder;
  final bool allowDecimals;

  const _GoalPickerConfig({
    required this.title,
    required this.presets,
    required this.customPlaceholder,
    required this.allowDecimals,
  });

  static _GoalPickerConfig forMetric(MetricType type) {
    switch (type) {
      case MetricType.steps:
        return const _GoalPickerConfig(
          title: 'Set daily steps goal',
          presets: [5000, 7500, 10000, 12000, 15000, 20000],
          customPlaceholder: 'steps',
          allowDecimals: false,
        );
      case MetricType.water:
        return const _GoalPickerConfig(
          title: 'Set daily water goal',
          presets: [1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
          customPlaceholder: 'liters',
          allowDecimals: true,
        );
      case MetricType.distance:
        return const _GoalPickerConfig(
          title: 'Set daily distance goal',
          presets: [3.0, 5.0, 7.0, 10.0, 12.0, 15.0],
          customPlaceholder: 'km',
          allowDecimals: true,
        );
      case MetricType.calories:
        return const _GoalPickerConfig(
          title: 'Set daily active calories goal',
          presets: [300, 500, 750, 1000, 1500, 2000],
          customPlaceholder: 'kcal',
          allowDecimals: false,
        );
    }
  }

  bool matchesPreset(double value) {
    if (value <= 0) return false;
    return presets.any((g) => (g - value).abs() < 0.05);
  }

  String formatPreset(double value) {
    switch (title) {
      case 'Set daily steps goal':
        return _formatSteps(value);
      case 'Set daily water goal':
        return _formatLiters(value);
      case 'Set daily distance goal':
        return _formatKm(value);
      case 'Set daily active calories goal':
        return '${value.toInt()} kcal';
      default:
        return value.toString();
    }
  }

  String formatCustomValue(double value) {
    if (!allowDecimals) return value.toInt().toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _formatSteps(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      if (k == k.roundToDouble()) return '${k.toInt()}k';
      if (k == 7.5) return '7.5k';
      return '${k}k';
    }
    return value.toInt().toString();
  }

  static String _formatLiters(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()} L';
    }
    return '${value.toStringAsFixed(1)} L';
  }

  static String _formatKm(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()} km';
    }
    return '${value.toStringAsFixed(1)} km';
  }
}
