import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idOrEmail = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _idOrEmail.dispose();
    _pass.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _goSignup() {
    HapticFeedback.lightImpact();
    context.push('/auth/create-account');
  }

  Future<void> _login() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithPassword(
        email: _idOrEmail.text.trim(),
        password: _pass.text,
      );

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = DesignTokens.backgroundOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing24,
                vertical: DesignTokens.spacing32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: DesignTokens.spacing40),
                  
                  // Minimalist logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: DesignTokens.accentOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: DesignTokens.accentOrange,
                        size: 40,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: DesignTokens.spacing48),
                  
                  // Clean typography
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: DesignTokens.fontWeightBold,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: DesignTokens.spacing8),
                  
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeBody,
                      color: textSecondary,
                      fontWeight: DesignTokens.fontWeightRegular,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: DesignTokens.spacing48),
                  
                  // Clean form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CleanField(
                          label: 'User ID or Email',
                          controller: _idOrEmail,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                          prefix: Icons.person_outline_rounded,
                        ),
                        
                        const SizedBox(height: DesignTokens.spacing20),
                        
                        _CleanField(
                          label: 'Password',
                          controller: _pass,
                          obscureText: _obscure,
                          validator: (v) =>
                              (v == null || v.length < 6) ? 'Min 6 chars' : null,
                          prefix: Icons.lock_outline_rounded,
                          suffix: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _obscure = !_obscure);
                          },
                        ),
                        
                        const SizedBox(height: DesignTokens.spacing32),
                        
                        _CleanButton(
                          text: 'Sign In',
                          onTap: _isLoading ? null : _login,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: DesignTokens.spacing24),
                  
                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: DesignTokens.fontSizeBodySmall,
                        ),
                      ),
                      GestureDetector(
                        onTap: _goSignup,
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontWeight: DesignTokens.fontWeightSemiBold,
                            fontSize: DesignTokens.fontSizeBodySmall,
                            color: DesignTokens.accentOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CleanField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final IconData prefix;
  final IconData? suffix;
  final VoidCallback? onSuffixTap;

  const _CleanField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    required this.prefix,
    this.suffix,
    this.onSuffixTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        color: textPrimary,
        fontWeight: DesignTokens.fontWeightMedium,
        fontSize: DesignTokens.fontSizeBody,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: textSecondary,
          fontWeight: DesignTokens.fontWeightRegular,
        ),
        prefixIcon: Icon(prefix, color: textSecondary, size: 20),
        suffixIcon: suffix != null
            ? IconButton(
                icon: Icon(suffix, color: textSecondary, size: 20),
                onPressed: onSuffixTap,
              )
            : null,
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: DesignTokens.accentOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: DesignTokens.accentRed,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing16,
        ),
      ),
    );
  }
}

class _CleanButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const _CleanButton({
    required this.text,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<_CleanButton> createState() => _CleanButtonState();
}

class _CleanButtonState extends State<_CleanButton>
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
        if (widget.onTap != null && !widget.isLoading) {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        }
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: DesignTokens.accentOrange,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: DesignTokens.fontWeightSemiBold,
                    fontSize: DesignTokens.fontSizeBody,
                  ),
                ),
        ),
      ),
    );
  }
}
