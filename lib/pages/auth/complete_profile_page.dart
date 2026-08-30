import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_error_mapper.dart';
import '../../core/auth/onboarding_state_service.dart';
import '../../core/auth/post_auth_destination.dart';
import '../../core/auth/signup_mode.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/cotrainr_loader.dart';
import 'signup_wizard_page.dart';

/// Route guard for `/auth/complete-profile`.
///
/// Onboarding is only shown when the server says onboarding is incomplete, so a
/// completed user cannot deep-link back in and overwrite real profile values.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        if (!mounted) return;
        context.go('/welcome');
        return;
      }

      final state = await OnboardingStateService.fetch()
          .timeout(PostAuthDestination.networkTimeout);
      if (!mounted) return;

      if (state.isComplete) {
        // Already onboarded: the post-auth gate owns the destination.
        final dest = await PostAuthDestination.resolve();
        if (!mounted) return;
        context.go(dest == '/auth/complete-profile' ? '/auth/continue' : dest);
        return;
      }

      setState(() => _checking = false);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = AuthErrorMapper.timeout.display;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = AuthErrorMapper.map(e).display;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || _error != null) {
      return Scaffold(
        backgroundColor: DesignTokens.backgroundOf(context),
        body: CotrainrLoader.fullscreen(
          error: _error,
          onRetry: _error == null ? null : _check,
        ),
      );
    }

    return const SignupWizardPage(mode: SignupMode.social);
  }
}
