import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/services/recent_foods_logic.dart';
import 'package:cotrainr/services/cotrainr_pass_id.dart';

void main() {
  group('Recent foods dedupe', () {
    test('empty history stays empty', () {
      final out = dedupeRecentFoodsByKey(
        newestFirst: <({String? foodId, String name})>[],
        dedupeKey: (i) =>
            recentFoodDedupeKey(foodId: i.foodId, foodName: i.name),
      );
      expect(out, isEmpty);
    });

    test('same food logged multiple times appears once with newest serving', () {
      final newestFirst = [
        (foodId: 'a', name: 'Oats', qty: 50.0),
        (foodId: 'a', name: 'Oats', qty: 80.0),
        (foodId: 'b', name: 'Eggs', qty: 2.0),
        (foodId: null, name: 'Oats', qty: 30.0), // different key (no id)
      ];
      final out = dedupeRecentFoodsByKey(
        newestFirst: newestFirst,
        dedupeKey: (i) =>
            recentFoodDedupeKey(foodId: i.foodId, foodName: i.name),
      );
      expect(out.length, 3);
      expect(out[0].qty, 50.0);
      expect(out[1].name, 'Eggs');
      expect(out[2].foodId, isNull);
    });

    test('format last used serving', () {
      expect(
        formatLastUsedServing(quantity: 200, unit: '100g'),
        '200 g',
      );
      expect(
        formatLastUsedServing(quantity: 4, unit: '1 egg'),
        '4 egg',
      );
      expect(
        formatLastUsedServing(quantity: 1, unit: 'serving'),
        '1 serving',
      );
    });
  });

  group('Cotrainr Pass ID', () {
    test('format validation', () {
      expect(isValidCotrainrPassId('CT58310427'), isTrue);
      expect(isValidCotrainrPassId('ct58310427'), isFalse);
      expect(isValidCotrainrPassId('CT5831042'), isFalse);
      expect(isValidCotrainrPassId('CT583104270'), isFalse);
      expect(isValidCotrainrPassId('XX58310427'), isFalse);
      expect(normalizeCotrainrPassId(' CT12345678 '), 'CT12345678');
    });
  });
}
