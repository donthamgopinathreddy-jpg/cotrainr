import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_deep_link.dart';
import '../../core/auth/auth_error_mapper.dart';
import '../../theme/auth_theme.dart';
import 'auth_ui.dart';

typedef ForgotPasswordSubmit = Future<void> Function(String email);

/// Opens the compact Cotrainr Forgot Password dialog.
///
/// Content lives in [showDialog]'s builder (not [showGeneralDialog]
/// `transitionBuilder`) so InheritedWidget dependents dispose cleanly.
Future<void> showForgotPasswordSheet(
  BuildContext context, {
  ForgotPasswordSubmit? onSubmit,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      return ForgotPasswordSheet(onSubmit: onSubmit);
    },
  );
}

/// Compact Reset Password card used from Login.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    this.onSubmit,
    this.redirectTo = AuthDeepLink.resetPassword,
  });

  /// Injected for tests. Defaults to Supabase [resetPasswordForEmail].
  final ForgotPasswordSubmit? onSubmit;

  final String redirectTo;

  static final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  State<ForgotPasswordSheet> createState() => ForgotPasswordSheetState();
}

@visibleForTesting
class ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _email = TextEditingController();
  final _focus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _success = false;
  String? _error;

  bool get isLoading => _loading;
  bool get isSuccess => _success;
  String? get errorText => _error;

  @override
  void dispose() {
    _focus.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _defaultSubmit(String email) {
    return Supabase.instance.client.auth.resetPasswordForEmail(
      email,
      redirectTo: widget.redirectTo,
    );
  }

  Future<void> submit() => _submit();

  Future<void> _submit() async {
    if (_loading || _success) return;

    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    if (!ForgotPasswordSheet.emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final submit = widget.onSubmit ?? _defaultSubmit;
      await submit(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final mapped = AuthErrorMapper.mapPasswordResetFailure(e);
      if (AuthErrorMapper.shouldSuppressUi(mapped)) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _loading = false;
        _error = mapped.display;
      });
    }
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AuthTheme.surfaceElevated(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AuthTheme.fieldBorder(context)),
                  boxShadow: AuthTheme.cardShadow(context).isEmpty
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ]
                      : AuthTheme.cardShadow(context),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(anim);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: _success
                          ? KeyedSubtree(
                              key: const ValueKey('forgot-success'),
                              child: _SuccessBody(onDone: _close),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('forgot-form'),
                              child: _FormBody(
                                formKey: _formKey,
                                email: _email,
                                focus: _focus,
                                loading: _loading,
                                error: _error,
                                onSubmit: _submit,
                                onCancel: _close,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.formKey,
    required this.email,
    required this.focus,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final FocusNode focus;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AuthTheme.selectionSurface(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AuthTheme.selectionBorder(context)
                      .withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                color: AuthTheme.accent,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reset password',
            textAlign: TextAlign.center,
            style: AuthTheme.title(context).copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your email and we'll send you a secure reset link.",
            textAlign: TextAlign.center,
            style: AuthTheme.subtitle(context).copyWith(fontSize: 15),
          ),
          const SizedBox(height: 22),
          Text(
            'Email',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AuthTheme.primaryText(context),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: email,
            focusNode: focus,
            enabled: !loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            style: AuthTheme.field(context),
            onFieldSubmitted: (_) => onSubmit(),
            decoration: AuthUi.fieldDecoration(
              context,
              label: 'you@example.com',
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                size: 20,
                color: AuthTheme.secondaryText(context),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: TextStyle(
                color: AuthTheme.error(context),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Send reset link',
            isLoading: loading,
            onPressed: loading ? null : onSubmit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AuthTheme.secondaryText(context),
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AuthTheme.selectionSurface(context),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    AuthTheme.selectionBorder(context).withValues(alpha: 0.55),
              ),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: AuthTheme.accent,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: AuthTheme.title(context).copyWith(fontSize: 26),
        ),
        const SizedBox(height: 10),
        Text(
          "If an account exists for this email, we've sent password reset instructions.",
          textAlign: TextAlign.center,
          style: AuthTheme.subtitle(context).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Done',
          onPressed: () {
            HapticFeedback.lightImpact();
            onDone();
          },
        ),
      ],
    );
  }
}
