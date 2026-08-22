import 'package:shared_preferences/shared_preferences.dart';

import '../core/startup/startup_router_bridge.dart';

/// Survives cold start so JOIN/REJECT still route after splash.
/// Does not steal Google OAuth `/video` or `/video/google-connected` routes.
class VideoSessionPendingNavigation {
  static const prefsKey = 'pending_video_session_route';

  static String routeFor({
    required String sessionId,
    String? action,
  }) {
    final id = sessionId.trim();
    if (id.isEmpty || id.contains('google-connected')) {
      return '/video';
    }
    if (action == 'join' || action == 'reject') {
      return '/video/session/$id?action=$action';
    }
    return '/video/session/$id';
  }

  static bool isSessionActionRoute(String route) {
    return route.startsWith('/video/session/') &&
        !route.contains('google-connected');
  }

  static Future<void> store(String route) async {
    if (!isSessionActionRoute(route)) return;
    StartupRouterBridge.setPendingDeepLinkRoute(route);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, route);
  }

  static Future<String?> peek() async {
    final memory = StartupRouterBridge.pendingDeepLinkRoute;
    if (memory != null && isSessionActionRoute(memory)) return memory;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    if (stored != null && isSessionActionRoute(stored)) return stored;
    return null;
  }

  static Future<void> clear() async {
    StartupRouterBridge.setPendingDeepLinkRoute(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static Future<String?> consume() async {
    final route = await peek();
    final memory = StartupRouterBridge.pendingDeepLinkRoute;
    if (memory != null && isSessionActionRoute(memory)) {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    return route;
  }
}
