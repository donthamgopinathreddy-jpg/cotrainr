import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:cotrainr/pages/profile/settings/privacy_security_page.dart';
import 'package:cotrainr/services/location_permission_status.dart';
import 'package:cotrainr/services/privacy_preferences_service.dart';

class _FakePrefsStore implements PrivacyPreferencesStore {
  PrivacyPreferences value = const PrivacyPreferences(
    shareActivityWithTrainer: true,
    shareMealsWithTrainer: false,
    shareNutritionWithNutritionist: true,
  );

  @override
  Future<PrivacyPreferences> load() async => value;

  @override
  Future<void> save(PrivacyPreferences prefs) async {
    value = prefs;
  }
}

class _FakeLocationGateway extends LocationPermissionGateway {
  LocationPermission permission = LocationPermission.whileInUse;
  bool serviceEnabled = true;
  int manageCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> check() async => permission;

  @override
  Future<LocationPermission> request() async => permission;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<void> manage() async {
    manageCalls++;
  }
}

void main() {
  testWidgets('Privacy & Security MVP controls are truthful', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = _FakePrefsStore();
    final location = _FakeLocationGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySecurityPage(
          preferencesService: prefs,
          locationGateway: location,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Share Activity Data with Trainer'), findsOneWidget);
    expect(find.text('Share Meal Data with Trainer'), findsOneWidget);
    expect(find.text('Share Meal Logs with Nutritionist'), findsOneWidget);
    expect(find.textContaining('Share Health Metrics'), findsNothing);
    expect(find.text('Two-Factor Authentication'), findsNothing);
    expect(find.text('Active Sessions'), findsNothing);
    expect(find.text('Location Access'), findsNothing);
    expect(find.textContaining('While using app'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Privacy Policy'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Download My Data'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Request Account Deletion'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('support@cotrainr.com'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Contact Support'), findsOneWidget);
    expect(find.text('support@cotrainr.com'), findsOneWidget);
    expect(find.text('noreply@cotrainr.com'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Manage'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Manage'));
    await tester.pump();
    expect(location.manageCalls, 1);

    await tester.scrollUntilVisible(
      find.text('Request Account Deletion'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Request Account Deletion'));
    await tester.pumpAndSettle();
    expect(find.text('Request Account Deletion'), findsWidgets);
    expect(
      find.textContaining('not available in the app yet'),
      findsOneWidget,
    );
    expect(find.textContaining('cannot be undone'), findsNothing);
  });
}
