import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _glowController;
  
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
    
    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
    
    _mainController.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session != null) {
      context.go('/home');
    } else {
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = DesignTokens.backgroundOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Minimalist background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _MinimalPatternPainter(isDark: isDark),
            ),
          ),
          
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with subtle glow
                    AnimatedBuilder(
                      animation: _glow,
                      builder: (context, child) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: DesignTokens.accentOrange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 56,
                              color: DesignTokens.accentOrange,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: DesignTokens.spacing32),
                    
                    // App name - clean typography
                    Text(
                      'COTRAINR',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: DesignTokens.fontWeightBold,
                        letterSpacing: 3,
                        color: DesignTokens.textPrimaryOf(context),
                      ),
                    ),
                    
                    const SizedBox(height: DesignTokens.spacing8),
                    
                    Text(
                      'Your Fitness Journey Starts Here',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.fontWeightRegular,
                        color: DesignTokens.textSecondaryOf(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalPatternPainter extends CustomPainter {
  final bool isDark;

  _MinimalPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // Subtle grid pattern
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint..strokeWidth = 0.5,
      );
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
