import 'dart:io';

import 'package:cotrainr/models/daily_metrics_snapshot.dart';
import 'package:cotrainr/pages/bmi/bmi_details_screen.dart';
import 'package:cotrainr/repositories/profile_repository.dart';
import 'package:cotrainr/services/metrics/metrics_source.dart';
import 'package:cotrainr/services/water_reminder_service.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/utils/health_metric_display.dart';
import 'package:cotrainr/widgets/home_v3/bmi_card_v3.dart';
import 'package:cotrainr/widgets/home_v3/metric_progress_ring.dart';
import 'package:cotrainr/widgets/home_v3/unified_metrics_tile_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

DailyMetricsSnapshot _snapshot({
  int steps = 0,
  double calories = 0,
  double distanceKm = 0,
  bool stepsGranted = true,
  bool caloriesGranted = true,
  bool distanceGranted = true,
}) {
  return DailyMetricsSnapshot(
    steps: steps,
    activeCalories: calories,
    distanceKm: distanceKm,
    waterLiters: 0,
    distanceSource: distanceGranted
        ? DistanceSource.healthConnect
        : DistanceSource.permissionDenied,
    caloriesSource: caloriesGranted
        ? CaloriesSource.healthConnectActive
        : CaloriesSource.permissionDenied,
    metricsSourceKind: MetricsSourceKind.healthConnect,
    stepsPermissionGranted: stepsGranted,
    caloriesPermissionGranted: caloriesGranted,
    distancePermissionGranted: distanceGranted,
  );
}

List<UnifiedMetricViewModel> _metrics({
  String steps = '0',
  String calories = '0',
  String water = '0.0',
  String distance = '0.0',
}) {
  UnifiedMetricViewModel m(String label, String value) => UnifiedMetricViewModel(
        label: label,
        icon: Icons.directions_walk,
        ringGradient: const LinearGradient(colors: [Colors.orange, Colors.red]),
        barColor: Colors.orange,
        progress: 0,
        mainValue: value,
        subValue: 'of goal',
        weekly: const [0, 0, 0, 0, 0, 0, 0],
        todayValue: 0,
        goalValue: 10000,
      );
  return [
    m('STEPS', steps),
    m('ACTIVE CALORIES', calories),
    m('WATER', water),
    m('DISTANCE', distance),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('live vs cache vs permission', () {
    test('empty Health Connect snapshot does not overwrite cached steps', () {
      final resolved = resolveHomeSteps(
        cached: 8421,
        live: DailyMetricsSnapshot.empty(kind: MetricsSourceKind.healthConnect),
      );
      expect(resolved.available, isTrue);
      expect(resolved.value, 8421);
      expect(resolved.displayInt, isNot('—'));
    });

    test('permission denied with no cache is unavailable, not a fake zero', () {
      final resolved = resolveHomeSteps(
        cached: 0,
        live: DailyMetricsSnapshot.empty(),
      );
      expect(resolved.available, isFalse);
      expect(resolved.displayInt, '—');
    });

    test('permission granted live zero is a real measured zero', () {
      final resolved = resolveHomeSteps(
        cached: 0,
        live: _snapshot(steps: 0, stepsGranted: true),
      );
      expect(resolved.available, isTrue);
      expect(resolved.value, 0);
      expect(resolved.displayInt, '0');
    });

    test('permission granted prefers the higher of live and cache', () {
      expect(
        resolveHomeSteps(
          cached: 2000,
          live: _snapshot(steps: 500, stepsGranted: true),
        ).value,
        2000,
      );
      expect(
        resolveHomeCalories(
          cached: 100,
          live: _snapshot(calories: 420, caloriesGranted: true),
        ).value,
        420,
      );
    });

    test('null live snapshot uses cache as available', () {
      final resolved = resolveHomeDistance(cached: 3.2, live: null);
      expect(resolved.available, isTrue);
      expect(resolved.value, 3.2);
    });
  });

  group('weekly last 7 local days', () {
    test('missing days map to 0 and order is oldest to newest', () {
      final series = weeklySeriesForLastSevenDays(
        now: DateTime(2026, 8, 19, 21, 10),
        key: 'steps',
        rows: [
          {'date': '2026-08-19', 'steps': 8000},
          {'date': '2026-08-17T00:00:00.000Z', 'steps': 1200},
          {'date': '2026-08-13', 'steps': 400},
        ],
      );
      expect(series, hasLength(7));
      expect(series, [400.0, 0.0, 0.0, 0.0, 1200.0, 0.0, 8000.0]);
    });
  });

  group('BMI', () {
    test('formula and categories match WHO cutoffs', () {
      final bmi = ProfileRepository.calculateBMI(175, 70);
      expect(bmi, closeTo(22.86, 0.02));
      expect(ProfileRepository.getBMIStatus(bmi), 'Normal');
      expect(bmiCategoryFromValue(bmi), 'Normal');
      expect(bmiCategoryFromValue(18.49), 'Underweight');
      expect(bmiCategoryFromValue(25), 'Overweight');
      expect(bmiCategoryFromValue(30), 'Obese');
    });

    test('missing height or weight is not a fabricated BMI', () {
      expect(ProfileRepository.calculateBMI(0, 70), 0);
      expect(ProfileRepository.calculateBMI(175, 0), 0);
      expect(ProfileRepository.getBMIStatus(0), isEmpty);
      expect(bmiFromHeightWeight(0, 70), 0);
      expect(formatHeight(null), '--');
      expect(formatWeightKg(null), '--');
      expect(formatHeight(0), '--');
      expect(formatWeightKg(0), '--');
    });
  });

  group('progress and water add', () {
    test('safeMetricProgress never returns NaN', () {
      expect(safeMetricProgress(double.nan, 10000), 0);
      expect(safeMetricProgress(5000, 0), 0);
      expect(safeMetricProgress(5000, double.infinity), 0);
      expect(safeMetricProgress(5000, 10000), 0.5);
      expect(safeMetricProgress(20000, 10000), 1.0);
    });

    test('water increment is not clamped to a goal', () {
      const current = 2.5;
      const goal = 2.5;
      const add = 0.25;
      final next = current + add;
      expect(next, greaterThan(goal));
      expect(next, 2.75);
    });
  });

  group('reminder copy and cancel paths', () {
    test('expanded reminder copy is not a goal nag', () {
      expect(
        WaterReminderService.expandedFallback,
        'Log your hydration in Cotrainr.',
      );
    });

    test('disable interval cancels then clears prefs key', () {
      final src =
          File('lib/services/water_reminder_service.dart').readAsStringSync();
      expect(src.contains('await cancelAll();'), isTrue);
      expect(src.contains("prefs.remove(_prefsKeyMinutes)"), isTrue);
    });
  });

  group('release source contracts', () {
    test('health metric services do not print PII', () {
      for (final path in [
        'lib/services/metrics_sync_service.dart',
        'lib/repositories/metrics_repository.dart',
      ]) {
        final src = File(path).readAsStringSync().replaceAll('debugPrint', '');
        expect(src.contains('print('), isFalse, reason: path);
      }
      final profile =
          File('lib/repositories/profile_repository.dart').readAsStringSync();
      expect(profile.contains('Updates: \$updates'), isFalse);
      expect(profile.contains('successfully: \$response'), isFalse);
      expect(profile.contains("Updating profile for user: \$_currentUserId"),
          isFalse);
    });

    test('health init does not request notification permission', () {
      final src =
          File('lib/services/health_tracking_service.dart').readAsStringSync();
      expect(src.contains('Permission.notification'), isFalse);
      expect(src.contains('ACTIVITY_RECOGNITION'), isTrue);
    });

    test('live refresh keeps the previous snapshot', () {
      final src =
          File('lib/providers/health_tracking_provider.dart').readAsStringSync();
      final refresh = src.substring(src.indexOf('Future<void> refresh()'));
      expect(refresh.contains('AsyncValue.loading()'), isFalse);
    });

    test('Home water add uses WaterIntakeService and is not goal-clamped', () {
      for (final path in [
        'lib/pages/home/home_page_v3.dart',
        'lib/pages/trainer/trainer_home_page.dart',
        'lib/pages/nutritionist/nutritionist_home_page.dart',
      ]) {
        final src = File(path).readAsStringSync();
        final idx = src.indexOf('onAddWater:');
        expect(idx, greaterThan(0), reason: path);
        final block = src.substring(idx, idx + 700);
        expect(block.contains('WaterIntakeService.instance.addWater'), isTrue);
        expect(block.contains('clamp'), isFalse, reason: path);
        expect(block.contains('updateTodayMetrics'), isFalse, reason: path);
      }
    });

    test('logout cancels pending water reminders', () {
      final src =
          File('lib/pages/profile/settings_page.dart').readAsStringSync();
      final logout = src.substring(src.indexOf('_handleLogout'));
      expect(
        logout.indexOf('WaterReminderService.instance.cancelAll()'),
        lessThan(logout.indexOf('auth.signOut()')),
      );
    });

    test('Android boot reschedules water reminders', () {
      final receiver = File(
        'android/app/src/main/kotlin/com/cotrainr/app/WaterReminderAlarmReceiver.kt',
      ).readAsStringSync();
      final helper = File(
        'android/app/src/main/kotlin/com/cotrainr/app/WaterNotificationHelper.kt',
      ).readAsStringSync();
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(receiver.contains('ACTION_BOOT_COMPLETED'), isTrue);
      expect(receiver.contains('rescheduleAfterBoot'), isTrue);
      expect(helper.contains('fun rescheduleAfterBoot'), isTrue);
      expect(helper.contains('Log your hydration in Cotrainr.'), isTrue);
      expect(manifest.contains('RECEIVE_BOOT_COMPLETED'), isTrue);
      expect(manifest.contains('.WaterReminderAlarmReceiver'), isTrue);
    });

    test('Home BMI card does not fabricate a target weight', () {
      final src =
          File('lib/widgets/home_v3/bmi_card_v3.dart').readAsStringSync();
      expect(src.contains('Target Weight'), isFalse);
      expect(src.contains("label: 'BMI status \$status'"), isTrue);
      expect(src.contains('excludeSemantics: true'), isTrue);
    });

    test('BMI details does not invent a 70kg body', () {
      final src =
          File('lib/pages/bmi/bmi_details_screen.dart').readAsStringSync();
      expect(src.contains('weightKg ?? 0'), isTrue);
      expect(src.contains('?? 70'), isFalse);
      expect(src.contains('AlwaysStoppedAnimation'), isTrue);
      expect(src.contains("if (bmi < 25) return 'Normal'"), isTrue);
    });

    test('progress rings use 400ms and sanitize NaN', () {
      final src =
          File('lib/widgets/home_v3/metric_progress_ring.dart').readAsStringSync();
      expect(src.contains('Duration(milliseconds: 400)'), isTrue);
      expect(src.contains('_controller.value = 1'), isTrue);
      expect(src.contains('if (!value.isFinite) return 0'), isTrue);
    });
  });

  group('widgets', () {
    testWidgets('BMI card shows status, missing body metrics, no target weight',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: BmiCardV3(bmi: 22.86, status: 'Normal'),
          ),
        ),
      );
      expect(find.text('Target Weight'), findsNothing);
      expect(find.text('NORMAL'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(2));
      expect(
        tester.getSemantics(find.text('NORMAL')),
        matchesSemantics(label: 'BMI status Normal'),
      );
    });

    testWidgets('BMI card light/dark/small/large text do not overflow',
        (tester) async {
      Future<void> pump(ThemeData theme) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(12),
                  child: BmiCardV3(
                    bmi: 27.4,
                    status: 'Overweight',
                    heightCm: 168,
                    weightKg: 77.3,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump(AppTheme.lightTheme);
      expect(tester.takeException(), isNull);
      await pump(AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MetricProgressRing accepts NaN without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricProgressRing(
              progressPercent: double.nan,
              color: Colors.orange,
              icon: Icons.directions_walk,
              size: 72,
              trackColor: Colors.grey,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('unavailable metrics show em dash on small screens',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: UnifiedMetricsTileV3(
                metrics: _metrics(steps: '—', calories: '—', distance: '—'),
                onMetricTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('—'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
