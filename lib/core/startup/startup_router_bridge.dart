import 'startup_state.dart';

/// Non-Riverpod mirror of bootstrap state for GoRouter redirects.
class StartupRouterBridge {
  StartupRouterBridge._();

  static StartupState state = StartupState.initial;

  /// Survives splash / warm deep-link races (e.g. password recovery).
  static String? pendingDeepLinkRoute;

  static void update(StartupState next) {
    state = next;
  }

  static void setPendingDeepLinkRoute(String? route) {
    pendingDeepLinkRoute = route;
  }
}
