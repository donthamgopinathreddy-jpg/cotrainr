import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _logoController;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoRotationAnimation;
  late final Animation<double> _titleFadeAnimation;
  late final Animation<Offset> _titleSlideAnimation;
  late final Animation<double> _subtitleFadeAnimation;
  late final Animation<Offset> _subtitleSlideAnimation;
  late final Animation<double> _buttonsFadeAnimation;
  late final Animation<Offset> _buttonsSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );
    
    _logoRotationAnimation = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    
    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    
    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _subtitleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    
    _buttonsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _buttonsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    _checkSession();
    _logoController.forward();
    _animationController.forward();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    
    if (session != null) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _logoController.dispose();
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
    final bgColor = DesignTokens.backgroundOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo with scale and rotation animation
              Center(
                child: ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: RotationTransition(
                    turns: _logoRotationAnimation,
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/images/cotrainr_logo_white.png'
                          : 'assets/images/cotrainr_logo_black.png',
                      width: 200,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image not found
                        debugPrint('Logo image not found: ${Theme.of(context).brightness == Brightness.dark ? "cotrainr_logo_white.png" : "cotrainr_logo_black.png"}');
                        return Container(
                          width: 200,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: DesignTokens.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              // Welcome Text with fade and slide
              FadeTransition(
                opacity: _titleFadeAnimation,
                child: SlideTransition(
                  position: _titleSlideAnimation,
                  child: Text(
                    'Welcome to Cotrainr',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: DesignTokens.fontWeightBold,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing8),
              
              // Subtitle with fade and slide
              FadeTransition(
                opacity: _subtitleFadeAnimation,
                child: SlideTransition(
                  position: _subtitleSlideAnimation,
                  child: Text(
                    'Transform your fitness journey',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeBody,
                      color: textSecondary,
                      fontWeight: DesignTokens.fontWeightRegular,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              // Buttons with fade and slide
              FadeTransition(
                opacity: _buttonsFadeAnimation,
                child: SlideTransition(
                  position: _buttonsSlideAnimation,
                  child: Column(
                    children: [
                      // Login Button
                      _WelcomeButton(
                        text: 'Login',
                        onTap: _goToLogin,
                        isPrimary: true,
                      ),
                      
                      const SizedBox(height: DesignTokens.spacing16),
                      
                      // Create Account Button
                      _WelcomeButton(
                        text: 'Create Account',
                        onTap: _goToCreateAccount,
                        isPrimary: false,
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

class _WelcomeButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isPrimary;

  const _WelcomeButton({
    required this.text,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DesignTokens.interactionDuration,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? DesignTokens.primaryGradient
                : null,
            color: widget.isPrimary
                ? null
                : DesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: widget.isPrimary
                ? null
                : Border.all(
                    color: DesignTokens.borderColorOf(context),
                    width: 1,
                  ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.isPrimary
                  ? Colors.white
                  : DesignTokens.textPrimaryOf(context),
              fontWeight: DesignTokens.fontWeightSemiBold,
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
        ),
      ),
    );
  }
}
