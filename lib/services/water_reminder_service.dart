import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/metrics_repository.dart';
import '../theme/design_tokens.dart';
import 'fitness_notification_preferences_service.dart';
import 'hydration_local_store.dart';
import 'user_goals_service.dart';
import 'water_notification_handler.dart';
import 'water_notification_platform.dart';

/// Local water intake reminders via [flutter_local_notifications] + Android AlarmManager.
///
/// Interval is stored in SharedPreferences only (no Supabase).
class WaterReminderService {
  WaterReminderService._();

  static final WaterReminderService instance = WaterReminderService._();

  static const _prefsKeyMinutes = 'water_reminder_interval_minutes';
  static const _legacyPrefsKeyHours = 'water_reminder_interval_hours';

  /// Versioned Android channel (replaces legacy `water_reminders`).
  static const channelId = 'cotrainr_hydration_reminders';
  static const channelName = 'Hydration reminders';
  static const channelDescription =
      'Reminders to drink water and log hydration.';

  static const title = 'Hydration check';
  static const body = 'Time for some water';
  static const expandedFallback =
      'Stay on track with your daily goal. Log a quick drink below.';

  static const reminderNotificationId = 9100;
  static const testNotificationId = 9099;

  static const presetMinutes = <int>[0, 30, 60, 120, 180];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidInit =
        AndroidInitializationSettings('@drawable/ic_notification_water');
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
      WaterNotificationPlatform.ensureQuickLogHandler(
        handler: WaterNotificationHandler.handleActionId,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.defaultImportance,
          showBadge: false,
        ),
      );
    }

    _initialized = true;
  }

  NotificationDetails _pluginNotificationDetails({
    required String expandedText,
    required bool goalComplete,
    int? consumedMl,
    int? goalMl,
  }) {
    final showProgress = !goalComplete &&
        consumedMl != null &&
        goalMl != null &&
        goalMl > 0 &&
        consumedMl >= 0;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        color: DesignTokens.accentOrange,
        icon: '@drawable/ic_notification_water',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          expandedText,
          contentTitle: goalComplete ? 'Hydration goal complete' : title,
          summaryText: 'Cotrainr',
        ),
        actions: goalComplete ? const [] : WaterNotificationActions.androidActions,
        autoCancel: true,
        onlyAlertOnce: true,
        showProgress: showProgress,
        maxProgress: showProgress ? goalMl : 0,
        progress: showProgress ? consumedMl.clamp(0, goalMl) : 0,
        indeterminate: false,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
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
    if (minutes <= 0) return false;
    return FitnessNotificationPreferencesService.allowsWaterReminders();
  }

  /// Cancels or reschedules locals from Notifications prefs without clearing interval.
  Future<void> applyPreferenceGate() async {
    final allowed =
        await FitnessNotificationPreferencesService.allowsWaterReminders();
    if (!allowed) {
      await cancelAll();
      return;
    }
    await rescheduleIfEnabled();
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
    await _plugin.cancel(reminderNotificationId);
  }

  Future<bool> setIntervalMinutes(int minutes) async {
    await ensureInitialized();
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    if (minutes <= 0) {
      await prefs.remove(_prefsKeyMinutes);
      return true;
    }

    await prefs.setInt(_prefsKeyMinutes, minutes);

    final allowed =
        await FitnessNotificationPreferencesService.allowsWaterReminders();
    if (!allowed) {
      return true;
    }

    if (!await requestPermissionIfNeeded()) {
      return false;
    }

    await syncHydrationSnapshot();
    await _scheduleRepeating(minutes);
    return true;
  }

  Future<bool> setIntervalHours(double hours) =>
      setIntervalMinutes((hours * 60).round());

  Future<void> disable() => setIntervalMinutes(0);

  Future<void> rescheduleIfEnabled() async {
    final minutes = await getIntervalMinutes();
    if (minutes <= 0) return;

    final allowed =
        await FitnessNotificationPreferencesService.allowsWaterReminders();
    if (!allowed) {
      await cancelAll();
      return;
    }

    await ensureInitialized();
    await cancelAll();

    if (!await requestPermissionIfNeeded()) return;
    await syncHydrationSnapshot();
    await _scheduleRepeating(minutes);
  }

  /// Writes consumed/goal ml for Android AlarmManager notifications.
  Future<({int consumedMl, int goalMl})> syncHydrationSnapshot({
    double? consumedLiters,
  }) async {
    final goalLiters = await UserGoalsService().getWaterGoal();
    var consumed = consumedLiters;
    if (consumed == null) {
      final localMl = await HydrationLocalStore.instance.getTodayMl();
      double? remoteLiters;
      try {
        final today = await MetricsRepository().getTodayMetrics();
        remoteLiters =
            (today?['water_intake_liters'] as num?)?.toDouble();
      } catch (_) {}
      final remoteMl =
          remoteLiters == null ? 0 : (remoteLiters * 1000).round();
      // Same rule as WaterIntakeService: never drop a fresher local total.
      consumed = (localMl >= remoteMl ? localMl : remoteMl) / 1000.0;
    }
    final consumedMl = (consumed * 1000).round();
    final goalMl = (goalLiters * 1000).round();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hydration_notif_consumed_ml', consumedMl);
    await prefs.setInt('hydration_notif_goal_ml', goalMl);
    await prefs.setInt(
      'hydration_notif_updated_at_ms',
      DateTime.now().millisecondsSinceEpoch,
    );

    if (Platform.isAndroid) {
      try {
        await WaterNotificationPlatform.syncHydrationSnapshot(
          consumedMl: consumedMl,
          goalMl: goalMl,
        );
      } catch (_) {}
    }
    return (consumedMl: consumedMl, goalMl: goalMl);
  }

  /// Refresh the active reminder after a quick-log (or show goal-complete).
  Future<void> refreshActiveNotification({
    required double consumedLiters,
    int? addedMl,
  }) async {
    final enabled = await isEnabled();
    if (!enabled && addedMl == null) return;

    await ensureInitialized();
    final snap = await syncHydrationSnapshot(consumedLiters: consumedLiters);
    final goalComplete = snap.goalMl > 0 && snap.consumedMl >= snap.goalMl;

    final collapsedTitle = goalComplete
        ? 'Hydration goal complete'
        : (addedMl != null ? 'Hydration updated' : title);
    final collapsedBody = goalComplete
        ? 'You reached your water goal for today.'
        : (addedMl != null && snap.goalMl > 0
            ? 'Today: ${_fmtMl(snap.consumedMl)} / ${_fmtMl(snap.goalMl)}'
            : (addedMl != null
                ? '$addedMl ml added'
                : body));
    final expanded = goalComplete
        ? collapsedBody
        : (snap.goalMl > 0
            ? 'You have ${_fmtMl((snap.goalMl - snap.consumedMl).clamp(0, snap.goalMl))} left to reach today’s goal. Log a quick drink below.'
            : expandedFallback);

    // Plugin show works from the background notification isolate.
    await _plugin.show(
      reminderNotificationId,
      collapsedTitle,
      collapsedBody,
      _pluginNotificationDetails(
        expandedText: expanded,
        goalComplete: goalComplete,
        consumedMl: snap.consumedMl,
        goalMl: snap.goalMl,
      ),
      payload: WaterNotificationActions.openWaterPayload,
    );

    // Keep native AlarmManager snapshot/notification in sync when possible.
    if (Platform.isAndroid) {
      try {
        if (goalComplete) {
          await WaterNotificationPlatform.show(
            notificationId: reminderNotificationId,
            goalComplete: true,
          );
        } else {
          await WaterNotificationPlatform.show(
            notificationId: reminderNotificationId,
            title: collapsedTitle,
            body: collapsedBody,
          );
        }
        if (addedMl != null) {
          final minutes = await getIntervalMinutes();
          final allowed = await FitnessNotificationPreferencesService
              .allowsWaterReminders();
          if (minutes > 0 && allowed) {
            await WaterNotificationPlatform.scheduleRepeating(minutes);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('WaterReminderService: native refresh skipped: $e');
        }
      }
    }
  }

  Future<void> showFailureNotification() async {
    await ensureInitialized();
    await _plugin.show(
      reminderNotificationId,
      'Couldn’t log water',
      'Open Cotrainr to try again.',
      _pluginNotificationDetails(
        expandedText: 'Open Cotrainr to try again.',
        goalComplete: false,
      ),
      payload: WaterNotificationActions.openWaterPayload,
    );
  }

  Future<bool> showTestNotification() async {
    await ensureInitialized();

    if (!await requestPermissionIfNeeded()) {
      return false;
    }

    await syncHydrationSnapshot();

    if (Platform.isAndroid) {
      await WaterNotificationPlatform.show(
        notificationId: testNotificationId,
        title: title,
        body: body,
      );
      return true;
    }

    final snap = await syncHydrationSnapshot();
    final remaining = (snap.goalMl - snap.consumedMl).clamp(0, snap.goalMl);
    final expanded = snap.goalMl > 0
        ? 'You have ${_fmtMl(remaining)} left to reach today’s goal. Log a quick drink below.'
        : expandedFallback;

    await _plugin.show(
      testNotificationId,
      title,
      body,
      _pluginNotificationDetails(
        expandedText: expanded,
        goalComplete: false,
        consumedMl: snap.consumedMl,
        goalMl: snap.goalMl,
      ),
      payload: WaterNotificationActions.openWaterPayload,
    );
    return true;
  }

  Future<void> _scheduleRepeating(int minutes) async {
    if (Platform.isAndroid) {
      await WaterNotificationPlatform.scheduleRepeating(minutes);
      return;
    }

    final interval = Duration(minutes: minutes.clamp(30, 24 * 60));
    final snap = await syncHydrationSnapshot();
    final remaining = (snap.goalMl - snap.consumedMl).clamp(0, snap.goalMl);
    final expanded = snap.goalMl > 0
        ? 'You have ${_fmtMl(remaining)} left to reach today’s goal. Log a quick drink below.'
        : expandedFallback;

    if (kDebugMode) {
      debugPrint(
        'WaterReminderService: scheduling every ${interval.inMinutes} minutes',
      );
    }

    await _plugin.periodicallyShowWithDuration(
      reminderNotificationId,
      title,
      body,
      interval,
      _pluginNotificationDetails(
        expandedText: expanded,
        goalComplete: false,
        consumedMl: snap.consumedMl,
        goalMl: snap.goalMl,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: WaterNotificationActions.openWaterPayload,
    );
  }

  static String _fmtMl(int ml) {
    final digits = ml.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$digits ml';
  }
}
