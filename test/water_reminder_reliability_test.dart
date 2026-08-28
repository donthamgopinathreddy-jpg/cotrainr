import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotrainr/services/hydration_local_store.dart';
import 'package:cotrainr/services/water_reminder_service.dart';

/// Reliability contract for Android hydration reminders and their +250/+500
/// notification actions.
///
/// The scheduling and the increment itself run in Kotlin (they must work with
/// no Flutter engine alive), so those halves are covered by source contract
/// assertions over the native files. The Dart reconciliation half is covered by
/// real unit tests against [HydrationLocalStore].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String readNative(String name) =>
      File('android/app/src/main/kotlin/com/cotrainr/app/$name').readAsStringSync();

  String readDart(String path) => File(path).readAsStringSync();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ------------------------------------------------------------------
  // A. Scheduling
  // ------------------------------------------------------------------
  group('reminder scheduling', () {
    test('does not use a Dart Timer or Future.delayed to drive reminders', () {
      final src = readDart('lib/services/water_reminder_service.dart');
      expect(src.contains('Timer.periodic'), isFalse);
      expect(src.contains('Future.delayed'), isFalse);
    });

    test('Android scheduling is delegated to the native alarm bridge', () {
      final src = readDart('lib/services/water_reminder_service.dart');
      expect(
        src.contains('WaterNotificationPlatform.scheduleRepeating'),
        isTrue,
      );
    });

    test('alarms are self-rescheduling one-shots, not setInexactRepeating', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('alarmManager.setInexactRepeating'), isFalse);
      expect(helper.contains('setAndAllowWhileIdle'), isTrue);
      expect(helper.contains('fun armNextFromReceiver'), isTrue);
    });

    test('the receiver re-arms the chain before posting the reminder', () {
      final receiver = readNative('WaterReminderAlarmReceiver.kt');
      final armAt = receiver.indexOf('armNextFromReceiver');
      final showAt = receiver.indexOf('showScheduledReminder');
      expect(armAt, greaterThan(-1));
      expect(showAt, greaterThan(-1));
      expect(
        armAt,
        lessThan(showAt),
        reason: 'a throwing notification post must not break the chain',
      );
    });

    test('changing the interval cancels the previous schedule first', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('fun scheduleRepeating'),
        helper.indexOf('fun armNextFromReceiver'),
      );
      final cancelAt = fn.indexOf('cancelSchedule(context)');
      final armAt = fn.indexOf('armNext(context');
      expect(cancelAt, greaterThan(-1));
      expect(armAt, greaterThan(cancelAt));
    });

    test('disabling reminders cancels the alarm and clears the interval', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('fun cancelSchedule'),
        helper.indexOf('fun rescheduleAfterBoot'),
      );
      expect(fn.contains('alarmManager.cancel'), isTrue);
      expect(fn.contains('persistInterval(context, 0)'), isTrue);
      expect(fn.contains('cancel(context, REMINDER_NOTIFICATION_ID)'), isTrue);
    });

    test('re-arming reuses one PendingIntent so alarms cannot stack', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('FLAG_UPDATE_CURRENT'), isTrue);
      // A single request code for the alarm PendingIntent.
      expect(
        helper.contains('pendingBroadcast(context, REMINDER_NOTIFICATION_ID, intent)'),
        isTrue,
      );
    });

    test('repeated ensureScheduled only arms when the chain is overdue', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('fun ensureScheduled'),
        helper.indexOf('fun storedIntervalMinutes'),
      );
      expect(fn.contains('if (overdue) armNext'), isTrue);
    });

    test('app startup heals rather than restarts the countdown', () {
      final src = readDart('lib/main.dart');
      expect(src.contains('ensureScheduleAlive'), isTrue);
      expect(
        src.contains('rescheduleIfEnabled'),
        isFalse,
        reason: 'restarting the countdown on every launch suppresses reminders',
      );
    });

    test('interval and enabled state survive process death on disk', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('KEY_INTERVAL_MINUTES'), isTrue);
      expect(helper.contains('persistInterval'), isTrue);
      final dart = readDart('lib/services/water_reminder_service.dart');
      expect(dart.contains("'water_reminder_interval_minutes'"), isTrue);
    });

    test('reboot restores the schedule from persisted interval', () {
      final receiver = readNative('WaterReminderAlarmReceiver.kt');
      expect(receiver.contains('ACTION_BOOT_COMPLETED'), isTrue);
      expect(receiver.contains('rescheduleAfterBoot'), isTrue);

      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('fun rescheduleAfterBoot'),
        helper.indexOf('fun ensureScheduled'),
      );
      expect(fn.contains('storedIntervalMinutes'), isTrue);
      expect(fn.contains('scheduleRepeating'), isTrue);
    });

    test('manifest declares the boot receiver and permission', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        manifest.contains('android.permission.RECEIVE_BOOT_COMPLETED'),
        isTrue,
      );
      expect(manifest.contains('.WaterReminderAlarmReceiver'), isTrue);
    });

    test('no exact-alarm permission is requested', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest.contains('SCHEDULE_EXACT_ALARM'), isFalse);
      expect(manifest.contains('USE_EXACT_ALARM'), isFalse);
    });
  });

  // ------------------------------------------------------------------
  // B + H. Notification actions
  // ------------------------------------------------------------------
  group('notification actions', () {
    test('actions are broadcasts and never launch MainActivity', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('private fun actionPendingIntent'),
        helper.indexOf('private fun pendingBroadcast'),
      );
      expect(fn.contains('WaterActionReceiver'), isTrue);
      expect(fn.contains('pendingBroadcast'), isTrue);
      expect(
        fn.contains('MainActivity'),
        isFalse,
        reason: 'quick logging must not open the app',
      );
      expect(fn.contains('getActivity'), isFalse);
    });

    test('MainActivity no longer has a quick-log launch intent path', () {
      final main = readNative('MainActivity.kt');
      expect(main.contains('ACTION_WATER_QUICK_LOG'), isFalse);
      expect(main.contains('captureWaterAction'), isFalse);
    });

    test('the action receiver is declared and not exported', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final at = manifest.indexOf('.WaterActionReceiver');
      expect(at, greaterThan(-1));
      final block = manifest.substring(at, at + 200);
      expect(block.contains('android:exported="false"'), isTrue);
    });

    test('amounts come from a fixed allow-list, not intent extras', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('ALLOWED_AMOUNTS'), isTrue);
      expect(helper.contains('ACTION_ADD_250 to 250'), isTrue);
      expect(helper.contains('ACTION_ADD_500 to 500'), isTrue);

      final receiver = readNative('WaterActionReceiver.kt');
      expect(receiver.contains('amountForAction(actionId)'), isTrue);
      expect(
        receiver.contains('getIntExtra'),
        isFalse,
        reason: 'an untrusted intent must not be able to inject an amount',
      );
    });

    test('PendingIntents are immutable where supported', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('FLAG_IMMUTABLE'), isTrue);
    });

    test('the receiver rejects unknown actions', () {
      final receiver = readNative('WaterActionReceiver.kt');
      expect(receiver.contains('if (intent?.action != ACTION_QUICK_LOG) return'),
          isTrue);
      expect(
        receiver.contains('amountForAction(actionId) == null) return'),
        isTrue,
      );
    });

    test('Dart never re-adds water for a native quick log', () {
      final src = readDart('lib/services/water_notification_handler.dart');
      final fn = src.substring(src.indexOf('onNativeQuickLogApplied'));
      final body = fn.substring(0, fn.indexOf('static Future<void> handle('));
      expect(body.contains('drainNativeQuickLogs'), isTrue);
      expect(
        body.contains('addWater'),
        isFalse,
        reason: 'native already committed the increment',
      );
    });

    test('the plugin does not attach a second action set on Android', () {
      final src = readDart('lib/services/water_reminder_service.dart');
      expect(src.contains('(goalComplete || Platform.isAndroid)'), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // C. Atomic update
  // ------------------------------------------------------------------
  group('atomic water update', () {
    test('the native increment is locked and committed synchronously', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('fun applyQuickLog'),
        helper.indexOf('fun drainPendingQuickLogs'),
      );
      expect(fn.contains('synchronized(logLock)'), isTrue);
      expect(
        fn.contains('.commit()'),
        isTrue,
        reason: 'apply() may not reach disk before the process dies',
      );
      expect(fn.contains('.coerceAtLeast(0)'), isTrue);
    });

    test('rapid +250 then +500 adds 750, not 500', () async {
      final store = HydrationLocalStore.instance;
      await store.applyEvent(
        eventId: 'native_water_add_250_1',
        amountMl: 250,
        source: 'notification',
      );
      await store.applyEvent(
        eventId: 'native_water_add_500_2',
        amountMl: 500,
        source: 'notification',
      );
      expect(await store.getTodayMl(), 750);
    });

    test('+250 adds exactly 250 and +500 exactly 500', () async {
      final store = HydrationLocalStore.instance;
      expect(
        await store.applyEvent(
          eventId: 'a',
          amountMl: 250,
          source: 'notification',
        ),
        250,
      );
      expect(
        await store.applyEvent(
          eventId: 'b',
          amountMl: 500,
          source: 'notification',
        ),
        750,
      );
    });

    test('replaying the same native event id does not double count', () async {
      final store = HydrationLocalStore.instance;
      const id = 'native_water_add_250_1756000000000_250';
      await store.applyEvent(
        eventId: id,
        amountMl: 250,
        source: 'notification',
      );
      final replay = await store.applyEvent(
        eventId: id,
        amountMl: 250,
        source: 'notification',
      );
      expect(replay, isNull);
      expect(await store.getTodayMl(), 250);
      expect(await store.hasProcessed(id), isTrue);
    });

    test('a burst of taps cannot evict an unacknowledged id', () async {
      final store = HydrationLocalStore.instance;
      await store.applyEvent(
        eventId: 'first',
        amountMl: 250,
        source: 'notification',
      );
      for (var i = 0; i < 60; i++) {
        await store.applyEvent(
          eventId: 'burst_$i',
          amountMl: 250,
          source: 'notification',
        );
      }
      expect(await store.hasProcessed('first'), isTrue);
    });

    test('non-positive amounts are rejected', () async {
      final store = HydrationLocalStore.instance;
      expect(
        await store.applyEvent(eventId: 'z', amountMl: 0, source: 'notification'),
        isNull,
      );
      expect(
        await store.applyEvent(
          eventId: 'y',
          amountMl: -250,
          source: 'notification',
        ),
        isNull,
      );
      expect(await store.getTodayMl(), 0);
    });
  });

  // ------------------------------------------------------------------
  // D. Notification refresh
  // ------------------------------------------------------------------
  group('notification refresh', () {
    test('the reminder is re-posted in place under one stable id', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('const val REMINDER_NOTIFICATION_ID = 9100'), isTrue);
      final fn = helper.substring(
        helper.indexOf('fun refreshAfterQuickLog'),
        helper.indexOf('fun showGoalComplete'),
      );
      expect(fn.contains('REMINDER_NOTIFICATION_ID'), isTrue);
      expect(
        WaterReminderService.reminderNotificationId,
        9100,
        reason: 'Dart and native must agree on the id or they duplicate',
      );
    });

    test('the receiver refreshes the notification after logging', () {
      final receiver = readNative('WaterActionReceiver.kt');
      final applyAt = receiver.indexOf('applyQuickLog');
      final refreshAt = receiver.indexOf('refreshAfterQuickLog');
      expect(applyAt, greaterThan(-1));
      expect(refreshAt, greaterThan(applyAt));
    });

    test('the refreshed body shows consumed / goal and remaining', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(
        helper.contains(
          '"\${formatMl(snapshot.consumedMl)} / \${formatMl(snapshot.goalMl)}"',
        ),
        isTrue,
      );
      expect(helper.contains('left to reach today'), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // E. App synchronization
  // ------------------------------------------------------------------
  group('app synchronization', () {
    test('resume drains native quick logs before flushing remotely', () {
      final src =
          readDart('lib/widgets/hydration/hydration_lifecycle_refresher.dart');
      final drainAt = src.indexOf('drainNativeQuickLogs');
      final flushAt = src.indexOf('flushPendingRemoteSync');
      expect(drainAt, greaterThan(-1));
      expect(flushAt, greaterThan(drainAt));
      expect(src.contains('AppLifecycleState.resumed'), isTrue);
    });

    test('draining bumps the revision so the water card rebuilds', () {
      final src = readDart('lib/services/water_intake_service.dart');
      final fn = src.substring(
        src.indexOf('Future<int> drainNativeQuickLogs'),
        src.indexOf('Future<void> flushPendingRemoteSync'),
      );
      expect(fn.contains('revision.value++'), isTrue);
    });

    test('only acknowledged events are cleared natively', () {
      final src = readDart('lib/services/water_intake_service.dart');
      final fn = src.substring(
        src.indexOf('Future<int> drainNativeQuickLogs'),
        src.indexOf('Future<void> flushPendingRemoteSync'),
      );
      expect(fn.contains('clearPendingQuickLogs(acknowledged)'), isTrue);
      // A failure leaves the event queued for the next drain.
      expect(fn.contains('// Leave it queued natively for the next drain.'),
          isTrue);
    });

    test('the drain is a no-op off Android', () {
      final src = readDart('lib/services/water_intake_service.dart');
      expect(src.contains('if (!Platform.isAndroid) return 0;'), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // F. Daily reset / date safety
  // ------------------------------------------------------------------
  group('daily reset and date safety', () {
    test('native stamps the local calendar date at tap time', () {
      final helper = readNative('WaterNotificationHelper.kt');
      expect(helper.contains('fun localDateKey'), isTrue);
      expect(helper.contains('Calendar.getInstance()'), isTrue);
      final fn = helper.substring(
        helper.indexOf('fun applyQuickLog'),
        helper.indexOf('fun drainPendingQuickLogs'),
      );
      expect(fn.contains('.put("localDate", today)'), isTrue);
    });

    test('native rolls the total over at local midnight before adding', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(
        helper.indexOf('fun applyQuickLog'),
        helper.indexOf('fun drainPendingQuickLogs'),
      );
      expect(fn.contains('if (storedDate == today)'), isTrue);
      expect(fn.contains('} else {\n                0\n            }'), isTrue);
    });

    test('23:55 and 00:05 taps produce different date keys', () {
      final store = HydrationLocalStore.instance;
      expect(
        store.localDateKey(DateTime(2026, 8, 28, 23, 55)),
        '2026-08-28',
      );
      expect(
        store.localDateKey(DateTime(2026, 8, 29, 0, 5)),
        '2026-08-29',
      );
    });

    test('an event from an earlier day is not credited to today', () async {
      final store = HydrationLocalStore.instance;
      final yesterday = store.localDateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      final applied = await store.applyEvent(
        eventId: 'late_night',
        amountMl: 250,
        source: 'notification',
        localDate: yesterday,
      );

      expect(applied, isNull);
      expect(await store.getTodayMl(), 0);
      // Still recorded, so a retry cannot replay it into today.
      expect(await store.hasProcessed('late_night'), isTrue);
    });

    test("today's event is credited normally", () async {
      final store = HydrationLocalStore.instance;
      final applied = await store.applyEvent(
        eventId: 'now',
        amountMl: 500,
        source: 'notification',
        localDate: store.localDateKey(),
      );
      expect(applied, 500);
    });

    test('a stale-day pending event is not pushed to today remotely', () {
      final src = readDart('lib/services/water_intake_service.dart');
      expect(
        src.contains("if ((event['localDate'] as String?) != today)"),
        isTrue,
      );
    });

    test('a stale snapshot cannot suppress the next day of reminders', () {
      final helper = readNative('WaterNotificationHelper.kt');
      final fn = helper.substring(helper.indexOf('private fun readSnapshot'));
      expect(fn.contains('val isToday = storedDate != null'), isTrue);
      expect(fn.contains('if (isToday) consumed.coerceAtLeast(0) else 0'), isTrue);
      // The old bug: isFresh was ORed with a condition that was always true.
      expect(fn.contains('fresh || (consumed >= 0 && goal > 0)'), isFalse);
    });
  });
}
