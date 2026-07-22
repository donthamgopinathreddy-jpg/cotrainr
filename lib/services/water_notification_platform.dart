import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-native water hydration reminder notifications + quick-log bridge.
class WaterNotificationPlatform {
  WaterNotificationPlatform._();

  static const _channel = MethodChannel('cotrainr/water_notifications');

  /// Main-isolate handler for native → Dart quick-log events.
  static Future<void> Function(String actionId)? onQuickLogAction;

  static bool _handlerAttached = false;

  /// Listen for MainActivity quick-log intents on the main isolate.
  static void ensureQuickLogHandler({
    Future<void> Function(String actionId)? handler,
  }) {
    if (handler != null) {
      onQuickLogAction = handler;
    }
    if (!_handlerAttached) {
      _handlerAttached = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onWaterQuickLog') {
          final args = call.arguments;
          final actionId = args is Map ? args['actionId'] as String? : null;
          if (actionId != null && onQuickLogAction != null) {
            await onQuickLogAction!(actionId);
          }
          return true;
        }
        return null;
      });
    }
    // Ask native to deliver any action captured before the handler was ready.
    _channel.invokeMethod<void>('readyForWaterActions').catchError((_) {});
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
