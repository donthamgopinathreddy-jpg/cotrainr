import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_error_mapper.dart';
import '../../core/startup/startup_router_bridge.dart';
import '../../theme/auth_theme.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../widgets/auth/auth_ui.dart';

/// Recovery screen for `cotrainr://reset-password` deep links.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

enum _ResetPhase { loadingSession, ready, invalid, success }

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;
  _ResetPhase _phase = _ResetPhase.loadingSession;

  @override
  void initState() {
    super.initState();
    StartupRouterBridge.setPendingDeepLinkRoute('/auth/reset-password');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_awaitRecoverySession());
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _awaitRecoverySession() async {
    String? errorParam;
    try {
      errorParam = GoRouterState.of(context).uri.queryParameters['error'];
    } catch (_) {
      errorParam = null;
    }
    final forceInvalid = errorParam == 'invalid';
    if (forceInvalid) {
      if (!mounted) return;
      setState(() => _phase = _ResetPhase.invalid);
      return;
    }

    Session? session;
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (_) {
      // Supabase not initialized (tests / startup race) → treat as invalid.
      if (!mounted) return;
      setState(() => _phase = _ResetPhase.invalid);
      return;
    }

    if (session != null) {
      if (!mounted) return;
      setState(() => _phase = _ResetPhase.ready);
      return;
    }

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      try {
        session = Supabase.instance.client.auth.currentSession;
      } catch (_) {
        session = null;
        break;
      }
      if (session != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }

    if (!mounted) return;
    if (session == null) {
      setState(() => _phase = _ResetPhase.invalid);
    } else {
      setState(() => _phase = _ResetPhase.ready);
    }
  }

  Future<void> _submit() async {
    if (_loading || _phase != _ResetPhase.ready) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.lightImpact();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text.trim()),
      );
      if (!mounted) return;
      // Leave recovery session so router does not treat this as a normal login.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      StartupRouterBridge.setPendingDeepLinkRoute(null);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _phase = _ResetPhase.success;
      });
    } catch (e) {
      if (!mounted) return;
      final mapped = AuthErrorMapper.map(e);
      setState(() {
        _loading = false;
        _error = AuthErrorMapper.shouldSuppressUi(mapped)
            ? 'Could not update password. Try again.'
            : (mapped.kind == AuthUserErrorKind.network
                ? 'Check your connection and try again.'
                : 'Could not update password. Try again.');
      });
    }
  }

  void _backToSignIn() {
    StartupRouterBridge.setPendingDeepLinkRoute(null);
    context.go('/auth/login');
  }

  void _requestNewLink() {
    StartupRouterBridge.setPendingDeepLinkRoute(null);
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AuthTheme.primaryText(context);
    final textSecondary = AuthTheme.secondaryText(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AuthTheme.overlay(context),
      child: AuthScreenBackground.onboarding(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: textPrimary,
            title: Text(
              _phase == _ResetPhase.success
                  ? 'Password updated'
                  : 'Set new password',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: switch (_phase) {
                _ResetPhase.loadingSession => _LoadingBody(
                    key: const ValueKey('loading'),
                    color: textSecondary,
                  ),
                _ResetPhase.invalid => _InvalidBody(
                    key: const ValueKey('invalid'),
                    onRequestNew: _requestNewLink,
                  ),
                _ResetPhase.success => _SuccessBody(
                    key: const ValueKey('success'),
                    onDone: _backToSignIn,
                  ),
                _ResetPhase.ready => _FormBody(
                    key: const ValueKey('form'),
                    formKey: _formKey,
                    password: _password,
                    confirm: _confirm,
                    obscure: _obscure,
                    obscureConfirm: _obscureConfirm,
                    loading: _loading,
                    error: _error,
                    onToggleObscure: () =>
                        setState(() => _obscure = !_obscure),
                    onToggleObscureConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    onSubmit: _submit,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AuthTheme.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Preparing secure reset…',
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _InvalidBody extends StatelessWidget {
  const _InvalidBody({super.key, required this.onRequestNew});

  final VoidCallback onRequestNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.link_off_rounded, size: 40, color: AuthTheme.accent),
          const SizedBox(height: 16),
          Text(
            'This reset link is invalid or has expired.',
            textAlign: TextAlign.center,
            style: AuthTheme.title(context).copyWith(fontSize: 22),
          ),
          const SizedBox(height: 10),
          Text(
            'Request a new link from the sign-in screen to continue.',
            textAlign: TextAlign.center,
            style: AuthTheme.subtitle(context).copyWith(fontSize: 15),
          ),
          const Spacer(),
          AuthPrimaryButton(
            label: 'Request a new link',
            onPressed: onRequestNew,
          ),
        ],
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.check_circle_outline_rounded,
              size: 44, color: AuthTheme.accent),
          const SizedBox(height: 16),
          Text(
            'Password updated',
            textAlign: TextAlign.center,
            style: AuthTheme.title(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 10),
          Text(
            'Your password has been changed successfully.',
            textAlign: TextAlign.center,
            style: AuthTheme.subtitle(context).copyWith(fontSize: 15),
          ),
          const Spacer(),
          AuthPrimaryButton(
            label: 'Back to Sign In',
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    super.key,
    required this.formKey,
    required this.password,
    required this.confirm,
    required this.obscure,
    required this.obscureConfirm,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onToggleObscureConfirm,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool obscure;
  final bool obscureConfirm;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleObscureConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AuthTheme.secondaryText(context);

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            'Choose a new password for your Cotrainr account.',
            style: TextStyle(
              color: textSecondary,
              height: 1.4,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: password,
            obscureText: obscure,
            style: AuthTheme.field(context),
            decoration: AuthUi.fieldDecoration(
              context,
              label: 'New password',
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: textSecondary,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 8) {
                return 'Use at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirm,
            obscureText: obscureConfirm,
            style: AuthTheme.field(context),
            decoration: AuthUi.fieldDecoration(
              context,
              label: 'Confirm password',
              suffixIcon: IconButton(
                onPressed: onToggleObscureConfirm,
                icon: Icon(
                  obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: textSecondary,
                ),
              ),
            ),
            validator: (v) {
              if (v != password.text) return 'Passwords do not match';
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(
                color: AuthTheme.error(context),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Update password',
            isLoading: loading,
            onPressed: loading ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
