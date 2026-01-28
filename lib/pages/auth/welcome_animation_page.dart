import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';

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

    // Opening animation controller
    _openingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Welcome message animation controller
    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Opening animations
    _openingScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _openingController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _openingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _openingController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // Welcome message animations
    _welcomeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // Start opening animation
    _openingController.forward().then((_) {
      // After opening animation, start welcome animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _welcomeController.forward().then((_) {
            // After welcome animation, navigate to home
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                context.go('/home');
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
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? DesignTokens.darkBackground
        : Colors.white;
    final textPrimary = DesignTokens.textPrimaryOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Opening animation
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
                      decoration: BoxDecoration(
                        gradient: DesignTokens.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Welcome message animation
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
                        // Welcome icon/logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: DesignTokens.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spacing32),
                        
                        // Welcome text
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
                          'Let\'s start your fitness journey',
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
    );
  }
}
