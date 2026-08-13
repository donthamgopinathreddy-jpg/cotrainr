import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_error_mapper.dart';
import '../../core/auth/post_auth_destination.dart';
import '../../theme/design_tokens.dart';

/// Resolves Home / Verification / Complete-profile after auth.
class PostAuthContinuePage extends StatefulWidget {
  const PostAuthContinuePage({super.key});

  @override
  State<PostAuthContinuePage> createState() => _PostAuthContinuePageState();
}

class _PostAuthContinuePageState extends State<PostAuthContinuePage> {
  String? _error;
  var _showSlowHint = false;
  Timer? _slowHint;

  @override
  void initState() {
    super.initState();
    _slowHint = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSlowHint = true);
    });
    unawaited(_resolve());
  }

  @override
  void dispose() {
    _slowHint?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() {
      _error = null;
    });
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        if (!mounted) return;
        context.go('/welcome');
        return;
      }
      final dest = await PostAuthDestination.resolve()
          .timeout(PostAuthDestination.networkTimeout);
      if (!mounted) return;
      // Avoid infinite loop if resolve returns continue.
      if (dest == '/auth/continue') {
        setState(() {
          _error =
              'Couldn’t finish loading your account. Check your connection and try again.';
        });
        return;
      }
      context.go(dest);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = AuthErrorMapper.timeout.display;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthErrorMapper.map(e).display;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fg = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showSlowHint
                            ? 'Taking a little longer than usual…'
                            : 'Preparing your account…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fg, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _showSlowHint = false;
                          });
                          _slowHint?.cancel();
                          _slowHint = Timer(const Duration(seconds: 3), () {
                            if (mounted) setState(() => _showSlowHint = true);
                          });
                          unawaited(_resolve());
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignTokens.accentOrange,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
