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
  final _scrollController = ScrollController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _showSuccess = false;
  bool _rememberMe = false;

  late final AnimationController _entrance;
  late final Animation<double> _headerAnim;
  late final Animation<double> _cardAnim;
  late final Animation<double> _footerAnim;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _headerAnim = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _cardAnim = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.18, 0.78, curve: Curves.easeOutCubic),
    );
    _footerAnim = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    );
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _idOrEmail.dispose();
    _pass.dispose();
    _scrollController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _goSignup() {
    HapticFeedback.lightImpact();
    context.push('/auth/create-account');
  }

  Future<void> _forgotPassword() async {
    HapticFeedback.lightImpact();

    final emailController = TextEditingController();
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondary) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AuthSectionCard(
                      title: 'Reset password',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter your email and we’ll send a reset link.',
                            style: AuthUi.pageSubtitle(context)
                                .copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofocus: true,
                            decoration: AuthUi.fieldDecoration(
                              context,
                              label: 'Email',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                color: AccountHubTheme.rowSubtitle(context)
                                    .color,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AuthOutlinedButton(
                                  label: 'Cancel',
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AuthPrimaryButton(
                                  label: 'Send',
                                  onPressed: () => Navigator.pop(
                                    context,
                                    emailController.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    emailController.dispose();

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

    setState(() {
      _isLoading = true;
      _showSuccess = false;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _idOrEmail.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 320));
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
      setState(() {
        _isLoading = false;
        _showSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textSecondary = AccountHubTheme.rowSubtitle(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final pageBg = AuthUi.pageBg(context);
    final iconColor = cs.onSurface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: pageBg,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: true,
        body: AuthScreenBackground(
          scrimStrength: 0.42,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/welcome'),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        controller: _scrollController,
                        physics: bottomInset > 0
                            ? const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              )
                            : const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16 + bottomInset.clamp(0, 24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                                AuthFadeSlide(
                                  animation: _headerAnim,
                                  child: Column(
                                    children: [
                                      Text(
                                        'Welcome back',
                                        textAlign: TextAlign.center,
                                        style: AuthUi.pageTitle(context)
                                            .copyWith(fontSize: 24),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Sign in to continue training.',
                                        textAlign: TextAlign.center,
                                        style: AuthUi.pageSubtitle(context)
                                            .copyWith(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                AuthFadeSlide(
                                  animation: _cardAnim,
                                  begin: const Offset(0, 0.05),
                                  beginScale: 0.98,
                                  child: AuthSectionCard(
                                    compact: true,
                                    title: 'Account',
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AuthTapToTypeField(
                                            controller: _idOrEmail,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            validator: (v) => (v == null ||
                                                    v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                            style: AuthUi.fieldTextStyle(
                                              context,
                                              large: true,
                                            ),
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
                                          const SizedBox(height: 12),
                                          AuthTapToTypeField(
                                            controller: _pass,
                                            obscureText: _obscure,
                                            validator: (v) =>
                                                (v == null || v.length < 6)
                                                    ? 'Min 6 chars'
                                                    : null,
                                            style: AuthUi.fieldTextStyle(
                                              context,
                                              large: true,
                                            ),
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
                                                icon: AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  transitionBuilder:
                                                      (child, anim) =>
                                                          FadeTransition(
                                                    opacity: anim,
                                                    child: ScaleTransition(
                                                      scale: anim,
                                                      child: child,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    _obscure
                                                        ? Icons
                                                            .visibility_outlined
                                                        : Icons
                                                            .visibility_off_outlined,
                                                    key: ValueKey(_obscure),
                                                    size: 20,
                                                    color: textSecondary.color,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  HapticFeedback
                                                      .selectionClick();
                                                  setState(() =>
                                                      _obscure = !_obscure);
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  HapticFeedback
                                                      .selectionClick();
                                                  setState(() =>
                                                      _rememberMe =
                                                          !_rememberMe);
                                                },
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Row(
                                                  children: [
                                                    AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 180,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      width: 22,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        color: _rememberMe
                                                            ? AuthUi.accent
                                                            : Colors
                                                                .transparent,
                                                        border: Border.all(
                                                          color: _rememberMe
                                                              ? AuthUi.accent
                                                              : cs.onSurface
                                                                  .withValues(
                                                                  alpha: 0.28,
                                                                ),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: AnimatedOpacity(
                                                        duration:
                                                            const Duration(
                                                          milliseconds: 160,
                                                        ),
                                                        opacity: _rememberMe
                                                            ? 1
                                                            : 0,
                                                        child: Icon(
                                                          Icons.check,
                                                          size: 14,
                                                          color: DesignTokens
                                                              .darkTextPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Remember me',
                                                      style: textSecondary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              AuthTextLink(
                                                label: 'Forgot password?',
                                                fontSize: 13,
                                                onTap: _forgotPassword,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          AuthPrimaryButton(
                                            label: 'Sign In',
                                            onPressed: _login,
                                            isLoading: _isLoading,
                                            showSuccess: _showSuccess,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AuthFadeSlide(
                                  animation: _footerAnim,
                                  child: Column(
                                    children: [
                                      AuthSectionCard(
                                        compact: true,
                                        title: 'Or continue with',
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AuthSocialButton(
                                              isLoading: _isLoading,
                                              onTap: () => _signInWithOAuth(
                                                OAuthProvider.google,
                                              ),
                                              icon: FaIcon(
                                                FontAwesomeIcons.google,
                                                size: 22,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            AuthSocialButton(
                                              isLoading: _isLoading,
                                              onTap: () => _signInWithOAuth(
                                                OAuthProvider.apple,
                                              ),
                                              icon: FaIcon(
                                                FontAwesomeIcons.apple,
                                                size: 24,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            AuthSocialButton(
                                              isLoading: _isLoading,
                                              onTap: () => _signInWithOAuth(
                                                OAuthProvider.facebook,
                                              ),
                                              icon: FaIcon(
                                                FontAwesomeIcons.facebook,
                                                size: 22,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Don't have an account? ",
                                            style: textSecondary,
                                          ),
                                          AuthTextLink(
                                            label: 'Sign Up',
                                            onTap: _goSignup,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      );
  }
}
