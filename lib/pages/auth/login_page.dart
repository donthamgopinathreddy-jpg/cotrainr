import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_screen_background.dart';
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

  /// Auth screens always use the dark branding surface (not orange welcome).
  static const _pageBg = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    final textSecondary = AccountHubTheme.rowSubtitle(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _pageBg,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: AuthScreenBackground(
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      color: Colors.white,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/welcome'),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        28 + bottomInset + safeBottom,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        // Let the branded athlete/logo area of the artwork show.
                        SizedBox(height: (h * 0.28).clamp(140.0, 260.0)),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: AuthUi.pageTitle(context).copyWith(
                            fontSize: 26,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to pick up your training, meals, and progress.',
                          textAlign: TextAlign.center,
                          style: AuthUi.pageSubtitle(context).copyWith(
                            fontSize: 14.5,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                  style: AuthUi.fieldTextStyle(context,
                                      large: true),
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
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Min 6 chars'
                                      : null,
                                  style: AuthUi.fieldTextStyle(context,
                                      large: true),
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
                                        setState(
                                            () => _rememberMe = !_rememberMe);
                                      },
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              color: _rememberMe
                                                  ? AuthUi.accent
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: _rememberMe
                                                    ? AuthUi.accent
                                                    : Colors.white.withValues(
                                                        alpha: 0.25),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: _rememberMe
                                                ? const Icon(Icons.check,
                                                    size: 14,
                                                    color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Remember me',
                                              style: textSecondary),
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
                        const SizedBox(height: 12),
                        AuthSectionCard(
                          compact: true,
                          title: 'Or continue with',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AuthSocialButton(
                                isLoading: _isLoading,
                                onTap: () =>
                                    _signInWithOAuth(OAuthProvider.google),
                                icon: const FaIcon(
                                  FontAwesomeIcons.google,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              AuthSocialButton(
                                isLoading: _isLoading,
                                onTap: () =>
                                    _signInWithOAuth(OAuthProvider.apple),
                                icon: const FaIcon(
                                  FontAwesomeIcons.apple,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              AuthSocialButton(
                                isLoading: _isLoading,
                                onTap: () =>
                                    _signInWithOAuth(OAuthProvider.facebook),
                                icon: const FaIcon(
                                  FontAwesomeIcons.facebook,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: textSecondary,
                            ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
