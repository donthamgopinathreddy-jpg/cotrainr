import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_ui.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idOrEmail = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _idOrEmail.dispose();
    _pass.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _goSignup() {
    HapticFeedback.lightImpact();
    context.push('/auth/create-account');
  }

  Future<void> _forgotPassword() async {
    HapticFeedback.lightImpact();

    final emailController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountHubTheme.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountHubTheme.sectionRadius),
        ),
        title: Text('Reset Password', style: AuthUi.pageTitle(context)),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: AuthUi.fieldDecoration(context, label: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AccountHubTheme.rowSubtitle(context),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, emailController.text),
            child: const Text(
              'Send',
              style: TextStyle(
                color: AuthUi.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          result.trim(),
          redirectTo: 'cotrainr://reset-password',
        );
        if (!mounted) return;
        showHubSnackBar(context, 'Password reset email sent!');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: DesignTokens.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'cotrainr://auth-callback',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _idOrEmail.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = AuthUi.pageBg(context);
    final textSecondary = AccountHubTheme.rowSubtitle(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            AuthHeroCard(
              isLight: isLight,
              compact: true,
              title: 'Welcome back',
              subtitle:
                  'Sign in to pick up your training, meals, and progress.',
            ),
            const SizedBox(height: 10),
            AuthSectionCard(
              compact: true,
              title: 'Account',
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTapToTypeField(
                      controller: _idOrEmail,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      style: AuthUi.fieldTextStyle(context, large: true),
                      decoration: AuthUi.fieldDecoration(
                        context,
                        large: true,
                        label: 'User ID or Email',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: textSecondary.color,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AuthTapToTypeField(
                      controller: _pass,
                      obscureText: _obscure,
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 chars' : null,
                      style: AuthUi.fieldTextStyle(context, large: true),
                      decoration: AuthUi.fieldDecoration(
                        context,
                        large: true,
                        label: 'Password',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: textSecondary.color,
                          size: 22,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: textSecondary.color,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _obscure = !_obscure);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _rememberMe = !_rememberMe);
                          },
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: _rememberMe
                                      ? AuthUi.accent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _rememberMe
                                        ? AuthUi.accent
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: _rememberMe
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text('Remember me', style: textSecondary),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AuthUi.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AuthPrimaryButton(
                      label: 'Sign In',
                      onPressed: _login,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            AuthSectionCard(
              compact: true,
              title: 'Or continue with',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AuthSocialButton(
                    isLoading: _isLoading,
                    onTap: () => _signInWithOAuth(OAuthProvider.google),
                    icon: FaIcon(
                      FontAwesomeIcons.google,
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AuthSocialButton(
                    isLoading: _isLoading,
                    onTap: () => _signInWithOAuth(OAuthProvider.apple),
                    icon: FaIcon(
                      FontAwesomeIcons.apple,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AuthSocialButton(
                    isLoading: _isLoading,
                    onTap: () => _signInWithOAuth(OAuthProvider.facebook),
                    icon: FaIcon(
                      FontAwesomeIcons.facebook,
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? ", style: textSecondary),
                GestureDetector(
                  onTap: _goSignup,
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: AuthUi.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
