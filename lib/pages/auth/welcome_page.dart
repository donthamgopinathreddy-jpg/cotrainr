import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/account_hub_theme.dart';
import '../../widgets/auth/auth_ui.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heroFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));
    _buttonsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    ));
    _controller.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentSession != null) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToLogin() {
    HapticFeedback.lightImpact();
    context.push('/auth/login');
  }

  void _goToCreateAccount() {
    HapticFeedback.lightImpact();
    context.push('/auth/create-account');
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = AuthUi.pageBg(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          child: Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                        decoration: BoxDecoration(
                          color: AccountHubTheme.cardBg(context),
                          borderRadius: BorderRadius.circular(
                            AccountHubTheme.sectionRadius,
                          ),
                          boxShadow: AccountHubTheme.cardShadow(context),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AuthUi.accent.withValues(alpha: isLight ? 0.16 : 0.22),
                              AccountHubTheme.cardBg(context),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              isLight
                                  ? 'assets/images/cotrainr_logo_black.png'
                                  : 'assets/images/cotrainr_logo_white.png',
                              width: 200,
                              height: 80,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  'Cotrainr',
                                  style: AuthUi.heroTitle(context),
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Welcome to Cotrainr',
                              style: AuthUi.heroTitle(context),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Train smarter. Eat better. Track everything in one place.',
                              style: AuthUi.heroSubtitle(context),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _buttonsFade,
                child: SlideTransition(
                  position: _buttonsSlide,
                  child: Column(
                    children: [
                      AuthPrimaryButton(
                        label: 'Login',
                        onPressed: _goToLogin,
                      ),
                      const SizedBox(height: 14),
                      AuthOutlinedButton(
                        label: 'Create Account',
                        onPressed: _goToCreateAccount,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Free to join · No credit card required',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
