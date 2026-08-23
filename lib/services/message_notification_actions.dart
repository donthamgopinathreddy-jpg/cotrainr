import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../repositories/messages_repository.dart';
import '../router/app_router.dart';
import 'message_pending_navigation.dart';

/// Local-notification + FCM tap routing for chat message pushes.
class MessageNotificationActions {
  static bool isMessageType(String? type) {
    final t = (type ?? '').trim().toLowerCase();
    return t == 'message' || t == 'new_message';
  }

  static String? conversationIdFrom(Map<String, dynamic> data) {
    final id = data['conversation_id']?.toString() ??
        data['conversationId']?.toString();
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static String encodePayload({
    required String conversationId,
    String type = 'message',
  }) {
    return jsonEncode({
      'action': 'open',
      'type': type,
      'notification_type': type,
      'conversation_id': conversationId,
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

  static bool isMessagePayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    if (isMessageType(payload['type']?.toString() ??
        payload['notification_type']?.toString())) {
      return true;
    }
    return conversationIdFrom(payload) != null &&
        (payload['type']?.toString().isEmpty ?? true);
  }

  /// Store pending route, validate access, then navigate.
  static Future<void> persistAndRoute({
    required String conversationId,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/messaging');
      });
      return;
    }
    final route = MessagePendingNavigation.routeFor(id);
    await MessagePendingNavigation.store(route);

    try {
      final conv = await MessagesRepository().fetchConversationById(id);
      if (conv == null) {
        await MessagePendingNavigation.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.go('/messaging');
        });
        return;
      }
      await MessagePendingNavigation.consume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go(route);
      });
    } catch (_) {
      await MessagePendingNavigation.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/home?tab=2');
      });
    }
  }

  static void routeFromPushData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ??
        data['notification_type']?.toString() ??
        '';
    if (!isMessageType(type)) return;
    final id = conversationIdFrom(data);
    if (id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/messaging');
      });
      return;
    }
    unawaited(persistAndRoute(conversationId: id));
  }

  static void handleResponse(NotificationResponse response) {
    final payload = decodePayload(response.payload);
    if (payload == null || !isMessagePayload(payload)) return;
    final id = conversationIdFrom(payload);
    if (id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/messaging');
      });
      return;
    }
    unawaited(persistAndRoute(conversationId: id));
  }

  static Future<void> handleBackgroundResponse(
    NotificationResponse response,
  ) async {
    final payload = decodePayload(response.payload) ?? {};
    if (!isMessagePayload(payload) &&
        !isMessageType(payload['type']?.toString())) {
      return;
    }
    final id = conversationIdFrom(payload);
    if (id == null || id.isEmpty) return;
    await MessagePendingNavigation.store(
      MessagePendingNavigation.routeFor(id),
    );
  }
}
