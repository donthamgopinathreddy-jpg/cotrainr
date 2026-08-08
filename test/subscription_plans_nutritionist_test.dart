import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/models/subscription_plans.dart';

void main() {
  group('SubscriptionPlans connection quotas', () {
    test('monthly limits: free 5, basic 15, premium unlimited', () {
      expect(SubscriptionPlans.monthlyConnectionRequestLimit(SubscriptionPlans.free), 5);
      expect(SubscriptionPlans.monthlyConnectionRequestLimit(SubscriptionPlans.basic), 15);
      expect(
        SubscriptionPlans.monthlyConnectionRequestLimit(SubscriptionPlans.unlimited),
        isNull,
      );
      expect(
        SubscriptionPlans.hasUnlimitedConnectionRequests(SubscriptionPlans.unlimited),
        isTrue,
      );
    });

    test('free can browse but cannot connect to nutritionists', () {
      expect(SubscriptionPlans.canBrowseNutritionists(SubscriptionPlans.free), isTrue);
      expect(
        SubscriptionPlans.canConnectToNutritionist(SubscriptionPlans.free),
        isFalse,
      );
    });

    test('basic and premium can connect to nutritionists', () {
      expect(
        SubscriptionPlans.canConnectToNutritionist(SubscriptionPlans.basic),
        isTrue,
      );
      expect(
        SubscriptionPlans.canConnectToNutritionist(SubscriptionPlans.unlimited),
        isTrue,
      );
      expect(SubscriptionPlans.displayName(SubscriptionPlans.unlimited), 'Ultimate');
    });

    test('discoverResultCap only applies to free trainers list', () {
      expect(SubscriptionPlans.discoverResultCap(SubscriptionPlans.free), 10);
      expect(SubscriptionPlans.discoverResultCap(SubscriptionPlans.basic), isNull);
    });
  });
}
