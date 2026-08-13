import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../widgets/auth/auth_ui.dart';
import '../../widgets/branding/cotrainr_logo.dart';

/// Premium Welcome landing for unauthenticated users (after splash).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _loginFade;
  late final Animation<Offset> _loginSlide;
  late final Animation<double> _createFade;
  late final Animation<Offset> _createSlide;
  late final Animation<double> _hintFade;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));
    _loginFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    );
    _loginSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    ));
    _createFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    );
    _createSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    ));
    _hintFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _goLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    context.push('/auth/login');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _goCreate() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    context.push('/auth/create-account');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final pageBg = AuthUi.pageBg(context);
    final logoW = (size.width * 0.28).clamp(96.0, 140.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AuthTheme.overlay(context),
      child: Scaffold(
        backgroundColor: pageBg,
        body: AuthScreenBackground.login(
          scrimStrength: 0.35,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _logoFade,
                    child: SlideTransition(
                      position: _logoSlide,
                      child: Hero(
                        tag: 'auth-cotrainr-logo',
                        child: Material(
                          type: MaterialType.transparency,
                          child: CotrainrBrandLockup(
                            logoWidth: logoW,
                            showTagline: true,
                            showWordmark: true,
                            variant: CotrainrLogoVariant.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _loginFade,
                    child: SlideTransition(
                      position: _loginSlide,
                      child: AuthPrimaryButton(
                        label: 'Login',
                        onPressed: _busy ? null : _goLogin,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _createFade,
                    child: SlideTransition(
                      position: _createSlide,
                      child: _WelcomeButton(
                        label: 'Create Account',
                        filled: false,
                        onPressed: _busy ? null : _goCreate,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _hintFade,
                    child: Text(
                      'Free to join · No credit card required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AuthTheme.secondaryText(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: pad.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeButton extends StatefulWidget {
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final onAccent = DesignTokens.darkTextPrimary;

    final child = Text(
      widget.label,
      style: TextStyle(
        color: widget.filled ? onAccent : AuthTheme.primaryText(context),
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    return GestureDetector(
      onTapDown:
          widget.onPressed == null ? null : (_) => setState(() => _pressed = true),
      onTapUp:
          widget.onPressed == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.onPressed == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 0.98 : 1,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: widget.filled
              ? FilledButton(
                  onPressed: widget.onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignTokens.accentOrange,
                    foregroundColor: onAccent,
                    disabledBackgroundColor:
                        DesignTokens.accentOrange.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: child,
                )
              : OutlinedButton(
                  onPressed: widget.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AuthTheme.primaryText(context),
                    side: BorderSide(color: AuthTheme.fieldBorder(context)),
                    backgroundColor: AuthTheme.backSurface(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}
