import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/meal_repository.dart';
import '../../theme/design_tokens.dart';
import 'client_monitoring_theme.dart';

class ClientMealsPanel extends StatelessWidget {
  final DayMealsData meals;
  final bool richMacros;

  const ClientMealsPanel({
    super.key,
    required this.meals,
    this.richMacros = false,
  });

  static const _order = ['breakfast', 'lunch', 'dinner', 'snack', 'snacks'];

  @override
  Widget build(BuildContext context) {
    if (!meals.hasLoggedMeals) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No meals logged today',
          textAlign: TextAlign.center,
          style: TextStyle(color: ClientMonitoringUi.secondary(context)),
        ),
      );
    }

    final types = _orderedTypes(meals.mealsByType.keys);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Today', style: ClientMonitoringUi.sectionLabel(context)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: ClientMonitoringUi.cardBox(context),
          child: richMacros
              ? _MacroGrid(meals: meals)
              : Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Calories',
                        value: '${meals.totalCalories}',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Protein',
                        value: '${meals.totalProtein.round()} g',
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        for (final type in types) ...[
          Text(
            _labelFor(type),
            style: ClientMonitoringUi.sectionLabel(context),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: ClientMonitoringUi.cardBox(context),
            child: Column(
              children: [
                for (final item in meals.mealsByType[type]!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.foodName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: DesignTokens.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        Text(
                          '${item.caloriesInt} kcal',
                          style: TextStyle(
                            color: ClientMonitoringUi.secondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  List<String> _orderedTypes(Iterable<String> keys) {
    final remaining = {for (final k in keys) k.toLowerCase(): k};
    final out = <String>[];
    for (final key in _order) {
      final original = remaining.remove(key);
      if (original != null) out.add(original);
    }
    out.addAll(remaining.values);
    return out;
  }

  String _labelFor(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
      case 'snacks':
        return 'Snacks';
      default:
        return toBeginningOfSentenceCase(type) ?? type;
    }
  }
}

class _MacroGrid extends StatelessWidget {
  final DayMealsData meals;
  const _MacroGrid({required this.meals});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _Metric(label: 'Calories', value: '${meals.totalCalories}')),
            Expanded(
              child: _Metric(
                label: 'Protein',
                value: '${meals.totalProtein.round()} g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Carbs',
                value: '${meals.totalCarbs.round()} g',
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'Fat',
                value: '${meals.totalFats.round()} g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Metric(label: 'Fiber', value: '${meals.totalFiber.round()} g'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ClientMonitoringUi.sectionLabel(context)),
        const SizedBox(height: 4),
        Text(value, style: ClientMonitoringUi.value(context)),
      ],
    );
  }
}
