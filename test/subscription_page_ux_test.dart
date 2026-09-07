import 'package:cotrainr/models/subscription_plans.dart';
import 'package:cotrainr/pages/subscription/subscription_page.dart';
import 'package:cotrainr/services/entitlement_service.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Entitlements _ents({
  required String plan,
  required String display,
  required bool unlimited,
  int used = 0,
  int? remaining,
  int? limit,
  bool nutritionistAllowed = false,
  DateTime? periodEnd,
}) {
  return Entitlements(
    plan: plan,
    planDisplayName: display,
    subscriptionStatus: 'active',
    periodKey: '2026-09',
    periodKind: 'month',
    periodStart: DateTime(2026, 9, 1),
    periodEnd: periodEnd ?? DateTime(2026, 10, 1),
    limit: limit,
    unlimited: unlimited,
    used: used,
    remaining: remaining,
    nutritionistAllowed: nutritionistAllowed,
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required String plan,
  required Entitlements entitlements,
  ThemeData? theme,
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme == AppTheme.darkTheme
              ? ThemeMode.dark
              : ThemeMode.light,
          home: SubscriptionPage(
            initialPlanOverride: plan,
            entitlementsOverride: entitlements,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SubscriptionPlanColors', () {
    test('locked Free / Basic / Ultimate colours', () {
      expect(SubscriptionPlanColors.freeStart, const Color(0xFF555B63));
      expect(SubscriptionPlanColors.freeEnd, const Color(0xFF8A9098));
      expect(SubscriptionPlanColors.basicStart, const Color(0xFFF65A00));
      expect(SubscriptionPlanColors.basicEnd, const Color(0xFFFF9D24));
      expect(SubscriptionPlanColors.ultimateStart, const Color(0xFF0D0D0F));
      expect(SubscriptionPlanColors.ultimateEnd, const Color(0xFF252529));
      expect(SubscriptionPlanColors.ultimateGold, const Color(0xFFD9AD4A));
      expect(
        SubscriptionPlanColors.accentFor(SubscriptionPlans.unlimited),
        SubscriptionPlanColors.ultimateGold,
      );
      expect(
        subscriptionPlanIcon(SubscriptionPlans.free),
        Icons.travel_explore_rounded,
      );
      expect(
        subscriptionPlanIcon(SubscriptionPlans.basic),
        Icons.group_add_rounded,
      );
      expect(
        subscriptionPlanIcon(SubscriptionPlans.unlimited),
        Icons.diamond_rounded,
      );
    });
  });

  group('MembershipSummaryCard', () {
    testWidgets('Free finite allowance mid usage', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.free,
        entitlements: _ents(
          plan: 'free',
          display: 'Free',
          unlimited: false,
          used: 3,
          remaining: 2,
          limit: 5,
          nutritionistAllowed: false,
        ),
      );

      expect(find.text('YOUR MEMBERSHIP'), findsOneWidget);
      expect(find.text('FREE'), findsWidgets);
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('connections remaining'), findsOneWidget);
      expect(find.textContaining('3 used'), findsOneWidget);
      expect(find.textContaining('2 remaining'), findsOneWidget);
      expect(find.textContaining('Resets'), findsOneWidget);
      expect(find.text('Trainer connections only'), findsWidgets);
      expect(find.text('Nutritionists unlock with Basic'), findsOneWidget);
      expect(find.text('CURRENT'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Upgrade — coming soon'), findsNothing);
      expect(find.text('Connection allowance'), findsNothing);
      expect(find.text('Current plan'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Upgrades coming soon'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Upgrades coming soon'), findsOneWidget);
    });

    testWidgets('Free zero remaining', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.free,
        entitlements: _ents(
          plan: 'free',
          display: 'Free',
          unlimited: false,
          used: 5,
          remaining: 0,
          limit: 5,
        ),
      );
      expect(find.text('0 of 5'), findsOneWidget);
      expect(find.textContaining('5 used'), findsOneWidget);
      expect(find.textContaining('0 remaining'), findsOneWidget);
    });

    testWidgets('Free full remaining', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.free,
        entitlements: _ents(
          plan: 'free',
          display: 'Free',
          unlimited: false,
          used: 0,
          remaining: 5,
          limit: 5,
        ),
      );
      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.textContaining('0 used'), findsOneWidget);
    });

    testWidgets('Basic finite allowance + nutritionist access', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.basic,
        entitlements: _ents(
          plan: 'basic',
          display: 'Basic',
          unlimited: false,
          used: 4,
          remaining: 11,
          limit: 15,
          nutritionistAllowed: true,
        ),
      );
      expect(find.text('BASIC'), findsWidgets);
      expect(find.text('11 of 15'), findsOneWidget);
      expect(find.text('Trainer + Nutritionist access'), findsOneWidget);
      expect(find.text('Nutritionists unlock with Basic'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Ultimate unlimited — no numeric progress', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.unlimited,
        entitlements: _ents(
          plan: 'premium',
          display: 'Ultimate',
          unlimited: true,
          nutritionistAllowed: true,
          remaining: null,
          limit: null,
        ),
      );
      expect(find.text('ULTIMATE'), findsWidgets);
      expect(find.text('Unlimited'), findsWidgets);
      expect(find.text('provider connections'), findsOneWidget);
      expect(find.text('Trainer + Nutritionist access'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('CURRENT'), findsWidgets);
      // CURRENT wins over POPULAR when Ultimate is current.
      expect(find.text('POPULAR'), findsNothing);
    });
  });

  group('Compare plans expand/collapse', () {
    testWidgets('expand and collapse Free / Basic / Ultimate', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.free,
        entitlements: _ents(
          plan: 'free',
          display: 'Free',
          unlimited: false,
          used: 1,
          remaining: 4,
          limit: 5,
        ),
        size: const Size(360, 1200),
      );

      expect(find.text('Compare plans'), findsOneWidget);
      expect(find.text('View benefits'), findsNWidgets(3));
      expect(find.text('Browse trainers & nutritionists'), findsNothing);

      await tester.tap(find.text('FREE').last);
      await tester.pumpAndSettle();
      expect(find.text('Browse trainers & nutritionists'), findsOneWidget);
      expect(find.text('Hide benefits'), findsOneWidget);

      await tester.tap(find.text('BASIC'));
      await tester.pumpAndSettle();
      expect(find.text('Browse trainers & nutritionists'), findsNothing);
      expect(
        find.text('15 new provider connections/month combined'),
        findsOneWidget,
      );
      // Duplicate connection wording should not appear twice on Basic card.
      expect(
        find.text('15 new Trainer & Nutritionist connections per month'),
        findsNothing,
      );

      await tester.tap(find.text('ULTIMATE'));
      await tester.pumpAndSettle();
      expect(find.text('Priority support'), findsOneWidget);
      expect(
        find.text('15 new provider connections/month combined'),
        findsNothing,
      );

      await tester.tap(find.text('ULTIMATE'));
      await tester.pumpAndSettle();
      expect(find.text('Priority support'), findsNothing);
      expect(find.text('View benefits'), findsNWidgets(3));
    });

    testWidgets('Ultimate not current shows POPULAR', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.basic,
        entitlements: _ents(
          plan: 'basic',
          display: 'Basic',
          unlimited: false,
          used: 0,
          remaining: 15,
          limit: 15,
          nutritionistAllowed: true,
        ),
      );
      expect(find.text('POPULAR'), findsOneWidget);
      expect(find.text('CURRENT'), findsWidgets);
    });
  });

  group('Responsive / a11y smoke', () {
    testWidgets('small Android screen + dark mode', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.free,
        entitlements: _ents(
          plan: 'free',
          display: 'Free',
          unlimited: false,
          used: 2,
          remaining: 3,
          limit: 5,
        ),
        theme: AppTheme.darkTheme,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('YOUR MEMBERSHIP'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Upgrades coming soon'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Upgrades coming soon'), findsOneWidget);
    });

    testWidgets('large text scale builds', (tester) async {
      await _pumpPage(
        tester,
        plan: SubscriptionPlans.basic,
        entitlements: _ents(
          plan: 'basic',
          display: 'Basic',
          unlimited: false,
          used: 1,
          remaining: 14,
          limit: 15,
          nutritionistAllowed: true,
        ),
        textScale: 1.5,
        size: const Size(360, 1000),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('YOUR MEMBERSHIP'), findsOneWidget);
    });
  });
}
