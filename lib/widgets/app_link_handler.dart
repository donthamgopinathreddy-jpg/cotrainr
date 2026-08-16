import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_deep_link.dart';
import '../core/startup/startup_router_bridge.dart';
import '../router/app_router.dart';
import '../services/pending_referral_service.dart';

/// Handles app deep links (invite, Google Meet OAuth return, water, auth, reset).
///
/// Lives *above* [MaterialApp.router], so navigation must use [appRouter]
/// (not `context.go`) — otherwise GoRouter is missing from this context.
///
/// - [AuthDeepLink.callback] → session → `/auth/continue`
/// - [AuthDeepLink.resetPassword] → recovery session → `/auth/reset-password`
/// - `cotrainr://video/google-connected` → OAuth event → `/video?google-connected=1`
class AppLinkHandler extends StatefulWidget {
  const AppLinkHandler({super.key, required this.child});

  final Widget child;

  @override
  State<AppLinkHandler> createState() => _AppLinkHandlerState();
}

class _AppLinkHandlerState extends State<AppLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _isInviteUri(Uri uri) {
    if (uri.path.contains('invite')) return true;
    if (uri.host == 'invite') return true;
    if (uri.host == 'www.cotrainr.com' || uri.host == 'cotrainr.com') {
      return uri.path.startsWith('/invite');
    }
    return false;
  }

  bool _isVideoZoomConnectedUri(Uri uri) {
    return uri.host == 'video' && uri.path.startsWith('/zoom-connected');
  }

  bool _isVideoGoogleConnectedUri(Uri uri) {
    if (uri.scheme != 'cotrainr') return false;
    if (uri.host == 'video') {
      return uri.path == '/google-connected' ||
          uri.path.startsWith('/google-connected');
    }
    // Defensive: some platforms flatten host into path.
    return uri.path == '/video/google-connected' ||
        uri.path.startsWith('/video/google-connected');
  }

  String? _extractCode(Uri uri) {
    final code = uri.queryParameters['code'];
    return (code != null && code.trim().isNotEmpty) ? code.trim() : null;
  }

  /// Maps OAuth return URI → in-app Video Sessions route (never /video/google-connected).
  String _googleConnectedAppRoute(Uri uri) {
    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      return '/video?google-connected=1&google_error=${Uri.encodeComponent(error)}';
    }
    // success=1 (or bare path) → refresh status on Video Sessions.
    return '/video?google-connected=1';
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    debugPrint(
      '[AppLinkHandler] uri scheme=${uri.scheme} host=${uri.host} path=${uri.path}',
    );
    if (AuthDeepLink.isResetPasswordUri(uri)) {
      unawaited(_continueAfterPasswordRecovery(uri));
      return;
    }
    if (AuthDeepLink.isCallbackUri(uri)) {
      unawaited(_continueAfterAuthCallback());
      return;
    }
    if (_isVideoZoomConnectedUri(uri)) {
      // Zoom OAuth retired from MVP — ignore callback noise; stay on video list.
      appRouter.go('/video');
      return;
    }
    if (_isVideoGoogleConnectedUri(uri)) {
      final target = _googleConnectedAppRoute(uri);
      debugPrint('[AppLinkHandler] google oauth complete → $target');
      // Survive splash / cold-start races before Video Sessions paints.
      StartupRouterBridge.setPendingDeepLinkRoute(target);
      appRouter.go(target);
      return;
    }
    if (_isWaterInsightsUri(uri)) {
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      if (!isLoggedIn) {
        appRouter.go('/welcome');
        return;
      }
      appRouter.go('/insights/water');
      return;
    }
    if (!_isInviteUri(uri)) return;
    final code = _extractCode(uri);
    if (code == null) return;
    PendingReferralService.setPendingCode(code);
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    if (!isLoggedIn) {
      appRouter.go('/auth/create-account?code=${Uri.encodeComponent(code)}');
    }
  }

  bool _isWaterInsightsUri(Uri uri) {
    if (uri.scheme == 'cotrainr' &&
        (uri.host == 'insights' || uri.host == 'water')) {
      if (uri.host == 'water') return true;
      return uri.path == '/water' || uri.path.startsWith('/water');
    }
    return false;
  }

  /// Password recovery deep-link path → `/auth/reset-password` only.
  Future<void> _continueAfterPasswordRecovery(Uri uri) async {
    StartupRouterBridge.setPendingDeepLinkRoute('/auth/reset-password');

    // Prefer SDK session establishment from the recovery URI when available.
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (_) {
      // SDK may already be consuming the link via its own listener.
    }

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (Supabase.instance.client.auth.currentSession == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }
    if (!mounted) return;

    if (Supabase.instance.client.auth.currentSession == null) {
      appRouter.go('/auth/reset-password?error=invalid');
      return;
    }
    appRouter.go('/auth/reset-password');
  }

  /// Wait for supabase_flutter to consume tokens, then use PostAuthDestination.
  /// Do not go to /home from the deep-link handler.
  Future<void> _continueAfterAuthCallback() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (Supabase.instance.client.auth.currentSession == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    appRouter.go('/auth/continue');
  }

  @override
  void initState() {
    super.initState();
    _appLinks.getInitialLink().then(_handleUri);
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
