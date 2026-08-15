import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotrainr/pages/profile/edit_profile_save_state.dart';
import 'package:cotrainr/pages/profile/settings/notifications_page.dart';
import 'package:cotrainr/pages/profile/settings_page.dart';
import 'package:cotrainr/services/fitness_notification_preferences_service.dart';
import 'package:cotrainr/services/os_notification_permission_status.dart';
import 'package:cotrainr/theme/account_hub_theme.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/profile/account_hub_widgets.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakeNotifStore implements FitnessNotificationPreferencesStore {
  FitnessNotificationPreferences value = const FitnessNotificationPreferences();
  int saveCount = 0;

  @override
  Future<FitnessNotificationPreferences> load() async => value;

  @override
  Future<void> save(FitnessNotificationPreferences prefs) async {
    saveCount++;
    value = prefs;
  }
}

class _FakeOsGateway extends OsNotificationPermissionGateway {
  OsNotificationAccessLabel label = OsNotificationAccessLabel.allowed;
  int manageCalls = 0;

  @override
  Future<PermissionStatus> check() async => PermissionStatus.granted;

  @override
  Future<OsNotificationAccessLabel> readLabel() async => label;

  @override
  Future<void> manage() async {
    manageCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Settings Fitness section', () {
    testWidgets('Units absent; Goals & Health Connect remain', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsFitnessSection(
              onOpenGoals: () {},
              onOpenHealthConnect: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goals & Preferences'), findsOneWidget);
      expect(find.text('Health Connect'), findsOneWidget);
      expect(find.text('Units'), findsNothing);
      expect(find.text('Coming soon'), findsNothing);
    });
  });

  group('Notifications MVP surface', () {
    testWidgets('only verified MVP categories render', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = _FakeNotifStore();
      final os = _FakeOsGateway();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: NotificationsPage(
            preferencesService: store,
            osPermissionGateway: os,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All notifications'), findsOneWidget);
      expect(find.text('Water reminders'), findsOneWidget);
      expect(find.text('System notifications'), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      expect(find.text('Trainer messages'), findsNothing);
      expect(find.text('Nutritionist messages'), findsNothing);
      expect(find.text('Meal reminders'), findsNothing);
      expect(find.text('Workout reminders'), findsNothing);
      expect(find.text('Goal progress'), findsNothing);
      expect(find.text('Achievement alerts'), findsNothing);
    });

    testWidgets('master off disables water; value preserved on save',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = _FakeNotifStore()
        ..value = const FitnessNotificationPreferences(
          all: true,
          waterReminders: true,
        );
      final os = _FakeOsGateway();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: NotificationsPage(
            preferencesService: store,
            osPermissionGateway: os,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(store.value.all, isFalse);
      expect(store.value.waterReminders, isTrue);
      expect(store.saveCount, 1);

      final waterTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Water reminders'),
      );
      expect(waterTile.onChanged, isNull);
      expect(waterTile.value, isTrue);
    });

    testWidgets('OS denied shows truthful note', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final os = _FakeOsGateway()
        ..label = OsNotificationAccessLabel.denied;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: NotificationsPage(
            preferencesService: _FakeNotifStore(),
            osPermissionGateway: os,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Denied'), findsWidgets);
      expect(
        find.textContaining('cannot override system notification permission'),
        findsOneWidget,
      );
    });

    testWidgets('light and dark themes build; text scale ok', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
              theme: theme,
              home: NotificationsPage(
                preferencesService: _FakeNotifStore(),
                osPermissionGateway: _FakeOsGateway(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('All notifications'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));
      }
    });
  });

  group('Edit Profile Save gate', () {
    test('disabled when clean; enabled when dirty+valid; blocked while saving',
        () {
      expect(
        editProfileCanSave(dirty: false, valid: true, saving: false),
        isFalse,
      );
      expect(
        editProfileCanSave(dirty: true, valid: true, saving: false),
        isTrue,
      );
      expect(
        editProfileCanSave(dirty: true, valid: false, saving: false),
        isFalse,
      );
      expect(
        editProfileCanSave(dirty: true, valid: true, saving: true),
        isFalse,
      );
    });

    test('form validation mirrors required fields', () {
      expect(
        editProfileFormLooksValid(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
          phone: '',
          dob: '1990-01-01',
          heightRaw: '170',
          weightRaw: '65',
          goalWeight: '',
        ),
        isTrue,
      );
      expect(
        editProfileFormLooksValid(
          firstName: '',
          lastName: 'Lovelace',
          email: 'ada@example.com',
          phone: '',
          dob: '1990-01-01',
          heightRaw: '170',
          weightRaw: '65',
          goalWeight: '',
        ),
        isFalse,
      );
      expect(
        editProfileFormLooksValid(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'not-an-email',
          phone: '',
          dob: '1990-01-01',
          heightRaw: '170',
          weightRaw: '65',
          goalWeight: '',
        ),
        isFalse,
      );
    });
  });

  group('Switch theme', () {
    test('shared Cotrainr switch theme defined for light and dark', () {
      final light = AccountHubTheme.switchTheme(isDark: false);
      final dark = AccountHubTheme.switchTheme(isDark: true);
      expect(light.trackColor, isNotNull);
      expect(dark.trackColor, isNotNull);
      expect(AppTheme.lightTheme.switchTheme.trackColor, isNotNull);
      expect(AppTheme.darkTheme.switchTheme.trackColor, isNotNull);
    });

    testWidgets('HubToggleRow uses SwitchListTile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HubToggleRow(
              title: 'Sample',
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('Water preference gate', () {
    test('allowsWaterReminders respects master and water keys', () async {
      SharedPreferences.setMockInitialValues({
        FitnessNotificationPreferencesService.allKey: false,
        FitnessNotificationPreferencesService.waterRemindersKey: true,
      });
      expect(
        await FitnessNotificationPreferencesService.allowsWaterReminders(),
        isFalse,
      );

      SharedPreferences.setMockInitialValues({
        FitnessNotificationPreferencesService.allKey: true,
        FitnessNotificationPreferencesService.waterRemindersKey: false,
      });
      expect(
        await FitnessNotificationPreferencesService.allowsWaterReminders(),
        isFalse,
      );

      SharedPreferences.setMockInitialValues({
        FitnessNotificationPreferencesService.allKey: true,
        FitnessNotificationPreferencesService.waterRemindersKey: true,
      });
      expect(
        await FitnessNotificationPreferencesService.allowsWaterReminders(),
        isTrue,
      );
    });
  });
}
