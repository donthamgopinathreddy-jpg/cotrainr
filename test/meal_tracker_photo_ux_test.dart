import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/theme/meal_tracker_tokens.dart';

void main() {
  group('MealTrackerTokens intake hero', () {
    test('light intake uses classic greens at medium strength', () {
      final light = MealTrackerTokens.intakeTileGradient(true);
      expect(light.colors.first, MealTrackerTokens.softAccent());
      expect(light.colors[1], MealTrackerTokens.softAccent2());
      expect(light.colors.last, MealTrackerTokens.softAccentDeep());
      expect(light.colors.first, isNot(const Color(0xFF22C55E)));
      expect(light.colors.first.green, greaterThan(light.colors.first.red));
    });

    test('light intake keeps white-on-green contrast helpers', () {
      expect(MealTrackerTokens.intakeOnPrimary(true), Colors.white);
      expect(MealTrackerTokens.intakeRingColor(true), Colors.white);
      expect(
        MealTrackerTokens.intakeMacroBarFill(true, 0),
        Colors.white.withValues(alpha: 0.92),
      );
    });

    test('Add Food primary gradient is stronger than intake surface', () {
      final g = MealTrackerTokens.primaryGradient;
      expect(g.colors.first, MealTrackerTokens.softAccent(0.92));
      expect(g.colors.last, MealTrackerTokens.softAccent2(0.92));
    });

    test('dark intake gradient still resolves elevated green wash', () {
      final dark = MealTrackerTokens.intakeTileGradient(false);
      expect(dark.colors, isNotEmpty);
      expect(dark.colors.first, isNot(MealTrackerTokens.darkBackground));
      expect(
        MealTrackerTokens.intakeRingColor(false),
        MealTrackerTokens.accent,
      );
    });
  });

  group('MealTrackerPageV2 photo UX source contract', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/pages/meal_tracker/meal_tracker_page_v2.dart',
      ).readAsStringSync();
    });

    test('separate meal-card camera button is removed', () {
      expect(src.contains('Icons.camera_alt_rounded'), isFalse);
      expect(src.contains('_MealPhotoSlot'), isTrue);
      expect(src.contains("label: 'Add meal photo'"), isTrue);
      expect(src.contains("label: 'Remove meal photo'"), isTrue);
    });

    test('delete control sits below image; no overlay close on photo slot', () {
      expect(src.contains('Icons.delete_outline_rounded'), isTrue);
      final photoSlot = src.substring(
        src.indexOf('class _MealPhotoSlot'),
        src.indexOf('class _AddMealTile'),
      );
      expect(photoSlot.contains('Icons.close_rounded'), isFalse);
      expect(photoSlot.contains('Icons.delete_outline_rounded'), isTrue);
      final placeholder = src.substring(
        src.indexOf('Widget _emptyPlaceholder()'),
        src.indexOf('class _AddMealTile'),
      );
      expect(placeholder.contains('Icons.add_rounded'), isFalse);
    });

    test('photo remove clears path only and is date-scoped', () {
      expect(src.contains('_mealPhotoKey'), isTrue);
      expect(src.contains('_setMealPhoto'), isTrue);
      expect(src.contains('onRemovePhoto'), isTrue);
      final removeBlock = src.substring(
        src.indexOf('onRemovePhoto: ()'),
        src.indexOf('onRemovePhoto: ()') + 180,
      );
      expect(removeBlock.contains('deleteFoodItem'), isFalse);
      expect(removeBlock.contains('_setMealPhoto(mealType, null)'), isTrue);
    });

    test('existing image uses BoxFit.cover inside rounded slot', () {
      expect(src.contains('fit: BoxFit.cover'), isTrue);
      expect(src.contains('Image.file'), isTrue);
    });
  });
}
