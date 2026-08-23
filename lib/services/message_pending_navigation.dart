import 'package:shared_preferences/shared_preferences.dart';

import '../core/startup/startup_router_bridge.dart';

/// Survives cold start so message notification taps still route after splash.
class MessagePendingNavigation {
  static const prefsKey = 'pending_message_conversation_route';

  static String routeFor(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return '/messaging';
    return '/messaging/chat/$id';
  }

  static bool isMessageChatRoute(String route) {
    return route.startsWith('/messaging/chat/');
  }

  static String? conversationIdFromRoute(String route) {
    if (!isMessageChatRoute(route)) return null;
    final id = route.substring('/messaging/chat/'.length).split('?').first.trim();
    return id.isEmpty ? null : id;
  }

  static Future<void> store(String route) async {
    if (!isMessageChatRoute(route)) return;
    StartupRouterBridge.setPendingDeepLinkRoute(route);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, route);
  }

  static Future<String?> peek() async {
    final memory = StartupRouterBridge.pendingDeepLinkRoute;
    if (memory != null && isMessageChatRoute(memory)) return memory;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    if (stored != null && isMessageChatRoute(stored)) return stored;
    return null;
  }

  static Future<void> clear() async {
    final memory = StartupRouterBridge.pendingDeepLinkRoute;
    if (memory != null && isMessageChatRoute(memory)) {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static Future<String?> consume() async {
    final route = await peek();
    final memory = StartupRouterBridge.pendingDeepLinkRoute;
    if (memory != null && isMessageChatRoute(memory)) {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    return route;
  }
}
