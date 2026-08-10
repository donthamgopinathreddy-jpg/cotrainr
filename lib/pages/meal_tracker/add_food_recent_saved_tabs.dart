import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../repositories/meal_repository.dart';
import '../../repositories/saved_meals_repository.dart';
import '../../services/recent_foods_logic.dart';
import '../../theme/meal_tracker_tokens.dart';

class AddFoodBrowseTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color textPrimary;
  final Color surface;

  const AddFoodBrowseTabs({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.textPrimary,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final labels = const ['Search', 'Recent', 'Saved Meals'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = selectedIndex == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? MealTrackerTokens.accent.withValues(alpha: 0.16)
                        : surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? MealTrackerTokens.accent.withValues(alpha: 0.45)
                          : textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? MealTrackerTokens.accent
                          : textPrimary.withValues(alpha: 0.7),
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

class RecentFoodsList extends StatelessWidget {
  final ScrollController controller;
  final List<RecentFoodItem> items;
  final bool loading;
  final String? error;
  final String? addingKey;
  final void Function(RecentFoodItem item) onTapRow;
  final void Function(RecentFoodItem item) onQuickAdd;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;

  const RecentFoodsList({
    super.key,
    required this.controller,
    required this.items,
    required this.loading,
    required this.error,
    required this.addingKey,
    required this.onTapRow,
    required this.onQuickAdd,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
        ),
      );
    }
    if (items.isEmpty) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'No recent foods yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Foods you log will show up here for one-tap add.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final key = recentFoodDedupeKey(
          foodId: item.foodId,
          foodName: item.foodName,
        );
        final busy = addingKey == key;
        final foodAsItem = _asDisplayFood(item);
        final serving = formatLastUsedServing(
          quantity: item.quantity,
          unit: item.unit,
        );
        return Material(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: busy ? null : () => onTapRow(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.foodName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last used: $serving',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${foodAsItem.totalCalories} kcal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'P ${foodAsItem.totalProtein.toStringAsFixed(0)}g • '
                          'C ${foodAsItem.totalCarbs.toStringAsFixed(0)}g • '
                          'F ${foodAsItem.totalFats.toStringAsFixed(0)}g',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => onQuickAdd(item),
                    icon: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.add_circle_rounded,
                            color: MealTrackerTokens.accent, size: 28),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Rebuild FoodItem-style totals using the same factor rules as meal tracker.
  static _RecentDisplay _asDisplayFood(RecentFoodItem item) {
    final base = RegExp(r'(\d+)\s*g', caseSensitive: false).firstMatch(item.unit);
    final factor = base != null
        ? item.quantity / (double.tryParse(base.group(1) ?? '100') ?? 100)
        : item.quantity;
    return _RecentDisplay(
      totalCalories: (item.calories * factor).round(),
      totalProtein: item.protein * factor,
      totalCarbs: item.carbs * factor,
      totalFats: item.fat * factor,
    );
  }
}

class _RecentDisplay {
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  const _RecentDisplay({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });
}

class SavedMealsList extends StatelessWidget {
  final ScrollController controller;
  final List<SavedMeal> meals;
  final bool loading;
  final String? error;
  final String? addingId;
  final VoidCallback onRefresh;
  final void Function(SavedMeal meal) onAdd;
  final void Function(SavedMeal meal) onEdit;
  final void Function(SavedMeal meal) onDelete;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;

  const SavedMealsList({
    super.key,
    required this.controller,
    required this.meals,
    required this.loading,
    required this.error,
    required this.addingId,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
              const SizedBox(height: 12),
              TextButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (meals.isEmpty) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'No saved meals yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a meal section and use Save as meal to store a combination you eat often.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: meals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final meal = meals[i];
        final busy = addingId == meal.id;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: textPrimary.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: busy ? null : () => onEdit(meal),
                    icon: Icon(Icons.edit_outlined, color: textSecondary, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: busy ? null : () => onDelete(meal),
                    icon: Icon(Icons.delete_outline_rounded,
                        color: textSecondary, size: 20),
                  ),
                ],
              ),
              Text(
                '${meal.items.length} foods · ${meal.totalCalories} kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...meal.items.take(4).map(
                    (it) => Text(
                      '• ${it.foodName} · ${formatLastUsedServing(quantity: it.quantity, unit: it.unit)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              if (meal.items.length > 4)
                Text(
                  '+ ${meal.items.length - 4} more',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : () => onAdd(meal),
                  style: FilledButton.styleFrom(
                    backgroundColor: MealTrackerTokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add meal'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
