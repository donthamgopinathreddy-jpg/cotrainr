import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/pending_referral_service.dart';

/// Handles app deep links (cotrainr://invite?code=X, https://www.cotrainr.com/invite?code=X).
/// Stores referral code temporarily if user not signed in; navigates to signup.
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

  String? _extractCode(Uri uri) {
    final code = uri.queryParameters['code'];
    return (code != null && code.trim().isNotEmpty) ? code.trim() : null;
  }

  void _handleUri(Uri? uri) {
    if (uri == null || !_isInviteUri(uri)) return;
    final code = _extractCode(uri);
    if (code == null) return;
    if (!mounted) return;
    // Store for persistence (in case user closes app before signup)
    PendingReferralService.setPendingCode(code);
    // Only navigate to signup if user not signed in
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    if (!isLoggedIn) {
      context.go('/auth/create-account?code=${Uri.encodeComponent(code)}');
    }
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
