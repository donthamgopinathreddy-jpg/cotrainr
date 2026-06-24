import 'package:flutter/material.dart';

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
  late final List<double> _commonGoals;
  late final String _unit;
  late final String _hintText;

  @override
  void initState() {
    super.initState();
    _selectedGoal = widget.initialGoal;
    switch (widget.metricType) {
      case MetricType.steps:
        _commonGoals = [5000, 7500, 10000, 12000, 15000];
        _unit = 'steps';
        _hintText = 'Enter custom steps';
        break;
      case MetricType.water:
        _commonGoals = [1.5, 2.0, 2.5, 3.0, 3.5];
        _unit = 'L';
        _hintText = 'Enter custom liters';
        break;
      case MetricType.calories:
        _commonGoals = [1500, 1800, 2000, 2200, 2500];
        _unit = 'calories';
        _hintText = 'Enter custom calories';
        break;
      case MetricType.distance:
        _commonGoals = [3.0, 5.0, 7.0, 10.0, 12.0];
        _unit = 'km';
        _hintText = 'Enter custom kilometers';
        break;
    }
    _isCustom = !_matchesCommon(widget.initialGoal);
    _customController = TextEditingController(
      text: _isCustom ? _formatGoal(widget.initialGoal) : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool _matchesCommon(double value) {
    return _commonGoals.any((g) => (g - value).abs() < 0.05);
  }

  String _formatGoal(double g) {
    if (widget.metricType == MetricType.steps ||
        widget.metricType == MetricType.calories) {
      return g.toInt().toString();
    }
    return g.toStringAsFixed(1);
  }

  String _formatOption(double g) {
    if (widget.metricType == MetricType.steps ||
        widget.metricType == MetricType.calories) {
      return '${g.toInt()} $_unit';
    }
    return '${g.toStringAsFixed(1)} $_unit';
  }

  Future<void> _save() async {
    final goal = _selectedGoal;
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
                'Set Daily ${widget.theme.title.replaceAll(' Insights', '')} Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 16),
              ..._commonGoals.map(
                (g) => ListTile(
                  title: Text(
                    _formatOption(g),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  trailing: !_isCustom && _selectedGoal == g
                      ? Icon(Icons.check_rounded, color: widget.theme.accent)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedGoal = g;
                      _isCustom = false;
                      _customController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Custom',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
                decoration: InputDecoration(
                  hintText: _hintText,
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
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _isCustom = false;
                      return;
                    }
                    final parsed = double.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      _selectedGoal = parsed;
                      _isCustom = true;
                    }
                  });
                },
              ),
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
                      onPressed: _selectedGoal == null ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: widget.theme.accent,
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
  }
}
