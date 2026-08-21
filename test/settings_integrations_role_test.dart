// Tests for Settings → Integrations role visibility.
//
// Requirements:
//   - Trainer: sees Integrations row in Settings
//   - Nutritionist: sees Integrations row in Settings
//   - Client/Member: does NOT see Integrations row in Settings
//   - Client direct-route to IntegrationsPage is rejected (page pops)
//   - Provider Integrations page renders Google Meet content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/profile/settings/integrations_page.dart';
import 'package:cotrainr/pages/profile/settings_page.dart';
import 'package:cotrainr/repositories/profile_repository.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Fake ProfileRepository
// ---------------------------------------------------------------------------

class _FakeProfileRepo implements ProfileRepository {
  final String role;
  _FakeProfileRepo(this.role);

  @override
  Future<Map<String, dynamic>?> fetchMyProfile() async =>
      {'role': role, 'full_name': 'Test User', 'id': 'test-uid'};

  // All other ProfileRepository methods are not called in these tests.
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FailingProfileRepo implements ProfileRepository {
  @override
  Future<Map<String, dynamic>?> fetchMyProfile() async =>
      throw Exception('auth error');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Fake VideoSessionsRepository (returns disconnected status)
// ---------------------------------------------------------------------------

class _FakeVideoRepo implements VideoSessionsRepository {
  @override
  Future<GoogleMeetIntegrationStatus> getGoogleMeetStatus() async =>
      GoogleMeetIntegrationStatus.disconnected();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _settingsPage(String role) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: SettingsPage(
        profileRepository: _FakeProfileRepo(role),
        appVersionLoader: () async => '1.0.0',
      ),
    ),
  );
}

Widget _integrationsPage(String role) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => IntegrationsPage(
          profileRepository: _FakeProfileRepo(role),
          videoSessionsRepository: _FakeVideoRepo(),
        ),
      ),
    ),
  );
}

Widget _integrationsPageFailingAuth() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => IntegrationsPage(
          profileRepository: _FailingProfileRepo(),
          videoSessionsRepository: _FakeVideoRepo(),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Settings page role visibility
  // -------------------------------------------------------------------------

  group('Settings page — Integrations row visibility', () {
    testWidgets('trainer sees Integrations row', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_settingsPage('trainer'));
      await tester.pumpAndSettle();

      expect(find.text('Integrations'), findsOneWidget);
      expect(find.text('Google Meet'), findsOneWidget);
    });

    testWidgets('nutritionist sees Integrations row', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_settingsPage('nutritionist'));
      await tester.pumpAndSettle();

      expect(find.text('Integrations'), findsOneWidget);
      expect(find.text('Google Meet'), findsOneWidget);
    });

    testWidgets('client does NOT see Integrations row', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_settingsPage('client'));
      await tester.pumpAndSettle();

      expect(find.text('Integrations'), findsNothing);
      // The subtitle "Google Meet" should also be absent in the settings list.
      // (It may appear inside the Integrations page — but that page is not open.)
      expect(find.text('Google Meet'), findsNothing);
    });

    testWidgets('member role does NOT see Integrations row', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_settingsPage('member'));
      await tester.pumpAndSettle();

      expect(find.text('Integrations'), findsNothing);
    });

    testWidgets('trainer still sees Service Locations', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_settingsPage('trainer'));
      await tester.pumpAndSettle();

      expect(find.text('Service Locations'), findsOneWidget);
    });

    testWidgets('client does not see Service Locations', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_settingsPage('client'));
      await tester.pumpAndSettle();

      expect(find.text('Service Locations'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // IntegrationsPage direct-route guard
  // -------------------------------------------------------------------------

  group('IntegrationsPage — direct route access guard', () {
    testWidgets('trainer can access IntegrationsPage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_integrationsPage('trainer'));
      await tester.pumpAndSettle();

      // Trainer sees the Integrations scaffold with Google Meet content.
      expect(find.text('Integrations'), findsOneWidget);
      expect(find.text('Google Meet'), findsOneWidget);
    });

    testWidgets('nutritionist can access IntegrationsPage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_integrationsPage('nutritionist'));
      await tester.pumpAndSettle();

      expect(find.text('Integrations'), findsOneWidget);
      expect(find.text('Google Meet'), findsOneWidget);
    });

    testWidgets('client direct-route is blocked — page pops', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Use a Navigator with a home route so we can verify the page pops back.
      final popped = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(ctx).push<void>(
                      MaterialPageRoute(
                        builder: (_) => IntegrationsPage(
                          profileRepository: _FakeProfileRepo('client'),
                          videoSessionsRepository: _FakeVideoRepo(),
                        ),
                      ),
                    );
                    popped.add(true);
                  },
                  child: const Text('Open Integrations'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Integrations'));
      // Allow access check future + postFrameCallback to complete.
      await tester.pumpAndSettle();

      // The page must have popped — Google Meet content must not be visible.
      expect(find.text('Google Meet'), findsNothing);
      expect(find.text('Integrations'), findsNothing);
      // The triggering button should be back.
      expect(find.text('Open Integrations'), findsOneWidget);
      // Route was pushed and then popped.
      expect(popped, [true]);
    });

    testWidgets('member direct-route is blocked — page pops', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final popped = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(ctx).push<void>(
                      MaterialPageRoute(
                        builder: (_) => IntegrationsPage(
                          profileRepository: _FakeProfileRepo('member'),
                          videoSessionsRepository: _FakeVideoRepo(),
                        ),
                      ),
                    );
                    popped.add(true);
                  },
                  child: const Text('Open Integrations'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Integrations'));
      await tester.pumpAndSettle();

      expect(find.text('Google Meet'), findsNothing);
      expect(popped, [true]);
    });

    testWidgets('auth failure blocks access and pops', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final popped = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(ctx).push<void>(
                      MaterialPageRoute(
                        builder: (_) => IntegrationsPage(
                          profileRepository: _FailingProfileRepo(),
                          videoSessionsRepository: _FakeVideoRepo(),
                        ),
                      ),
                    );
                    popped.add(true);
                  },
                  child: const Text('Open Integrations'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Integrations'));
      await tester.pumpAndSettle();

      expect(find.text('Google Meet'), findsNothing);
      expect(popped, [true]);
    });
  });

  // -------------------------------------------------------------------------
  // Provider Integrations page content
  // -------------------------------------------------------------------------

  group('IntegrationsPage — provider content', () {
    testWidgets('shows Google Meet section with Connect button when disconnected',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_integrationsPage('trainer'));
      await tester.pumpAndSettle();

      expect(find.text('Google Meet'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect Google Meet'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
    });

    testWidgets('does not expose OAuth tokens or raw integration metadata',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_integrationsPage('nutritionist'));
      await tester.pumpAndSettle();

      // Token strings should never appear in the UI.
      expect(find.textContaining('token'), findsNothing);
      expect(find.textContaining('refresh_token'), findsNothing);
      expect(find.textContaining('access_token'), findsNothing);
      expect(find.textContaining('client_secret'), findsNothing);
    });
  });
}
