import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_wizard_page.dart';

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

  late final AnimationController _buttonController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  late final Animation<double> _buttonScale = Tween(begin: 1.0, end: 0.98).animate(
    CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _idOrEmail.dispose();
    _pass.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _goSignup() {
    HapticFeedback.lightImpact();
    context.push('/auth/signup');
  }

  Future<void> _login() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      // Try email first, if it fails, could try user_id lookup
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
          backgroundColor: Colors.red,
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.primary.withOpacity(0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.bolt, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Welcome back',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _Field(
                          label: 'User ID or Email',
                          controller: _idOrEmail,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                          prefix: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Password',
                          controller: _pass,
                          obscureText: _obscure,
                          validator: (v) =>
                              (v == null || v.length < 6) ? 'Min 6 chars' : null,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _obscure = !_obscure);
                            },
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PrimaryButton(
                          text: 'Login',
                          onTap: _isLoading ? null : _login,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('New here?', style: TextStyle(color: cs.onSurfaceVariant)),
                            TextButton(
                              onPressed: _goSignup,
                              child: const Text('Create account'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Support: support@cotrainr.com',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Website: www.cotrainr.com',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
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

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? prefix;
  final Widget? suffix;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: cs.surface.withOpacity(0.40),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PrimaryButton({required this.text, this.onTap, this.isLoading = false});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  late final Animation<double> _s =
      Tween(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapCancel: () => _c.reverse(),
      onTapUp: (_) => _c.reverse(),
      onTap: widget.onTap == null || widget.isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
      child: ScaleTransition(
        scale: _s,
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.70)],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.20),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  ),
                )
              : Text(
                  widget.text,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}





