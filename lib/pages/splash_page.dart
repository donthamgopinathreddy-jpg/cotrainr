import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/branding_assets.dart';
import '../theme/design_tokens.dart';
import '../core/startup/startup_router_bridge.dart';
import '../widgets/branding/cotrainr_logo.dart';
import '../widgets/branding/splash_light_trails.dart';

/// Layered cinematic Flutter splash (after native OS splash).
///
/// Layers: black → light trails → runner photo → SVG logo → wordmark →
/// tagline text → Flutter loader. Init runs immediately; stays ≥ 3.5s.
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
  static const _minimumDuration = Duration(milliseconds: 3500);
  static const _slowHintAfter = Duration(seconds: 4);

  late final AnimationController _sequence;
  late final AnimationController _loader;
  late final AnimationController _lightsLoop;
  late final AnimationController _exit;

  late final Animation<double> _runnerOpacity;
  late final Animation<double> _runnerScale;
  late final Animation<double> _lightsOpacity;
  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _taglineOpacity;

  bool _hasNavigated = false;
  bool _showPreparing = false;
  String _nextRoute = '/welcome';
  Timer? _slowHintTimer;

  @override
  void initState() {
    super.initState();

    // Timeline mapped onto 0–1700 ms sequence, then hold.
    _sequence = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _lightsLoop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    // 0–600 ms: runner fade + settle 1.03 → 1.0
    _runnerOpacity = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _runnerScale = Tween<double>(begin: 1.03, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequence,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // 400–1100 ms: lights
    _lightsOpacity = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(0.24, 0.65, curve: Curves.easeInOut),
    );

    // 800–1400 ms: brand
    _brandOpacity = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(0.47, 0.82, curve: Curves.easeOutCubic),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sequence,
        curve: const Interval(0.47, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    // 1200–1700 ms: tagline
    _taglineOpacity = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FlutterNativeSplash.remove();
      unawaited(_precache());
      final reduce = MediaQuery.of(context).disableAnimations;
      if (reduce) {
        _sequence.value = 1;
        _loader.value = 0.45;
      } else {
        _sequence.forward();
        _loader.repeat();
        _lightsLoop.repeat();
      }
      if (widget.runStartupNavigation) {
        unawaited(_bootstrap());
      }
    });
  }

  Future<void> _precache() async {
    try {
      await Future.wait([
        precacheImage(const AssetImage(BrandingAssets.runnerHero), context),
        precacheImage(const AssetImage(BrandingAssets.wordmarkOfficial), context),
      ]);
    } catch (_) {}
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
      final pending = StartupRouterBridge.pendingDeepLinkRoute;
      // Password recovery must never be treated as a normal signed-in continue.
      if (pending == '/auth/reset-password') {
        next = '/auth/reset-password';
      } else if (session != null) {
        next = '/auth/continue';
      } else {
        next = '/welcome';
      }
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
    _sequence.dispose();
    _loader.dispose();
    _lightsLoop.dispose();
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
          animation: Listenable.merge([
            _sequence,
            _loader,
            _lightsLoop,
            _exit,
          ]),
          builder: (context, _) {
            final exitT = _exit.value;
            return Opacity(
              opacity: (1.0 - exitT).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1.0 + (0.012 * exitT),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final pad = MediaQuery.paddingOf(context);
                    final logoW = (w * 0.26).clamp(88.0, 132.0);
                    final barW = (w * 0.38).clamp(120.0, 200.0);
                    final runnerH = h * 0.58;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 1 — black
                        const ColoredBox(color: Colors.black),

                        // Layer 3 — orange light trails (behind / around runner)
                        if (!reduce)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: h * 0.62,
                            child: SplashLightTrails(
                              progress: _lightsOpacity.value,
                              opacity: 0.55 + 0.35 * _lightsLoop.value,
                            ),
                          )
                        else
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: h * 0.62,
                            child: const SplashLightTrails(
                              progress: 1,
                              opacity: 0.7,
                            ),
                          ),

                        // Layer 2 — runner photo (upper 55–60%, contain)
                        Positioned(
                          top: pad.top + h * 0.02,
                          left: 0,
                          right: 0,
                          height: runnerH,
                          child: Opacity(
                            opacity: reduce ? 1 : _runnerOpacity.value,
                            child: Transform.scale(
                              scale: reduce ? 1 : _runnerScale.value,
                              alignment: Alignment.topCenter,
                              child: Image.asset(
                                BrandingAssets.runnerHero,
                                fit: BoxFit.contain,
                                alignment: Alignment.topCenter,
                                filterQuality: FilterQuality.high,
                                cacheWidth: (w *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round()
                                    .clamp(320, 1400),
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    BrandingAssets.runnerAthlete,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.topCenter,
                                    filterQuality: FilterQuality.high,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Soft fade into brand zone
                        Positioned(
                          left: 0,
                          right: 0,
                          top: h * 0.48,
                          height: h * 0.18,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x00000000),
                                  Color(0xCC000000),
                                  Color(0xFF000000),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Layers 4–6 — logo SVG, wordmark, tagline
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: pad.bottom + h * 0.12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: reduce
                                    ? const AlwaysStoppedAnimation(1)
                                    : _brandOpacity,
                                child: SlideTransition(
                                  position: reduce
                                      ? const AlwaysStoppedAnimation(
                                          Offset.zero)
                                      : _brandSlide,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CotrainrLogo(
                                        width: logoW,
                                        variant: CotrainrLogoVariant.color,
                                      ),
                                      SizedBox(height: logoW * 0.12),
                                      CotrainrWordmark(
                                        width: (logoW * 1.65)
                                            .clamp(140.0, 240.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: logoW * 0.10),
                              Opacity(
                                opacity: reduce ? 1 : _taglineOpacity.value,
                                child: CotrainrTagline(
                                  fontSize: (w * 0.028).clamp(9.0, 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Layer 7 — Flutter loader (from ~1500 ms)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: pad.bottom + h * 0.045,
                          child: Opacity(
                            opacity: reduce
                                ? 1
                                : Curves.easeOut.transform(
                                    ((_sequence.value - 0.88) / 0.12)
                                        .clamp(0.0, 1.0),
                                  ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _IndeterminateBar(
                                  width: barW,
                                  progress: _loader.value,
                                ),
                                const SizedBox(height: 12),
                                AnimatedOpacity(
                                  opacity: _showPreparing ? 1 : 0,
                                  duration: const Duration(milliseconds: 280),
                                  child: Text(
                                    'PREPARING YOUR EXPERIENCE',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 10.5,
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      height: 3.2,
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
