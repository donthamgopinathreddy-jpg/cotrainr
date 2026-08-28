import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-native water hydration reminder notifications + quick-log bridge.
///
/// The +250/+500 notification actions are applied natively by
/// `WaterActionReceiver` without starting the app, so Dart's job is only to
/// drain the events native has already committed to disk.
class WaterNotificationPlatform {
  WaterNotificationPlatform._();

  static const _channel = MethodChannel('cotrainr/water_notifications');

  /// Called when native has applied a quick log while the engine is attached.
  static Future<void> Function()? onQuickLogApplied;

  static bool _handlerAttached = false;

  static void ensureQuickLogHandler({Future<void> Function()? handler}) {
    if (handler != null) {
      onQuickLogApplied = handler;
    }
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWaterQuickLogApplied') {
        await onQuickLogApplied?.call();
        return true;
      }
      return null;
    });
  }

  /// Quick-log events committed natively but not yet applied in Dart.
  static Future<List<Map<String, dynamic>>> drainPendingQuickLogs() async {
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('drainPendingQuickLogs');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('WaterNotificationPlatform.drain failed: $e');
      return const [];
    }
  }

  /// Acknowledge events Dart has durably applied.
  static Future<void> clearPendingQuickLogs(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    try {
      await _channel.invokeMethod('clearPendingQuickLogs', {
        'eventIds': eventIds,
      });
    } catch (e) {
      debugPrint('WaterNotificationPlatform.clearPending failed: $e');
    }
  }

  /// Re-arm the alarm chain if the OS dropped it. No-op when up to date.
  static Future<void> ensureSchedule() async {
    try {
      await _channel.invokeMethod('ensureWaterSchedule');
    } catch (e) {
      debugPrint('WaterNotificationPlatform.ensureSchedule failed: $e');
    }
  }

  static Future<void> show({
    required int notificationId,
    String? title,
    String? body,
    bool goalComplete = false,
  }) async {
    try {
      await _channel.invokeMethod('showWaterReminder', {
        'notificationId': notificationId,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        'goalComplete': goalComplete,
      });
    } catch (e, stack) {
      debugPrint('WaterNotificationPlatform.show failed: $e\n$stack');
      rethrow;
    }
  }

  static Future<void> scheduleRepeating(int intervalMinutes) async {
    try {
      await _channel.invokeMethod('scheduleWaterReminder', {
        'intervalMinutes': intervalMinutes,
      });
    } catch (e, stack) {
      debugPrint('WaterNotificationPlatform.schedule failed: $e\n$stack');
      rethrow;
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelWaterReminder');
    } catch (e, stack) {
      debugPrint('WaterNotificationPlatform.cancel failed: $e\n$stack');
      rethrow;
    }
  }

  static Future<void> syncHydrationSnapshot({
    required int consumedMl,
    required int goalMl,
  }) async {
    try {
      await _channel.invokeMethod('syncHydrationSnapshot', {
        'consumedMl': consumedMl,
        'goalMl': goalMl,
      });
    } catch (e, stack) {
      debugPrint('WaterNotificationPlatform.syncSnapshot failed: $e\n$stack');
    }
  }
}
