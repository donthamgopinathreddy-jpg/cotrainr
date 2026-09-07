import 'dart:io';

import 'package:cotrainr/core/auth/user_role.dart';
import 'package:cotrainr/providers/accepted_client_trainers_provider.dart';
import 'package:cotrainr/providers/profile_role_provider.dart';
import 'package:cotrainr/providers/unread_video_session_notifications_provider.dart';
import 'package:cotrainr/services/leads_models.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/common/app_tab_page_header.dart';
import 'package:cotrainr/widgets/home_v3/quick_access_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedUser extends CurrentUserNotifier {
  _FixedUser(this.user);
  final CurrentUser user;

  @override
  Future<CurrentUser?> build() async => user;
}

CurrentUser _user(String role) => CurrentUser(
      id: 'u1',
      role: UserRoleParser.parse(role),
      fullName: 'Ada',
    );

class _EmptyTrainers extends AcceptedClientTrainersNotifier {
  @override
  Future<List<AcceptedTrainer>> build() async => const [];
}

class _EmptyNutritionists extends AcceptedClientNutritionistsNotifier {
  @override
  Future<List<AcceptedProvider>> build() async => const [];
}

List<Override> _exploreOverrides(CurrentUser user) {
  return [
    currentUserProvider.overrideWith(() => _FixedUser(user)),
    acceptedClientTrainersProvider.overrideWith(_EmptyTrainers.new),
    acceptedClientNutritionistsProvider.overrideWith(_EmptyNutritionists.new),
    acceptedClientTrainersCountProvider.overrideWith((ref) => 0),
    acceptedClientNutritionistsCountProvider.overrideWith((ref) => 0),
    unreadVideoSessionNotificationsProvider.overrideWith((ref) async => 0),
  ];
}

void main() {
  group('Provider Centres navigation contracts', () {
    test('shared /centres route uses DiscoverPage centersOnly', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router.contains("path: '/centres'"), isTrue);
      expect(router.contains('centersOnly: true'), isTrue);
      expect(router.contains('initialDiscoverTab: 2'), isTrue);
      expect(
        router.contains("import '../../pages/discover/discover_page.dart'"),
        isTrue,
      );
    });

    test('DiscoverPage centersOnly hides Trainers/Nutritionists tabs', () {
      final src =
          File('lib/pages/discover/discover_page.dart').readAsStringSync();
      expect(src.contains('final bool centersOnly'), isTrue);
      expect(src.contains("centersOnly ? 'CENTRES' : 'DISCOVER'"), isTrue);
      expect(src.contains('if (!widget.centersOnly)'), isTrue);
    });

    test('Explore Centres routes to /centres for providers', () {
      final src =
          File('lib/widgets/home_v3/quick_access_v3.dart').readAsStringSync();
      expect(src.contains("tiles['Centres']"), isTrue);
      expect(src.contains("context.push('/centres')"), isTrue);
      expect(src.contains('Find fitness and wellness centres nearby'), isTrue);
    });

    test('provider Find Partner Centres opens /centres not My Clients tab', () {
      final src =
          File('lib/pages/profile/cotrainr_pass_page.dart').readAsStringSync();
      final openFn =
          src.split('void _openPartnerCentres()')[1].split('void ')[0];
      expect(openFn.contains('if (isProvider)'), isTrue);
      expect(openFn.contains("context.push('/centres')"), isTrue);
      expect(
        openFn.contains("context.go('/home?tab=1&discover=centers')"),
        isTrue,
      );
    });

    test('home shell tab indices remain 0–4 with Discover/Clients at 1', () {
      final src =
          File('lib/pages/home/home_shell_page.dart').readAsStringSync();
      expect(
        src.contains(
          '0 Home, 1 Discover/My Clients, 2 Messages, 3 Meals, 4 Profile',
        ),
        isTrue,
      );
      expect(
        src.contains("label: isProvider ? 'My Clients' : 'Discover'"),
        isTrue,
      );
    });

    test('My Clients uses AppTabPageHeader with purple clientsGradient', () {
      final src = File('lib/pages/provider/provider_my_clients_page.dart')
          .readAsStringSync();
      expect(src.contains('AppTabPageHeader'), isTrue);
      expect(src.contains('AppTabPageHeader.clientsGradient'), isTrue);
      expect(src.contains('Icons.groups_rounded'), isTrue);
      expect(src.contains("title: 'My Clients'"), isTrue);
      expect(
        File('lib/widgets/common/app_tab_page_header.dart')
            .readAsStringSync()
            .contains('clientsGradient'),
        isTrue,
      );
    });
  });

  group('Provider Explore Centres widget', () {
    testWidgets('trainer sees Centres tile', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
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
      expect(find.text('Centres'), findsOneWidget);
      expect(find.text('Nutrition Goals'), findsOneWidget);
      expect(find.text('Video Sessions'), findsOneWidget);
      expect(find.text('Trainers & Nutritionists'), findsNothing);
    });

    testWidgets('nutritionist sees Centres tile', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('nutritionist')),
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
      expect(find.text('Centres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('client Explore does not show standalone Centres tile',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
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
      expect(find.text('Centres'), findsNothing);
      expect(find.text('Trainers & Nutritionists'), findsOneWidget);
    });

    testWidgets('AppTabPageHeader clientsGradient renders MY CLIENTS',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppTabPageHeader(
              icon: Icons.groups_rounded,
              title: 'My Clients',
              gradient: AppTabPageHeader.clientsGradient,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MY CLIENTS'), findsOneWidget);
      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    });

    testWidgets('larger text scale Explore builds for trainer', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _exploreOverrides(_user('trainer')),
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: QuickAccessV3()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Centres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
