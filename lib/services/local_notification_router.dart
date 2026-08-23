import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'message_notification_actions.dart';
import 'video_session_notification_actions.dart';
import 'water_notification_handler.dart';

/// Shared flutter_local_notifications callbacks so video JOIN/REJECT,
/// message, and hydration actions keep working after PushNotificationService initializes.
/// Returns true when the tap was handled.
bool routeLocalNotificationResponse(NotificationResponse response) {
  final actionId = response.actionId ?? '';
  if (actionId == WaterNotificationActions.add250 ||
      actionId == WaterNotificationActions.add500 ||
      response.payload == WaterNotificationActions.openWaterPayload) {
    WaterNotificationHandler.onForegroundResponse(response);
    return true;
  }
  final payload =
      VideoSessionNotificationActions.decodePayload(response.payload);
  if (actionId == VideoSessionNotificationActions.join ||
      actionId == VideoSessionNotificationActions.reject ||
      actionId == VideoSessionNotificationActions.dismiss ||
      VideoSessionNotificationActions.isVideoSessionPayload(payload)) {
    VideoSessionNotificationActions.handleResponse(response);
    return true;
  }
  final messagePayload =
      MessageNotificationActions.decodePayload(response.payload);
  if (MessageNotificationActions.isMessagePayload(messagePayload)) {
    MessageNotificationActions.handleResponse(response);
    return true;
  }
  return false;
}

@pragma('vm:entry-point')
Future<void> localNotificationBackgroundRouter(
  NotificationResponse response,
) async {
  final actionId = response.actionId ?? '';
  if (actionId == WaterNotificationActions.add250 ||
      actionId == WaterNotificationActions.add500 ||
      response.payload == WaterNotificationActions.openWaterPayload) {
    await waterNotificationBackgroundResponse(response);
    return;
  }
  final payload =
      VideoSessionNotificationActions.decodePayload(response.payload);
  if (actionId == VideoSessionNotificationActions.join ||
      actionId == VideoSessionNotificationActions.reject ||
      actionId == VideoSessionNotificationActions.dismiss ||
      VideoSessionNotificationActions.isVideoSessionPayload(payload)) {
    await VideoSessionNotificationActions.handleBackgroundResponse(response);
    return;
  }
  final messagePayload =
      MessageNotificationActions.decodePayload(response.payload);
  if (MessageNotificationActions.isMessagePayload(messagePayload)) {
    await MessageNotificationActions.handleBackgroundResponse(response);
  }
}
