import 'startup_state.dart';

/// Non-Riverpod mirror of bootstrap state for GoRouter redirects.
class StartupRouterBridge {
  StartupRouterBridge._();

  static StartupState state = StartupState.initial;

  static void update(StartupState next) {
    state = next;
  }
}
