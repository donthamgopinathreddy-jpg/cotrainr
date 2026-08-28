import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../router/app_router.dart';
import '../theme/design_tokens.dart';
import 'user_goals_service.dart';
import 'water_intake_service.dart';
import 'water_notification_platform.dart';
import 'water_reminder_service.dart';

/// Action IDs for water reminder notification buttons.
abstract final class WaterNotificationActions {
  static const add250 = 'water_add_250';
  static const add500 = 'water_add_500';
  static const openWaterPayload = 'open_water_insights';

  static const androidActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      add250,
      '+250 ml',
      titleColor: DesignTokens.accentOrange,
      showsUserInterface: false,
      cancelNotification: false,
    ),
    AndroidNotificationAction(
      add500,
      '+500 ml',
      titleColor: DesignTokens.accentOrange,
      showsUserInterface: false,
      cancelNotification: false,
    ),
  ];
}

/// Background isolate entry — must be top-level, awaited, and plugin-ready.
@pragma('vm:entry-point')
Future<void> waterNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await WaterNotificationHandler.handle(response);
}

/// Handles water reminder notification action taps (foreground + background).
class WaterNotificationHandler {
  static DateTime? _lastActionAt;
  static String? _lastActionId;
  static const _debounce = Duration(milliseconds: 800);

  static Future<void> onForegroundResponse(
    NotificationResponse response,
  ) async {
    await handle(response);
  }

  /// Android: the native receiver already committed the increment, so this
  /// only reconciles it into the Dart store. It must never add water itself.
  static Future<void> onNativeQuickLogApplied() async {
    try {
      final applied = await WaterIntakeService.instance.drainNativeQuickLogs();
      if (applied > 0) {
        await WaterIntakeService.instance.flushPendingRemoteSync();
      }
    } catch (e) {
      debugPrint('WaterNotificationHandler: native drain failed: $e');
    }
  }

  static Future<void> handle(NotificationResponse response) async {
    // Body tap → open water insights (foreground / plugin path only).
    if (response.actionId == null || response.actionId!.isEmpty) {
      if (response.payload == WaterNotificationActions.openWaterPayload ||
          response.notificationResponseType ==
              NotificationResponseType.selectedNotification) {
        await _openWaterInsights();
      }
      return;
    }

    final liters = litersForActionId(response.actionId);
    if (liters == null) return;

    final now = DateTime.now();
    if (_lastActionId == response.actionId &&
        _lastActionAt != null &&
        now.difference(_lastActionAt!) < _debounce) {
      return;
    }
    _lastActionId = response.actionId;
    _lastActionAt = now;

    final eventId =
        'notif_${response.actionId}_${response.id ?? 0}_${now.millisecondsSinceEpoch}';

    await _ensureBackgroundDeps();

    final updated = await WaterIntakeService.instance.addWater(
      liters,
      source: 'notification',
      eventId: eventId,
    );

    if (updated == null) {
      await _showLogFailedNotification();
      return;
    }

    final addedMl = (liters * 1000).round();
    await _refreshNotificationAfterLog(
      consumedLiters: updated,
      addedMl: addedMl,
    );
  }

  static double? litersForActionId(String? actionId) {
    return switch (actionId) {
      WaterNotificationActions.add250 => 0.25,
      WaterNotificationActions.add500 => 0.5,
      _ => null,
    };
  }

  static Future<void> _ensureBackgroundDeps() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    }

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      try {
        await auth.refreshSession();
      } catch (_) {}
    }

    // Ensure notification plugin callback wiring exists in this isolate.
    try {
      await WaterReminderService.instance.ensureInitialized();
    } catch (_) {}
  }

  static Future<void> _refreshNotificationAfterLog({
    required double consumedLiters,
    required int addedMl,
  }) async {
    final goalLiters = await UserGoalsService().getWaterGoal();
    final consumedMl = (consumedLiters * 1000).round();
    final goalMl = (goalLiters * 1000).round();
    final goalComplete = goalMl > 0 && consumedMl >= goalMl;

    // Prefer plugin show (works in background isolate). Fall back to native channel.
    try {
      await WaterReminderService.instance.refreshActiveNotification(
        consumedLiters: consumedLiters,
        addedMl: addedMl,
      );
      return;
    } catch (e) {
      debugPrint('WaterNotificationHandler: plugin refresh failed: $e');
    }

    if (Platform.isAndroid) {
      try {
        await WaterNotificationPlatform.syncHydrationSnapshot(
          consumedMl: consumedMl,
          goalMl: goalMl,
        );
        if (goalComplete) {
          await WaterNotificationPlatform.show(
            notificationId: WaterReminderService.reminderNotificationId,
            goalComplete: true,
          );
        } else {
          await WaterNotificationPlatform.show(
            notificationId: WaterReminderService.reminderNotificationId,
            title: 'Hydration updated',
            body: goalMl > 0
                ? 'Today: ${_fmtMl(consumedMl)} / ${_fmtMl(goalMl)}'
                : '$addedMl ml added',
          );
        }
        final prefs = await SharedPreferences.getInstance();
        final minutes =
            prefs.getInt('water_reminder_interval_minutes') ?? 0;
        if (minutes > 0) {
          await WaterNotificationPlatform.scheduleRepeating(minutes);
        }
      } catch (e) {
        debugPrint('WaterNotificationHandler: native refresh failed: $e');
      }
    }
  }

  static Future<void> _showLogFailedNotification() async {
    try {
      await WaterReminderService.instance.showFailureNotification();
    } catch (_) {
      if (Platform.isAndroid) {
        try {
          await WaterNotificationPlatform.show(
            notificationId: WaterReminderService.reminderNotificationId,
            title: 'Couldn’t log water',
            body: 'Open Cotrainr to try again.',
          );
        } catch (_) {}
      }
    }
  }

  static String _fmtMl(int ml) =>
      '${ml.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )} ml';

  static Future<void> _openWaterInsights() async {
    try {
      appRouter.go('/insights/water');
    } catch (_) {}
  }
}
