import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-native water notifications with pill-shaped preset buttons.
class WaterNotificationPlatform {
  WaterNotificationPlatform._();

  static const _channel = MethodChannel('cotrainr/water_notifications');

  static Future<void> show({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('showWaterReminder', {
        'notificationId': notificationId,
        'title': title,
        'body': body,
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
}
