import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/app_router.dart';
import '../utils/meeting_link_rules.dart';

/// Android local-notification actions for video session reminders.
class VideoSessionNotificationActions {
  static const join = 'video_session_join';
  static const dismiss = 'video_session_dismiss';
  static const channelId = 'cotrainr_video_sessions';

  static String encodePayload({
    required String action,
    String? sessionId,
    String? joinUrl,
    String? scheduledStart,
    int? durationMinutes,
    String? status,
  }) {
    return jsonEncode({
      'action': action,
      'video_session_id': sessionId,
      'join_url': joinUrl,
      'scheduled_start': scheduledStart,
      'duration_minutes': durationMinutes,
      'status': status,
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

  static void handleResponse(NotificationResponse response) {
    final payload = decodePayload(response.payload) ?? {};
    final actionId = response.actionId;
    if (actionId == dismiss || payload['action'] == 'dismiss') {
      return;
    }
    final sessionId = payload['video_session_id']?.toString();
    final joinUrl = payload['join_url']?.toString();
    final wantsJoin = actionId == join || payload['action'] == 'join';

    if (wantsJoin && joinUrl != null && joinUrl.isNotEmpty) {
      final startRaw = payload['scheduled_start']?.toString();
      final start = startRaw == null ? null : DateTime.tryParse(startRaw);
      final duration = int.tryParse('${payload['duration_minutes']}') ?? 30;
      final status = payload['status']?.toString() ?? 'scheduled';
      final allowed = start == null
          ? MeetingLinkRules.isValidHttpsMeetingLink(joinUrl)
          : VideoSessionJoinRules.canJoin(
              VideoSessionJoinRules.evaluate(
                status: status,
                scheduledStart: start,
                durationMinutes: duration,
                joinUrl: joinUrl,
              ),
            );
      if (allowed) {
        final uri = Uri.tryParse(joinUrl);
        if (uri != null) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          return;
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sessionId != null &&
          sessionId.isNotEmpty &&
          !sessionId.contains('google-connected')) {
        appRouter.go('/video/session/$sessionId');
      } else {
        appRouter.go('/video');
      }
    });
  }

  static void routeFromPushData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final sessionId = data['video_session_id']?.toString() ??
        data['videoSessionId']?.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (type.startsWith('video_session_') &&
          sessionId != null &&
          sessionId.isNotEmpty &&
          !sessionId.contains('google-connected')) {
        appRouter.go('/video/session/$sessionId');
        return;
      }
      appRouter.go('/notifications');
    });
  }
}
