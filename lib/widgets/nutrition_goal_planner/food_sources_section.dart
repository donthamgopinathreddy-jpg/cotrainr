import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/food_sources_data.dart';
import '../../services/nutrition_planner_local_storage.dart';
import '../home_v3/home_premium_theme.dart';

class FoodSourcesSection extends StatelessWidget {
  static const _proteinColor = Color(0xFFFF6B8A);
  static const _carbsColor = Color(0xFF4DA3FF);
  static const _fatsColor = Color(0xFFF5B942);
  static const _fiberColor = Color(0xFF3ED598);
  static const _caloriesColor = Color(0xFFFF8C42);

  final bool isLight;
  final DietPreference selectedDiet;
  final int proteinGoalG;
  final int carbsGoalG;
  final int fiberGoalG;
  final int fatsGoalG;
  final ValueChanged<DietPreference> onDietChanged;

  const FoodSourcesSection({
    super.key,
    required this.isLight,
    required this.selectedDiet,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fiberGoalG,
    required this.fatsGoalG,
    required this.onDietChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How To Hit These Targets',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: HomePremiumTheme.primaryText(isLight),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose foods based on your diet preference.',
          style: TextStyle(
            fontSize: 13,
            color: HomePremiumTheme.secondaryText(isLight),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        _dietChips(),
        const SizedBox(height: 20),
        _macroSection(
          title: 'Protein Sources',
          goalLabel: 'Goal ${proteinGoalG}g',
          color: _proteinColor,
          category: FoodMacroCategory.protein,
        ),
        const SizedBox(height: 16),
        _macroSection(
          title: 'Carb Sources',
          goalLabel: 'Goal ${carbsGoalG}g',
          color: _carbsColor,
          category: FoodMacroCategory.carbs,
        ),
        const SizedBox(height: 16),
        _macroSection(
          title: 'Fiber Sources',
          goalLabel: 'Goal ${fiberGoalG}g',
          color: _fiberColor,
          category: FoodMacroCategory.fiber,
        ),
        const SizedBox(height: 16),
        _macroSection(
          title: 'Healthy Fat Sources',
          goalLabel: 'Goal ${fatsGoalG}g',
          color: _fatsColor,
          category: FoodMacroCategory.fats,
        ),
      ],
    );
  }

  Widget _dietChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DietPreference.values.map((diet) {
          final selected = selectedDiet == diet;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(diet.label),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: selected
                    ? Colors.white
                    : HomePremiumTheme.primaryText(isLight),
              ),
              selectedColor: const Color(0xFF3ED598),
              backgroundColor:
                  isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard,
              side: BorderSide(
                color: selected
                    ? const Color(0xFF3ED598)
                    : HomePremiumTheme.secondaryText(isLight).withValues(alpha: 0.2),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onDietChanged(diet);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _macroSection({
    required String title,
    required String goalLabel,
    required Color color,
    required FoodMacroCategory category,
  }) {
    final foods = foodsForCategory(category, diet: selectedDiet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title • $goalLabel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HomePremiumTheme.primaryText(isLight),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (foods.isEmpty)
          Text(
            'No foods match this diet filter.',
            style: TextStyle(
              fontSize: 12,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: foods.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _foodCard(foods[index], color),
            ),
          ),
      ],
    );
  }

  Widget _foodCard(FoodSource food, Color macroColor) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: macroColor.withValues(alpha: 0.25),
        ),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(isLight),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: macroColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${food.mainMacroLabel} / 100g',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: macroColor,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${food.caloriesPer100g.round()} kcal',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _caloriesColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${food.dietType.label} • ${food.region.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }
}
