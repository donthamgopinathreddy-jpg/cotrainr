import 'package:flutter/foundation.dart';

import '../core/startup/startup_router_bridge.dart';
import 'push_notification_service.dart';
import 'video_session_pending_navigation.dart';
import 'water_reminder_service.dart';

/// Best-effort notification/session cleanup on logout and account switch.
abstract final class NotificationSessionCleanup {
  /// Call before [Supabase.auth.signOut]. Never throws to caller.
  static Future<void> prepareForLogout() async {
    try {
      await PushNotificationService.instance.removeDeviceToken();
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationSessionCleanup: token remove failed');
    }
    try {
      await VideoSessionPendingNavigation.clear();
    } catch (_) {}
    try {
      StartupRouterBridge.setPendingDeepLinkRoute(null);
    } catch (_) {}
    try {
      await WaterReminderService.instance.cancelAll();
    } catch (_) {}
  }

  /// After a new session is established.
  static Future<void> onAccountSignedIn() async {
    try {
      await PushNotificationService.instance.registerToken();
    } catch (_) {}
    try {
      await WaterReminderService.instance.rescheduleIfEnabled();
    } catch (_) {}
  }
}
