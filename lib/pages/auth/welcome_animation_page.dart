import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../widgets/auth/auth_ui.dart';

class WelcomeAnimationPage extends StatefulWidget {
  const WelcomeAnimationPage({super.key});

  @override
  State<WelcomeAnimationPage> createState() => _WelcomeAnimationPageState();
}

class _WelcomeAnimationPageState extends State<WelcomeAnimationPage>
    with TickerProviderStateMixin {
  late final AnimationController _openingController;
  late final AnimationController _welcomeController;
  late final Animation<double> _openingScale;
  late final Animation<double> _openingFade;
  late final Animation<double> _welcomeFade;
  late final Animation<Offset> _welcomeSlide;

  @override
  void initState() {
    super.initState();

    _openingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _openingScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _openingController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _openingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _openingController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _welcomeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _openingController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _welcomeController.forward().then((_) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                context.go('/auth/continue');
              }
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _openingController.dispose();
    _welcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = AuthUi.pageBg(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: pageBg,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: AuthScreenBackground(
          scrimStrength: 0.3,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _openingController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _openingFade.value,
                    child: Center(
                      child: ScaleTransition(
                        scale: _openingScale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: DesignTokens.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              color: DesignTokens.darkTextPrimary,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _welcomeController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _welcomeFade.value,
                    child: SlideTransition(
                      position: _welcomeSlide,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AuthBrandLogo(width: 160),
                            const SizedBox(height: DesignTokens.spacing32),
                            Text(
                              'Welcome!',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: DesignTokens.fontWeightBold,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.spacing12),
                            Text(
                              "Let's start your fitness journey",
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeBody,
                                color: DesignTokens.textSecondaryOf(context),
                                fontWeight: DesignTokens.fontWeightRegular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
