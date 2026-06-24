import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local water intake reminders (SharedPreferences + flutter_local_notifications).
class WaterReminderService {
  WaterReminderService._();
  static final WaterReminderService instance = WaterReminderService._();

  static const _prefsKey = 'water_reminder_interval_hours';
  static const _channelId = 'water_reminders';
  static const _channelName = 'Water Reminders';
  static const _notificationIdBase = 9100;
  static const _scheduledSlots = 24;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Reminders to log water intake',
              importance: Importance.high,
            ),
          );
    }
    _initialized = true;
  }

  Future<double> getIntervalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_prefsKey) ?? 0;
  }

  Future<bool> isEnabled() async {
    final hours = await getIntervalHours();
    return hours > 0;
  }

  String labelFor(double hours) {
    if (hours <= 0) return 'Off';
    if (hours == 1) return 'Every 1 hour';
    if (hours == 2) return 'Every 2 hours';
    if (hours == 3) return 'Every 3 hours';
    if (hours == hours.roundToDouble()) {
      return 'Every ${hours.toInt()} hours';
    }
    return 'Every ${hours.toStringAsFixed(1)} hours';
  }

  Future<String> statusLabel() async {
    final hours = await getIntervalHours();
    if (hours <= 0) return 'Reminder: Off';
    return 'Reminder: ${labelFor(hours)}';
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancelAll() async {
    await ensureInitialized();
    for (var i = 0; i < _scheduledSlots; i++) {
      await _plugin.cancel(_notificationIdBase + i);
    }
  }

  Future<bool> setIntervalHours(double hours) async {
    await ensureInitialized();
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    if (hours <= 0) {
      await prefs.setDouble(_prefsKey, 0);
      return true;
    }

    final granted = await requestPermissionIfNeeded();
    if (!granted) return false;

    await prefs.setDouble(_prefsKey, hours);
    await _schedule(hours);
    return true;
  }

  Future<void> _schedule(double hours) async {
    final interval = Duration(minutes: (hours * 60).round());
    final now = tz.TZDateTime.now(tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders to log water intake',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (var i = 0; i < _scheduledSlots; i++) {
      final when = now.add(interval * (i + 1));
      await _plugin.zonedSchedule(
        _notificationIdBase + i,
        'Time to drink water 💧',
        'Log your water intake in Cotrainr.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
