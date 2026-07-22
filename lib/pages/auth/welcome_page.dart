import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/branding_assets.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/cotrainr_logo.dart';
import '../../widgets/branding/splash_light_trails.dart';
import '../../widgets/branding/splash_vector_layers.dart';

/// Dark premium Welcome landing for unauthenticated users (after splash).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _artFade;
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
      duration: const Duration(milliseconds: 1100),
    );

    _artFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
    ));
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
      precacheImage(const AssetImage(BrandingAssets.runnerHero), context);
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
    final pad = MediaQuery.paddingOf(context);
    final logoW = (size.width * 0.28).clamp(96.0, 140.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),

            // Upper athlete artwork (~45–50%)
            FadeTransition(
              opacity: _artFade,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: size.height * 0.50,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const SplashLightTrails(progress: 1, opacity: 0.45),
                      const SplashVectorLayers(opacity: 0.25),
                      Image.asset(
                        BrandingAssets.runnerHero,
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.high,
                        cacheWidth: (size.width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round()
                            .clamp(320, 1400),
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            BrandingAssets.runnerAthlete,
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                          );
                        },
                      ),
                      // Black fade toward middle
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x66000000),
                              Color(0xFF000000),
                            ],
                            stops: [0.35, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    FadeTransition(
                      opacity: _logoFade,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: CotrainrBrandLockup(
                          logoWidth: logoW,
                          showTagline: true,
                          showWordmark: true,
                          variant: CotrainrLogoVariant.color,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
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
                          color: Colors.white.withValues(alpha: 0.55),
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
          ],
        ),
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.accentOrange,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                DesignTokens.accentOrange.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: DesignTokens.accentOrange.withValues(alpha: 0.85),
            width: 1.5,
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      ),
    );
  }
}
