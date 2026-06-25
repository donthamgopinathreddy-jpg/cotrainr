import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'water_notification_handler.dart';
import 'water_notification_platform.dart';

/// Local water intake reminders via [flutter_local_notifications].
///
/// Interval is stored in SharedPreferences only (no Supabase).
class WaterReminderService {
  WaterReminderService._();

  static final WaterReminderService instance = WaterReminderService._();

  static const _prefsKeyMinutes = 'water_reminder_interval_minutes';
  static const _legacyPrefsKeyHours = 'water_reminder_interval_hours';

  static const _channelId = 'water_reminders';
  static const _channelName = 'Water Reminders';

  static const _title = 'Time to drink water 💧';
  static const _body = 'Tap a preset to add water.';

  static const _reminderNotificationId = 9100;
  static const _testNotificationId = 9099;

  static const presetMinutes = <int>[0, 30, 60, 120, 180];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          WaterNotificationHandler.onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          waterNotificationBackgroundResponse,
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Periodic reminders to log water intake',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  NotificationDetails _notificationDetails() {
    if (Platform.isAndroid) {
      // Android uses native pill layout via [WaterNotificationPlatform].
      return const NotificationDetails();
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Periodic reminders to log water intake',
        importance: Importance.high,
        priority: Priority.high,
        actions: WaterNotificationActions.androidActions,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<int> getIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_prefsKeyMinutes)) {
      return prefs.getInt(_prefsKeyMinutes) ?? 0;
    }

    final legacyHours = prefs.getDouble(_legacyPrefsKeyHours);
    if (legacyHours != null && legacyHours > 0) {
      final minutes = (legacyHours * 60).round();
      await prefs.setInt(_prefsKeyMinutes, minutes);
      await prefs.remove(_legacyPrefsKeyHours);
      return minutes;
    }
    return 0;
  }

  @Deprecated('Use getIntervalMinutes')
  Future<double> getIntervalHours() async {
    final minutes = await getIntervalMinutes();
    return minutes / 60.0;
  }

  Future<bool> isEnabled() async {
    final minutes = await getIntervalMinutes();
    return minutes > 0;
  }

  Future<String> statusLabel() async {
    final minutes = await getIntervalMinutes();
    if (minutes <= 0) return 'Reminder: Off';
    return 'Reminder: ${intervalLabel(minutes)}';
  }

  static String intervalLabel(int minutes) {
    if (minutes <= 0) return 'Off';
    if (minutes < 60) return 'Every $minutes min';
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      if (hours == 1) return 'Every 1 hour';
      return 'Every $hours hours';
    }
    final hours = minutes / 60;
    return 'Every ${hours.toStringAsFixed(1)} hours';
  }

  static String pillLabel(int minutes) {
    if (minutes <= 0) return 'Off';
    if (minutes == 30) return '30 min';
    if (minutes == 60) return '1 hr';
    if (minutes == 120) return '2 hr';
    if (minutes == 180) return '3 hr';
    return '${minutes}m';
  }

  static bool isPreset(int minutes) => presetMinutes.contains(minutes);

  Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final pluginGranted = await android?.requestNotificationsPermission();
      if (pluginGranted == true) return true;

      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final result = await Permission.notification.request();
      return result.isGranted;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  Future<void> cancelAll() async {
    await ensureInitialized();
    if (Platform.isAndroid) {
      await WaterNotificationPlatform.cancelAll();
    }
    await _plugin.cancel(_reminderNotificationId);
  }

  Future<bool> setIntervalMinutes(int minutes) async {
    await ensureInitialized();
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    if (minutes <= 0) {
      await prefs.remove(_prefsKeyMinutes);
      return true;
    }

    if (!await requestPermissionIfNeeded()) {
      return false;
    }

    await prefs.setInt(_prefsKeyMinutes, minutes);
    await _scheduleRepeating(minutes);
    return true;
  }

  Future<bool> setIntervalHours(double hours) =>
      setIntervalMinutes((hours * 60).round());

  Future<void> disable() => setIntervalMinutes(0);

  Future<void> rescheduleIfEnabled() async {
    final minutes = await getIntervalMinutes();
    if (minutes <= 0) return;

    await ensureInitialized();
    await cancelAll();

    if (!await requestPermissionIfNeeded()) return;
    await _scheduleRepeating(minutes);
  }

  Future<bool> showTestNotification() async {
    await ensureInitialized();

    if (!await requestPermissionIfNeeded()) {
      return false;
    }

    if (Platform.isAndroid) {
      await WaterNotificationPlatform.show(
        notificationId: _testNotificationId,
        title: _title,
        body: _body,
      );
      return true;
    }

    await _plugin.show(
      _testNotificationId,
      _title,
      _body,
      _notificationDetails(),
    );
    return true;
  }

  Future<void> _scheduleRepeating(int minutes) async {
    if (Platform.isAndroid) {
      await WaterNotificationPlatform.scheduleRepeating(minutes);
      return;
    }

    final interval = Duration(minutes: minutes.clamp(30, 24 * 60));

    if (kDebugMode) {
      debugPrint(
        'WaterReminderService: scheduling every ${interval.inMinutes} minutes',
      );
    }

    await _plugin.periodicallyShowWithDuration(
      _reminderNotificationId,
      _title,
      _body,
      interval,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
