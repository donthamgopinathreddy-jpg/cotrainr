import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/branding_assets.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/cotrainr_logo.dart';
import '../../widgets/branding/splash_vector_layers.dart';

/// Premium orange Welcome landing for unauthenticated users (after splash).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _logoScale;
  late final Animation<double> _loginFade;
  late final Animation<Offset> _loginSlide;
  late final Animation<double> _createFade;
  late final Animation<Offset> _createSlide;
  late final Animation<double> _hintFade;
  late final Animation<double> _decorFade;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );

    _decorFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.12, 0.55, curve: Curves.easeOutCubic),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.12, 0.55, curve: Curves.easeOutCubic),
    ));
    _logoScale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.12, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _loginFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic),
    );
    _loginSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic),
    ));
    _createFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.52, 0.88, curve: Curves.easeOutCubic),
    );
    _createSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.52, 0.88, curve: Curves.easeOutCubic),
    ));
    _hintFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.68, 1.0, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
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
    final logoWidth = (size.width * 0.58).clamp(200.0, 340.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: DesignTokens.accentOrange,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DesignTokens.accentOrange,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: DesignTokens.accentOrange),
            FadeTransition(
              opacity: _decorFade,
              child: const SplashVectorLayers(opacity: 0.42),
            ),
            // Soft pattern wash from official orange brand art (not the logo).
            FadeTransition(
              opacity: _decorFade,
              child: Opacity(
                opacity: 0.10,
                child: IgnorePointer(
                  child: Image.asset(
                    BrandingAssets.orangeFullLogo,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    color: Colors.white.withValues(alpha: 0.35),
                    colorBlendMode: BlendMode.srcATop,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: _logoFade,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: CotrainrBrandLockup(
                            logoWidth: logoWidth * 0.55,
                            showTagline: false,
                            variant: CotrainrLogoVariant.white,
                            wordmarkColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _loginFade,
                      child: SlideTransition(
                        position: _loginSlide,
                        child: _WelcomeButton(
                          label: 'Login',
                          filled: true,
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
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 18),
                  ],
                ),
              ),
            ),
          ],
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
    final child = AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: widget.filled
            ? FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: DesignTokens.accentOrange,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              )
            : OutlinedButton(
                onPressed: widget.onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
      ),
    );

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: child,
    );
  }
}
