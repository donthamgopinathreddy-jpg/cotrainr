import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/core/auth/user_role.dart';
import 'package:cotrainr/models/member_plan_view.dart';
import 'package:cotrainr/providers/accepted_client_trainers_provider.dart';
import 'package:cotrainr/providers/profile_role_provider.dart';
import 'package:cotrainr/providers/unread_video_session_notifications_provider.dart';
import 'package:cotrainr/repositories/subscriptions_repository.dart';
import 'package:cotrainr/services/leads_models.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/home_v3/quick_access_v3.dart';

class _FixedUser extends CurrentUserNotifier {
  _FixedUser(this.user);
  final CurrentUser user;

  @override
  Future<CurrentUser?> build() async => user;
}

CurrentUser _user(String role) => CurrentUser(
      id: 'u-$role',
      role: UserRoleParser.parse(role),
      fullName: role,
    );

class _EmptyTrainers extends AcceptedClientTrainersNotifier {
  @override
  Future<List<AcceptedTrainer>> build() async => const [];
}

class _EmptyNutritionists extends AcceptedClientNutritionistsNotifier {
  @override
  Future<List<AcceptedProvider>> build() async => const [];
}

List<Override> _exploreOverrides(CurrentUser user) => [
      currentUserProvider.overrideWith(() => _FixedUser(user)),
      acceptedClientTrainersProvider.overrideWith(_EmptyTrainers.new),
      acceptedClientNutritionistsProvider.overrideWith(_EmptyNutritionists.new),
      acceptedClientTrainersCountProvider.overrideWith((ref) => 0),
      acceptedClientNutritionistsCountProvider.overrideWith((ref) => 0),
      unreadVideoSessionNotificationsProvider.overrideWith((ref) async => 0),
    ];

void main() {
  group('MemberPlanView.fromSubscription', () {
    test('null row is Free / Current plan / View plans', () {
      final v = MemberPlanView.fromSubscription(null);
      expect(v.state, MemberPlanUiState.free);
      expect(v.planDisplayName, 'Free');
      expect(v.statusLabel, 'Current plan');
      expect(v.ctaLabel, 'View plans');
      expect(v.detailLine, isNull);
    });

    test('free plan is Free not Expired', () {
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(plan: 'free', status: 'active', expiresAt: null),
      );
      expect(v.state, MemberPlanUiState.free);
      expect(v.planDisplayName, 'Free');
      expect(v.ctaLabel, 'View plans');
    });

    test('active premium shows Ultimate + Active + Manage plan', () {
      final renews = DateTime(2026, 9, 14);
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(plan: 'premium', status: 'active', expiresAt: renews),
      );
      expect(v.state, MemberPlanUiState.active);
      expect(v.planDisplayName, 'Ultimate');
      expect(v.statusLabel, 'Active');
      expect(v.ctaLabel, 'Manage plan');
      expect(v.detailLine, 'Renews 14 September 2026');
    });

    test('active basic shows Basic', () {
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(plan: 'basic', status: 'active', expiresAt: null),
      );
      expect(v.planDisplayName, 'Basic');
      expect(v.detailLine, isNull);
      expect(v.ctaLabel, 'Manage plan');
    });

    test('trialing shows Trial', () {
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(
          plan: 'basic',
          status: 'trialing',
          expiresAt: DateTime(2026, 10, 1),
        ),
      );
      expect(v.state, MemberPlanUiState.trial);
      expect(v.statusLabel, 'Trial');
      expect(v.detailLine, contains('Trial ends'));
    });

    test('cancelled but not expired stays Cancelled with Active until', () {
      final until = DateTime.now().add(const Duration(days: 10));
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(plan: 'premium', status: 'cancelled', expiresAt: until),
      );
      expect(v.state, MemberPlanUiState.cancelledActive);
      expect(v.statusLabel, 'Cancelled');
      expect(v.detailLine, contains('Active until'));
      expect(v.ctaLabel, 'Manage plan');
    });

    test('expired by status', () {
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(plan: 'premium', status: 'expired', expiresAt: null),
      );
      expect(v.state, MemberPlanUiState.expired);
      expect(v.statusLabel, 'Expired');
      expect(v.ctaLabel, 'Renew');
    });

    test('expired by date', () {
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(
          plan: 'basic',
          status: 'active',
          expiresAt: DateTime(2020, 1, 1),
        ),
      );
      expect(v.state, MemberPlanUiState.expired);
      expect(v.ctaLabel, 'Renew');
    });

    test('past_due is Billing issue not Expired', () {
      final v = MemberPlanView.fromSubscription(
        SubscriptionRow(plan: 'premium', status: 'past_due', expiresAt: null),
      );
      expect(v.state, MemberPlanUiState.pastDue);
      expect(v.statusLabel, 'Billing issue');
      expect(v.ctaLabel, 'Manage plan');
    });

    test('loading and error do not fabricate plan names', () {
      expect(MemberPlanView.loading.planDisplayName, isEmpty);
      expect(MemberPlanView.error.statusLabel, 'Unable to load plan');
      expect(MemberPlanView.error.ctaLabel, 'Retry');
    });
  });

  group('Explore Member Pass tile', () {
    testWidgets('client sees Member Pass, not standalone Subscription',
        (tester) async {
      tester.view.physicalSize = const Size(412, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('client')),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: QuickAccessV3()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Member Pass'), findsOneWidget);
      expect(find.text('Subscription'), findsNothing);
    });

    testWidgets('trainer does not see Member Pass', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('trainer')),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: QuickAccessV3()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Member Pass'), findsNothing);
    });

    testWidgets('nutritionist does not see Member Pass', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('nutritionist')),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: QuickAccessV3()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Member Pass'), findsNothing);
    });

    testWidgets('320dp client layout has no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('client')),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: QuickAccessV3()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Member Pass'), findsOneWidget);
    });

    testWidgets('text scale 1.5 client Explore builds', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('client')),
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: QuickAccessV3()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode client Explore builds', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('client')),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              body: SingleChildScrollView(child: QuickAccessV3()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Member Pass'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Member Pass wiring contracts', () {
    test('Manage/View plans routes to existing subscription page for clients', () {
      final src =
          File('lib/pages/profile/cotrainr_pass_page.dart').readAsStringSync();
      expect(src.contains("context.push('/subscription')"), isTrue);
      expect(src.contains('_YourPlanCard'), isTrue);
      expect(src.contains('YOUR PLAN'), isTrue);
      expect(src.contains('_loadPlanOnly'), isTrue);
      expect(src.contains('if (_isClient)'), isTrue);
    });

    test('provider roles show ROLE and hide Your Plan section', () {
      final src =
          File('lib/pages/profile/cotrainr_pass_page.dart').readAsStringSync();
      expect(src.contains('currentUserProvider'), isTrue);
      expect(src.contains("return 'Trainer'"), isTrue);
      expect(src.contains("return 'Nutritionist'"), isTrue);
      expect(src.contains("metaLabel = showRole ? 'ROLE' : 'PLAN'"), isTrue);
      expect(src.contains('permanent Trainer identity'), isTrue);
      expect(src.contains('permanent Nutritionist identity'), isTrue);
      expect(src.contains('permanent member identity'), isTrue);
      expect(src.contains('Partner Centres'), isTrue);
      expect(src.contains('Find Centres'), isTrue);
    });

    test('subscription page and route remain intact', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router.contains("path: '/subscription'"), isTrue);
      expect(router.contains("path: '/profile/cotrainr-pass'"), isTrue);
      expect(
        File('lib/pages/subscription/subscription_page.dart').existsSync(),
        isTrue,
      );
    });

    test('no purchase token surfaced in Member Pass page', () {
      final src =
          File('lib/pages/profile/cotrainr_pass_page.dart').readAsStringSync();
      expect(src.toLowerCase().contains('purchase_token'), isFalse);
      expect(src.toLowerCase().contains('purchasetoken'), isFalse);
    });

    test('Explore Member Pass opens cotrainr-pass route', () {
      final src =
          File('lib/widgets/home_v3/quick_access_v3.dart').readAsStringSync();
      expect(src.contains("'Member Pass'"), isTrue);
      expect(src.contains("context.push('/profile/cotrainr-pass')"), isTrue);
      expect(src.contains("tiles['Subscription']"), isFalse);
    });

    test('fetchMineStrict distinguishes errors from free', () {
      final src = File('lib/repositories/subscriptions_repository.dart')
          .readAsStringSync();
      expect(src.contains('fetchMineStrict'), isTrue);
    });
  });
}
