import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/branding_assets.dart';
import '../theme/design_tokens.dart';
import '../widgets/branding/cotrainr_logo.dart';
import '../widgets/branding/splash_vector_layers.dart';

/// Animated Flutter runner splash (after native OS splash).
///
/// Composed from SVG atmosphere layers + PNG athlete + SVG logo.
/// Runs real startup work immediately, stays visible ≥ 4 seconds, then routes
/// once via [context.go] to Home (authenticated) or Welcome (guest).
class CotrainrSplashScreen extends StatefulWidget {
  const CotrainrSplashScreen({
    super.key,
    this.runStartupNavigation = true,
  });

  final bool runStartupNavigation;

  @override
  State<CotrainrSplashScreen> createState() => _CotrainrSplashScreenState();
}

typedef SplashPage = CotrainrSplashScreen;

class _CotrainrSplashScreenState extends State<CotrainrSplashScreen>
    with TickerProviderStateMixin {
  static const _minimumDuration = Duration(seconds: 4);
  static const _slowHintAfter = Duration(seconds: 4);

  late final AnimationController _master;
  late final AnimationController _loader;
  late final AnimationController _exit;

  late final Animation<double> _artOpacity;
  late final Animation<double> _artScale;
  late final Animation<double> _glowOpacity;

  bool _hasNavigated = false;
  bool _showPreparing = false;
  String _nextRoute = '/welcome';
  Timer? _slowHintTimer;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _artOpacity = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _artScale = Tween<double>(begin: 1.035, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
    _glowOpacity = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.18, 0.55, curve: Curves.easeInOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FlutterNativeSplash.remove();
      unawaited(_precache());
      final reduce = MediaQuery.of(context).disableAnimations;
      if (reduce) {
        _master.value = 1;
        _loader.value = 0.45;
      } else {
        _master.forward();
        _loader.repeat();
      }
      if (widget.runStartupNavigation) {
        unawaited(_bootstrap());
      }
    });
  }

  Future<void> _precache() async {
    try {
      await Future.wait([
        precacheImage(const AssetImage(BrandingAssets.runnerAthlete), context),
        precacheImage(const AssetImage(BrandingAssets.runnerSplash), context),
      ]);
    } catch (_) {
      // Offline / decode failures must not block startup.
    }
  }

  Future<void> _bootstrap() async {
    final splashStartTime = DateTime.now();
    _slowHintTimer = Timer(_slowHintAfter, () {
      if (mounted && !_hasNavigated) {
        setState(() => _showPreparing = true);
      }
    });

    var next = '/welcome';
    try {
      await SharedPreferences.getInstance();
      final session = Supabase.instance.client.auth.currentSession;
      next = session != null ? '/home' : '/welcome';
    } catch (e, st) {
      debugPrint('[CotrainrSplash] init failed: $e\n$st');
      next = '/welcome';
    }

    final elapsed = DateTime.now().difference(splashStartTime);
    if (elapsed < _minimumDuration) {
      await Future<void>.delayed(_minimumDuration - elapsed);
    }

    if (!mounted || _hasNavigated) return;
    _nextRoute = next;
    _hasNavigated = true;
    _slowHintTimer?.cancel();

    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      await _exit.forward();
    }
    if (!mounted) return;
    context.go(_nextRoute);
  }

  @override
  void dispose() {
    _slowHintTimer?.cancel();
    _master.dispose();
    _loader.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: Listenable.merge([_master, _loader, _exit]),
          builder: (context, _) {
            final exitT = _exit.value;
            final exitOpacity = 1.0 - exitT;
            final exitScale = 1.0 + (0.015 * exitT);

            return Opacity(
              opacity: exitOpacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: exitScale,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final barW = (w * 0.40).clamp(130.0, 210.0);
                    final logoW = (w * 0.28).clamp(96.0, 148.0);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.black),
                        // Vector atmosphere (sharp at every resolution).
                        SplashVectorLayers(
                          opacity: reduce ? 0.55 : _glowOpacity.value,
                        ),
                        // Photographic runner (PNG only for photo).
                        Center(
                          child: Opacity(
                            opacity: reduce ? 1 : _artOpacity.value,
                            child: Transform.scale(
                              scale: reduce ? 1 : _artScale.value,
                              child: Image.asset(
                                BrandingAssets.runnerAthlete,
                                width: w,
                                height: h,
                                fit: BoxFit.contain,
                                alignment: Alignment.topCenter,
                                filterQuality: FilterQuality.high,
                                cacheWidth: (w *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round()
                                    .clamp(320, 1600),
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback: full splash art, then cover baked logo.
                                  return Image.asset(
                                    BrandingAssets.runnerSplash,
                                    width: w,
                                    height: h,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.topCenter,
                                    filterQuality: FilterQuality.high,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // Cover any residual baked lockup from fallback PNG.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: w,
                            height: h * 0.42,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x00000000),
                                  Color(0xCC000000),
                                  Color(0xFF000000),
                                  Color(0xFF000000),
                                ],
                                stops: [0.0, 0.22, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Master SVG logo + wordmark / tagline.
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: MediaQuery.paddingOf(context).bottom +
                              h * 0.14,
                          child: Opacity(
                            opacity: reduce ? 1 : _artOpacity.value,
                            child: CotrainrBrandLockup(
                              logoWidth: logoW,
                              showTagline: true,
                              variant: CotrainrLogoVariant.color,
                            ),
                          ),
                        ),
                        // Real Flutter loader.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom:
                              MediaQuery.paddingOf(context).bottom + h * 0.05,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _IndeterminateBar(
                                width: barW,
                                progress: _loader.value,
                              ),
                              const SizedBox(height: 14),
                              AnimatedOpacity(
                                opacity: _showPreparing ? 1 : 0,
                                duration: const Duration(milliseconds: 280),
                                child: Text(
                                  'PREPARING YOUR EXPERIENCE',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 11,
                                    letterSpacing: 2.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IndeterminateBar extends StatelessWidget {
  const _IndeterminateBar({required this.width, required this.progress});

  final double width;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final travel = width * 1.35;
    final seg = width * 0.42;
    final x = (progress * travel) - seg;

    return SizedBox(
      width: width,
      height: 3.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: ColoredBox(
          color: const Color(0xFF2A2A2A),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: x,
                top: 0,
                bottom: 0,
                width: seg,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        DesignTokens.accentOrange.withValues(alpha: 0.12),
                        DesignTokens.accentOrange,
                        DesignTokens.accentOrangeLight,
                        DesignTokens.accentOrange.withValues(alpha: 0.12),
                      ],
                    ),
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
