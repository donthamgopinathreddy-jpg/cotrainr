import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/models/subscription_plans.dart';

void main() {
  group('SubscriptionPlans presentation metadata', () {
    test('displayName maps premium to Ultimate', () {
      expect(SubscriptionPlans.displayName(SubscriptionPlans.unlimited), 'Ultimate');
      expect(SubscriptionPlans.displayName(SubscriptionPlans.basic), 'Basic');
      expect(SubscriptionPlans.displayName(SubscriptionPlans.free), 'Free');
    });

    test('free can browse nutritionists', () {
      expect(SubscriptionPlans.canBrowseNutritionists(SubscriptionPlans.free), isTrue);
    });

    test('discoverResultCap only applies to free trainers list', () {
      expect(SubscriptionPlans.discoverResultCap(SubscriptionPlans.free), 10);
      expect(SubscriptionPlans.discoverResultCap(SubscriptionPlans.basic), isNull);
    });
  });
}
