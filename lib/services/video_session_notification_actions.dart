import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../router/app_router.dart';
import '../theme/design_tokens.dart';
import '../video_sessions/video_session_notification_logic.dart';
import 'video_session_pending_navigation.dart';

/// Android local-notification actions for video session reminders.
class VideoSessionNotificationActions {
  static const join = 'video_session_join';
  static const reject = 'video_session_reject';
  static const dismiss = 'video_session_dismiss';
  static const channelId = 'cotrainr_video_sessions';

  static const androidActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      join,
      'JOIN',
      titleColor: DesignTokens.videoSessionsAccent,
      showsUserInterface: true,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      reject,
      'REJECT',
      showsUserInterface: true,
      cancelNotification: true,
    ),
  ];

  static String encodePayload({
    required String action,
    String? sessionId,
    String? joinUrl,
    String? scheduledStart,
    int? durationMinutes,
    String? status,
    String? type,
    String? counterpartName,
  }) {
    return jsonEncode({
      'action': action,
      'type': type,
      'notification_type': type,
      'video_session_id': sessionId,
      'join_url': joinUrl,
      'scheduled_start': scheduledStart,
      'duration_minutes': durationMinutes,
      'status': status,
      'counterpart_name': counterpartName,
    });
  }

  static Map<String, dynamic>? decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Map<String, String> stringData(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  static String? sessionIdFrom(Map<String, dynamic> data) {
    final id = data['video_session_id']?.toString() ??
        data['videoSessionId']?.toString();
    if (id == null || id.isEmpty || id.contains('google-connected')) {
      return null;
    }
    return id;
  }

  static String localTimeLabel(DateTime scheduledStart) {
    return DateFormat('h:mm a').format(scheduledStart.toLocal());
  }

  static String reminderBodyFromData(Map<String, dynamic> data) {
    final name = (data['counterpart_name']?.toString() ?? '').trim();
    final display = name.isEmpty ? 'your trainer' : name;
    final type = data['type']?.toString() ?? data['notification_type']?.toString();
    if (type == VideoSessionNotificationLogic.startingType) {
      return VideoSessionNotificationLogic.startingBody(counterpartName: display);
    }
    final startRaw = data['scheduled_start']?.toString();
    final start = startRaw == null ? null : DateTime.tryParse(startRaw);
    if (start == null) {
      return VideoSessionNotificationLogic.reminderBody(
        counterpartName: display,
        whenLabel: 'the scheduled time',
      );
    }
    return VideoSessionNotificationLogic.reminderBody(
      counterpartName: display,
      whenLabel: localTimeLabel(start),
    );
  }

  static String reminderTitleFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? data['notification_type']?.toString();
    if (type == VideoSessionNotificationLogic.startingType) {
      return VideoSessionNotificationLogic.startingTitle;
    }
    return VideoSessionNotificationLogic.reminder5mTitle;
  }

  static bool isVideoSessionPayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    if (payload.containsKey('video_session_id') ||
        payload.containsKey('videoSessionId')) {
      return true;
    }
    final type = payload['type']?.toString() ??
        payload['notification_type']?.toString() ??
        '';
    return type.startsWith('video_session_');
  }

  static Future<void> persistAndRoute({
    required String? sessionId,
    String? action,
  }) async {
    final route = VideoSessionPendingNavigation.routeFor(
      sessionId: sessionId ?? '',
      action: action,
    );
    await VideoSessionPendingNavigation.store(route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.go(route);
    });
  }

  static void handleResponse(NotificationResponse response) {
    final payload = decodePayload(response.payload) ?? {};
    final actionId = response.actionId;
    if (actionId == dismiss || payload['action'] == 'dismiss') {
      return;
    }
    final sessionId = sessionIdFrom(payload);
    final wantsReject = actionId == reject || payload['action'] == 'reject';
    final wantsJoin = actionId == join || payload['action'] == 'join';
    unawaited(persistAndRoute(
      sessionId: sessionId,
      action: wantsReject
          ? 'reject'
          : wantsJoin
              ? 'join'
              : null,
    ));
  }

  static void routeFromPushData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ??
        data['notification_type']?.toString() ??
        '';
    final sessionId = sessionIdFrom(data);
    final action = data['action']?.toString();
    if (type.startsWith('video_session_') && sessionId != null) {
      unawaited(persistAndRoute(
        sessionId: sessionId,
        action: action == 'join' || action == 'reject' ? action : null,
      ));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.go('/notifications');
    });
  }

  static Future<void> handleBackgroundResponse(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final payload = decodePayload(response.payload) ?? {};
    final actionId = response.actionId;
    if (actionId == dismiss) return;
    final sessionId = sessionIdFrom(payload);
    final wantsReject = actionId == reject || payload['action'] == 'reject';
    final wantsJoin = actionId == join || payload['action'] == 'join';
    final route = VideoSessionPendingNavigation.routeFor(
      sessionId: sessionId ?? '',
      action: wantsReject
          ? 'reject'
          : wantsJoin
              ? 'join'
              : null,
    );
    await VideoSessionPendingNavigation.store(route);
  }
}

@pragma('vm:entry-point')
Future<void> videoSessionNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  await VideoSessionNotificationActions.handleBackgroundResponse(response);
}
