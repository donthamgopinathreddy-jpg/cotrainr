import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';

class SignupWizardPage extends StatefulWidget {
  const SignupWizardPage({super.key});

  @override
  State<SignupWizardPage> createState() => _SignupWizardPageState();
}

class _SignupWizardPageState extends State<SignupWizardPage>
    with TickerProviderStateMixin {
  final _page = PageController();
  int _step = 0;

  // Step 1
  final _userId = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  String? _userIdAvailabilityStatus;
  bool _isCheckingUserId = false;
  String? _emailValidationStatus; // 'valid', 'invalid', 'taken', null
  bool _isCheckingEmail = false;

  // Step 2
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  String _phoneCountryCode = '+91';

  // Step 3
  DateTime _dob = DateTime(2002, 1, 1);
  String _gender = 'Male';

  // Step 4
  bool _heightInCm = true;
  double _heightCm = 170;
  int _feet = 5;
  int _inch = 7;

  bool _weightInKg = true;
  double _weightKg = 70;
  double _weightLbs = 154;

  // Step 5
  final List<String> _goals = [
    'Weight Loss',
    'Muscle Gain',
    'Strength',
    'Yoga',
    'Cardio Fitness',
    'Boxing',
    'Pilates',
    'Zumba',
    'Calisthenics',
    'Nutrition',
  ];
  final Set<String> _selectedGoals = {'Weight Loss'};
  String _role = 'Client';

  bool _isSubmitting = false;
  
  late final AnimationController _fadeController;
  late final AnimationController _stepTransitionController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    
    _stepTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _stepTransitionController.forward();
  }

  @override
  void dispose() {
    _page.dispose();
    _userId.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _fadeController.dispose();
    _stepTransitionController.dispose();
    super.dispose();
  }

  double get _heightMeters {
    final cm = _heightInCm ? _heightCm : ((_feet * 30.48) + (_inch * 2.54));
    return cm / 100.0;
  }

  double get _weightKgResolved {
    return _weightInKg ? _weightKg : (_weightLbs * 0.45359237);
  }

  double get _bmi {
    final h = _heightMeters;
    if (h <= 0) return 0;
    return _weightKgResolved / (h * h);
  }

  bool _validateStep1() {
    final userIdText = _userId.text.trim();
    if (userIdText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID is required')),
      );
      return false;
    }
    if (userIdText.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID must be at least 6 characters')),
      );
      return false;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(userIdText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID can only contain lowercase letters, numbers, and underscore')),
      );
      return false;
    }
    if (_userIdAvailabilityStatus != 'available') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure User ID is available')),
      );
      return false;
    }

    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email is required')),
      );
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_email.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return false;
    }
    if (_emailValidationStatus == 'taken') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This email is already used')),
      );
      return false;
    }
    if (_emailValidationStatus != 'valid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure email is valid')),
      );
      return false;
    }

    final pass = _pass.text;
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password is required')),
      );
      return false;
    }
    if (!_isValidPassword(pass)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must have 1 uppercase, 1 lowercase, 1 number, and 1 special character')),
      );
      return false;
    }

    if (_confirmPass.text != _pass.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return false;
    }

    return true;
  }

  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    return hasUpper && hasLower && hasNumber && hasSpecial;
  }

  Future<void> _checkUserIdAvailability(String userId) async {
    if (userId.isEmpty || !RegExp(r'^[a-z0-9_]+$').hasMatch(userId)) {
      setState(() {
        _userIdAvailabilityStatus = null;
        _isCheckingUserId = false;
      });
      return;
    }

    setState(() {
      _isCheckingUserId = true;
      _userIdAvailabilityStatus = 'checking';
    });

    await Future.delayed(const Duration(milliseconds: 800));

    // Simulate availability check - in production, call your API
    final isAvailable = userId.length >= 3;
    if (mounted) {
      setState(() {
        _userIdAvailabilityStatus = isAvailable ? 'available' : 'taken';
        _isCheckingUserId = false;
      });
    }
  }

  Future<void> _checkEmailValidation(String email) async {
    final emailTrimmed = email.trim();
    
    if (emailTrimmed.isEmpty) {
      setState(() {
        _emailValidationStatus = null;
        _isCheckingEmail = false;
      });
      return;
    }

    // Check email format first
    final isValidFormat = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailTrimmed);
    
    if (!isValidFormat) {
      setState(() {
        _emailValidationStatus = 'invalid';
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailValidationStatus = 'checking';
    });

    // Simulate API call to check if email is already used
    await Future.delayed(const Duration(milliseconds: 800));

    // For now, simulate: email is available if it doesn't contain "taken" or "used"
    final isAvailable = !emailTrimmed.toLowerCase().contains('taken') && 
                        !emailTrimmed.toLowerCase().contains('used');
    
    if (mounted) {
      setState(() {
        _emailValidationStatus = isAvailable ? 'valid' : 'taken';
        _isCheckingEmail = false;
      });
    }
  }

  void _next() {
    if (_step == 0 && !_validateStep1()) {
      return;
    }

    if (_step < 4) {
      _stepTransitionController.reset();
      setState(() => _step++);
      _page.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _stepTransitionController.forward();
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      _stepTransitionController.reset();
      setState(() => _step--);
      _page.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      _stepTransitionController.forward();
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;

      final heightCm = _heightInCm ? _heightCm : ((_feet * 30.48) + (_inch * 2.54));
      final weightKg = _weightInKg ? _weightKg : (_weightLbs * 0.45359237);

      final response = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _pass.text,
        data: {
          'user_id': _userId.text.trim(),
          'first_name': _first.text.trim(),
          'last_name': _last.text.trim(),
          'phone': '${_phoneCountryCode}${_phone.text.trim()}',
          'dob': _dob.toIso8601String(),
          'gender': _gender,
          'height_cm': heightCm,
          'weight_kg': weightKg,
          'bmi': _bmi,
          'goals': _selectedGoals.toList(),
          'role': _role.toLowerCase(),
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        var session = response.session;
        
        if (session == null) {
          try {
            final signInResponse = await supabase.auth.signInWithPassword(
              email: _email.text.trim(),
              password: _pass.text,
            );
            session = signInResponse.session;
          } catch (e) {
            session = supabase.auth.currentSession;
          }
        }
        
        if (session == null) {
          await Future.delayed(const Duration(milliseconds: 300));
          session = supabase.auth.currentSession;
        }
        
        if (session == null) {
          await Future.delayed(const Duration(milliseconds: 300));
          session = supabase.auth.currentSession;
        }
        
        if (session != null) {
          final role = _role.toLowerCase();
          if (!mounted) return;
          
          // Redirect to permissions page first
          context.go('/auth/permissions', extra: {'role': role});
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account created! Please check your email to confirm.'),
              backgroundColor: DesignTokens.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
              ),
            ),
          );
          context.go('/auth/login');
        }
      } else {
        throw Exception('Signup failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed: ${e.toString()}'),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Create Account';
      case 1:
        return 'Personal Info';
      case 2:
        return 'About You';
      case 3:
        return 'Body Metrics';
      case 4:
        return 'Preferences';
      default:
        return 'Create Account';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0:
        return 'Set up your credentials';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'Age and gender';
      case 3:
        return 'Height and weight';
      case 4:
        return 'Goals and role';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : DesignTokens.backgroundOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _back,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStepTitle(_step),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getStepSubtitle(_step),
                            style: TextStyle(
                              fontSize: 15,
                              color: textSecondary,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Animated Gradient Progress indicator
                    Row(
                      children: List.generate(5, (index) {
                        final isActive = index <= _step;
                        final isCurrent = index == _step;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            height: isCurrent ? 4 : 3,
                            margin: EdgeInsets.only(
                              right: index < 4 ? 6 : 0,
                            ),
                            decoration: BoxDecoration(
                              gradient: isActive
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                                  )
                                : null,
                              color: isActive
                                ? null
                                : DesignTokens.borderColorOf(context),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: DesignTokens.accentOrange
                                        .withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Content Section with better spacing
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step1Content(
                      userId: _userId,
                      email: _email,
                      pass: _pass,
                      confirmPass: _confirmPass,
                      userIdAvailabilityStatus: _userIdAvailabilityStatus,
                      isCheckingUserId: _isCheckingUserId,
                      onUserIdChanged: _checkUserIdAvailability,
                      emailValidationStatus: _emailValidationStatus,
                      isCheckingEmail: _isCheckingEmail,
                      onEmailChanged: _checkEmailValidation,
                    ),
                    _Step2Content(
                      first: _first,
                      last: _last,
                      phone: _phone,
                      phoneCountryCode: _phoneCountryCode,
                      onPhoneCountryCodeChanged: (code) {
                        setState(() => _phoneCountryCode = code);
                      },
                    ),
                    _Step3Content(
                      dob: _dob,
                      gender: _gender,
                      onDobChanged: (d) {
                        HapticFeedback.selectionClick();
                        setState(() => _dob = d);
                      },
                      onGenderChanged: (g) {
                        HapticFeedback.selectionClick();
                        setState(() => _gender = g);
                      },
                    ),
                    _Step4Content(
                      heightInCm: _heightInCm,
                      weightInKg: _weightInKg,
                      heightCm: _heightCm,
                      feet: _feet,
                      inch: _inch,
                      weightKg: _weightKg,
                      weightLbs: _weightLbs,
                      onToggleHeightUnit: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _heightInCm = v);
                      },
                      onToggleWeightUnit: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _weightInKg = v);
                      },
                      onHeightCm: (v) => setState(() => _heightCm = v),
                      onFeet: (v) => setState(() => _feet = v),
                      onInch: (v) => setState(() => _inch = v),
                      onWeightKg: (v) => setState(() => _weightKg = v),
                      onWeightLbs: (v) => setState(() => _weightLbs = v),
                    ),
                    _Step5Content(
                      goals: _goals,
                      selected: _selectedGoals,
                      role: _role,
                      onToggleGoal: (g) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_selectedGoals.contains(g) && _selectedGoals.length > 1) {
                            _selectedGoals.remove(g);
                          } else {
                            _selectedGoals.add(g);
                          }
                        });
                      },
                      onRoleChanged: (r) {
                        HapticFeedback.selectionClick();
                        setState(() => _role = r);
                      },
                    ),
                  ],
                ),
              ),

              // Navigation button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _isSubmitting ? null : _next,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                          ),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                        ),
                        child: _isSubmitting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _step == 4 ? 'Create Account' : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '>',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                      ),
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

// Step 1: Credentials
class _Step1Content extends StatefulWidget {
  final TextEditingController userId;
  final TextEditingController email;
  final TextEditingController pass;
  final TextEditingController confirmPass;
  final String? userIdAvailabilityStatus;
  final bool isCheckingUserId;
  final ValueChanged<String> onUserIdChanged;
  final String? emailValidationStatus;
  final bool isCheckingEmail;
  final ValueChanged<String> onEmailChanged;

  const _Step1Content({
    required this.userId,
    required this.email,
    required this.pass,
    required this.confirmPass,
    required this.userIdAvailabilityStatus,
    required this.isCheckingUserId,
    required this.onUserIdChanged,
    required this.emailValidationStatus,
    required this.isCheckingEmail,
    required this.onEmailChanged,
  });

  @override
  State<_Step1Content> createState() => _Step1ContentState();
}

class _Step1ContentState extends State<_Step1Content> {
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  @override
  void initState() {
    super.initState();
    // Listen to password changes to update validation chips
    widget.pass.addListener(_onPasswordChanged);
    widget.confirmPass.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.pass.removeListener(_onPasswordChanged);
    widget.confirmPass.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      // Trigger rebuild to update password validation chips
    });
  }

  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    return hasUpper && hasLower && hasNumber && hasSpecial;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final pass = widget.pass.text;
    final passwordsMatch = widget.pass.text == widget.confirmPass.text && widget.confirmPass.text.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _TextFieldCard(
            label: 'User ID',
            controller: widget.userId,
            hint: 'lowercase, numbers, _ only',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.text,
            onChanged: (value) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (widget.userId.text == value) {
                  widget.onUserIdChanged(value);
                }
              });
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                // Only convert letters to lowercase, preserve numbers and underscores
                final newText = newValue.text.replaceAllMapped(
                  RegExp(r'[A-Z]'),
                  (match) => match.group(0)!.toLowerCase(),
                );
                return TextEditingValue(
                  text: newText,
                  selection: newValue.selection,
                );
              }),
            ],
            suffix: widget.isCheckingUserId
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : widget.userIdAvailabilityStatus == 'available'
                ? Icon(Icons.check_circle, color: DesignTokens.accentGreen, size: 20)
                : widget.userIdAvailabilityStatus == 'taken'
                  ? Icon(Icons.cancel, color: DesignTokens.accentRed, size: 20)
                  : null,
            helperText: widget.userId.text.isNotEmpty && widget.userId.text.length < 6
              ? 'Minimum 6 characters required'
              : null,
            helperColor: widget.userId.text.isNotEmpty && widget.userId.text.length < 6
              ? DesignTokens.accentRed
              : null,
          ),

          const SizedBox(height: 24),

          _TextFieldCard(
            label: 'Email',
            controller: widget.email,
            hint: 'your.email@example.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (widget.email.text == value) {
                  widget.onEmailChanged(value);
                }
              });
            },
            suffix: widget.isCheckingEmail
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : widget.emailValidationStatus == 'valid'
                ? Icon(Icons.check_circle, color: DesignTokens.accentGreen, size: 20)
                : widget.emailValidationStatus == 'taken'
                  ? Icon(Icons.cancel, color: DesignTokens.accentRed, size: 20)
                  : widget.emailValidationStatus == 'invalid'
                    ? Icon(Icons.error_outline, color: DesignTokens.accentRed, size: 20)
                    : null,
            helperText: widget.emailValidationStatus == 'invalid'
              ? 'Invalid email'
              : widget.emailValidationStatus == 'taken'
                ? 'Already used'
                : null,
            helperColor: widget.emailValidationStatus == 'invalid' || widget.emailValidationStatus == 'taken'
              ? DesignTokens.accentRed
              : null,
          ),

          const SizedBox(height: 24),

          _TextFieldCard(
            label: 'Password',
            controller: widget.pass,
            hint: 'Create a strong password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePass,
            onChanged: (value) {
              setState(() {
                // Trigger rebuild to update password validation chips
              });
            },
            suffix: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
              color: textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),

          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PasswordChip(
                label: 'A-Z',
                isValid: RegExp(r'[A-Z]').hasMatch(pass),
              ),
              _PasswordChip(
                label: 'a-z',
                isValid: RegExp(r'[a-z]').hasMatch(pass),
              ),
              _PasswordChip(
                label: '0-9',
                isValid: RegExp(r'[0-9]').hasMatch(pass),
              ),
              _PasswordChip(
                label: '!@#',
                isValid: RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass),
              ),
              _PasswordChip(
                label: '8+',
                isValid: pass.length >= 8,
              ),
            ],
          ),

          const SizedBox(height: 20),

          _TextFieldCard(
            label: 'Confirm Password',
            controller: widget.confirmPass,
            hint: 'Re-enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPass,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              color: textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            helperText: widget.confirmPass.text.isEmpty
              ? null
              : passwordsMatch
                ? 'Passwords match'
                : 'Passwords do not match',
            helperColor: passwordsMatch ? DesignTokens.accentGreen : DesignTokens.accentRed,
          ),
        ],
      ),
    );
  }
}

// Step 2: Personal Info
class _Step2Content extends StatelessWidget {
  final TextEditingController first;
  final TextEditingController last;
  final TextEditingController phone;
  final String phoneCountryCode;
  final ValueChanged<String> onPhoneCountryCodeChanged;

  const _Step2Content({
    required this.first,
    required this.last,
    required this.phone,
    required this.phoneCountryCode,
    required this.onPhoneCountryCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _TextFieldCard(
            label: 'First Name',
            controller: first,
            hint: 'Enter your first name',
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 24),

          _TextFieldCard(
            label: 'Last Name',
            controller: last,
            hint: 'Enter your last name',
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 24),

          _TextFieldCard(
            label: 'Phone Number',
            controller: phone,
            hint: 'Enter your phone number',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    phoneCountryCode,
                    style: TextStyle(
                      color: DesignTokens.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: DesignTokens.borderColorOf(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Step 3: DOB & Gender
class _Step3Content extends StatelessWidget {
  final DateTime dob;
  final String gender;
  final ValueChanged<DateTime> onDobChanged;
  final ValueChanged<String> onGenderChanged;

  const _Step3Content({
    required this.dob,
    required this.gender,
    required this.onDobChanged,
    required this.onGenderChanged,
  });

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    
    if (months < 0) {
      years--;
      months += 12;
    }
    
    if (now.day < birthDate.day) {
      months--;
      if (months < 0) {
        years--;
        months += 12;
      }
    }
    
    if (years == 0) {
      return '$months ${months == 1 ? 'month' : 'months'}';
    } else if (months == 0) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    } else {
      return '$years ${years == 1 ? 'year' : 'years'} $months ${months == 1 ? 'month' : 'months'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final ageText = _calculateAge(dob);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.15, 0.85, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: DesignTokens.accentOrange,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: _CustomDatePicker(
                  initialDate: dob,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(1900),
                  onDateChanged: onDobChanged,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
              ).createShader(bounds),
              child: Text(
                'Age: $ageText',
                style: TextStyle(
                  color: Colors.white, // This will be masked by the gradient
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Gender',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _GenderOption(
                  symbol: '♂',
                  name: 'Male',
                  isSelected: gender == 'Male',
                  onTap: () => onGenderChanged('Male'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _GenderOption(
                  symbol: '♀',
                  name: 'Female',
                  isSelected: gender == 'Female',
                  onTap: () => onGenderChanged('Female'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _GenderOption(
                  symbol: '⚧',
                  name: 'Other',
                  isSelected: gender == 'Other',
                  onTap: () => onGenderChanged('Other'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Step 4: Height & Weight
class _Step4Content extends StatefulWidget {
  final bool heightInCm;
  final bool weightInKg;
  final double heightCm;
  final int feet;
  final int inch;
  final double weightKg;
  final double weightLbs;
  final ValueChanged<bool> onToggleHeightUnit;
  final ValueChanged<bool> onToggleWeightUnit;
  final ValueChanged<double> onHeightCm;
  final ValueChanged<int> onFeet;
  final ValueChanged<int> onInch;
  final ValueChanged<double> onWeightKg;
  final ValueChanged<double> onWeightLbs;

  const _Step4Content({
    required this.heightInCm,
    required this.weightInKg,
    required this.heightCm,
    required this.feet,
    required this.inch,
    required this.weightKg,
    required this.weightLbs,
    required this.onToggleHeightUnit,
    required this.onToggleWeightUnit,
    required this.onHeightCm,
    required this.onFeet,
    required this.onInch,
    required this.onWeightKg,
    required this.onWeightLbs,
  });

  @override
  State<_Step4Content> createState() => _Step4ContentState();
}

class _Step4ContentState extends State<_Step4Content> {
  late FixedExtentScrollController _heightCmController;
  late FixedExtentScrollController _feetController;
  late FixedExtentScrollController _inchController;
  late FixedExtentScrollController _weightKgController;
  late FixedExtentScrollController _weightLbsController;
  
  late int _selectedWeightKgIndex;
  late int _selectedWeightLbsIndex;

  @override
  void initState() {
    super.initState();
    _heightCmController = FixedExtentScrollController(
      initialItem: (widget.heightCm - 80).round().clamp(0, 150),
    );
    _feetController = FixedExtentScrollController(
      initialItem: (widget.feet - 3).clamp(0, 5),
    );
    _inchController = FixedExtentScrollController(
      initialItem: widget.inch.clamp(0, 11),
    );
    _selectedWeightKgIndex = ((widget.weightKg - 35) / 0.1).round().clamp(0, 1150);
    _weightKgController = FixedExtentScrollController(
      initialItem: _selectedWeightKgIndex,
    );
    _selectedWeightLbsIndex = ((widget.weightLbs - 77) / 0.1).round().clamp(0, 2530);
    _weightLbsController = FixedExtentScrollController(
      initialItem: _selectedWeightLbsIndex,
    );
  }

  @override
  void dispose() {
    _heightCmController.dispose();
    _feetController.dispose();
    _inchController.dispose();
    _weightKgController.dispose();
    _weightLbsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Height
          Row(
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                    ).createShader(bounds),
                    child: Icon(
                      Icons.height,
                      size: 18,
                      color: Colors.white, // This will be masked by the gradient
                    ),
                  ),
                  const SizedBox(width: 6),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                    ).createShader(bounds),
                    child: Text(
                      'Height',
                      style: TextStyle(
                        color: Colors.white, // This will be masked by the gradient
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _UnitToggle(
                left: 'cm',
                right: 'ft/in',
                isLeft: widget.heightInCm,
                onChanged: widget.onToggleHeightUnit,
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 200,
            child: widget.heightInCm
              ? ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.15, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      primaryColor: DesignTokens.accentOrange,
                      textTheme: CupertinoTextThemeData(
                        pickerTextStyle: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: _LoopingPicker(
                      scrollController: _heightCmController,
                      itemExtent: 50,
                      itemCount: 151,
                      initialIndex: (widget.heightCm - 80).round().clamp(0, 150),
                      onSelectedItemChanged: (index) {
                        HapticFeedback.selectionClick();
                        final newHeightCm = (80 + (index % 151)).toDouble();
                        widget.onHeightCm(newHeightCm);
                        final totalInches = (newHeightCm / 2.54).round();
                        final feet = (totalInches / 12).floor().clamp(3, 8);
                        final inches = (totalInches % 12).clamp(0, 11);
                        widget.onFeet(feet);
                        widget.onInch(inches);
                      },
                      builder: (context, index) {
                        final value = 80 + (index % 151);
                        final isSelected = value == widget.heightCm.round();
                        return Center(
                          child: isSelected
                            ? ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                                ).createShader(bounds),
                                child: Text(
                                  '$value cm',
                                  style: TextStyle(
                                    color: Colors.white, // This will be masked by the gradient
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Text(
                                '$value cm',
                                style: TextStyle(
                                  color: textPrimary.withOpacity(0.8),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.15, 0.85, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            brightness: Theme.of(context).brightness,
                            primaryColor: DesignTokens.accentOrange,
                            textTheme: CupertinoTextThemeData(
                              pickerTextStyle: TextStyle(
                                color: textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          child: _LoopingPicker(
                            scrollController: _feetController,
                            itemExtent: 50,
                            itemCount: 6,
                            initialIndex: (widget.feet - 3).clamp(0, 5),
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              widget.onFeet(3 + (index % 6));
                            },
                            builder: (context, index) {
                              final value = 3 + (index % 6);
                              final isSelected = value == widget.feet;
                              return Center(
                                child: isSelected
                                  ? ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                                      ).createShader(bounds),
                                      child: Text(
                                        '$value ft',
                                        style: TextStyle(
                                          color: Colors.white, // This will be masked by the gradient
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '$value ft',
                                      style: TextStyle(
                                        color: textPrimary.withOpacity(0.8),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.15, 0.85, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            brightness: Theme.of(context).brightness,
                            primaryColor: DesignTokens.accentOrange,
                            textTheme: CupertinoTextThemeData(
                              pickerTextStyle: TextStyle(
                                color: textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          child: _LoopingPicker(
                            scrollController: _inchController,
                            itemExtent: 50,
                            itemCount: 12,
                            initialIndex: widget.inch.clamp(0, 11),
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              widget.onInch(index % 12);
                            },
                            builder: (context, index) {
                              final value = index % 12;
                              final isSelected = value == widget.inch;
                              return Center(
                                child: isSelected
                                  ? ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                                      ).createShader(bounds),
                                      child: Text(
                                        '$value in',
                                        style: TextStyle(
                                          color: Colors.white, // This will be masked by the gradient
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '$value in',
                                      style: TextStyle(
                                        color: textPrimary.withOpacity(0.8),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),

          const SizedBox(height: 36),

          // Weight
          Row(
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                    ).createShader(bounds),
                    child: Icon(
                      Icons.monitor_weight,
                      size: 18,
                      color: Colors.white, // This will be masked by the gradient
                    ),
                  ),
                  const SizedBox(width: 6),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                    ).createShader(bounds),
                    child: Text(
                      'Weight',
                      style: TextStyle(
                        color: Colors.white, // This will be masked by the gradient
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _UnitToggle(
                left: 'kg',
                right: 'lbs',
                isLeft: widget.weightInKg,
                onChanged: widget.onToggleWeightUnit,
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 200,
            child: widget.weightInKg
              ? ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.15, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      primaryColor: DesignTokens.accentOrange,
                      textTheme: CupertinoTextThemeData(
                        pickerTextStyle: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: _LoopingPicker(
                      scrollController: _weightKgController,
                      itemExtent: 50,
                      itemCount: 1151,
                      initialIndex: _selectedWeightKgIndex,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedWeightKgIndex = index % 1151;
                        });
                        HapticFeedback.selectionClick();
                        final newWeightKg = (35 + (index % 1151) * 0.1).roundToDouble();
                        widget.onWeightKg(newWeightKg);
                        final lbsValue = (newWeightKg * 2.20462).round().toDouble();
                        widget.onWeightLbs(lbsValue);
                      },
                      builder: (context, index) {
                        final actualIndex = index % 1151;
                        final value = (35 + actualIndex * 0.1).toStringAsFixed(1);
                        final isSelected = actualIndex == _selectedWeightKgIndex;
                        return Center(
                          child: isSelected
                            ? ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                                ).createShader(bounds),
                                child: Text(
                                  '$value kg',
                                  style: TextStyle(
                                    color: Colors.white, // This will be masked by the gradient
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Text(
                                '$value kg',
                                style: TextStyle(
                                  color: textPrimary.withOpacity(0.8),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                )
              : ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.15, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      primaryColor: DesignTokens.accentOrange,
                      textTheme: CupertinoTextThemeData(
                        pickerTextStyle: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: _LoopingPicker(
                    scrollController: _weightLbsController,
                    itemExtent: 50,
                    itemCount: 2531,
                    initialIndex: _selectedWeightLbsIndex,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedWeightLbsIndex = index % 2531;
                      });
                      HapticFeedback.selectionClick();
                      final newWeightLbs = (77 + (index % 2531) * 0.1).roundToDouble();
                      widget.onWeightLbs(newWeightLbs);
                      final kgValue = (newWeightLbs * 0.453592).roundToDouble();
                      widget.onWeightKg(kgValue);
                    },
                    builder: (context, index) {
                      final actualIndex = index % 2531;
                      final value = (77 + actualIndex * 0.1).toStringAsFixed(1);
                      final isSelected = actualIndex == _selectedWeightLbsIndex;
                      return Center(
                        child: isSelected
                          ? ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                              ).createShader(bounds),
                              child: Text(
                                '$value lbs',
                                style: TextStyle(
                                  color: Colors.white, // This will be masked by the gradient
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Text(
                              '$value lbs',
                              style: TextStyle(
                                color: textPrimary.withOpacity(0.8),
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      );
                    },
                  ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// Step 5: Goals & Role
class _Step5Content extends StatefulWidget {
  final List<String> goals;
  final Set<String> selected;
  final String role;
  final ValueChanged<String> onToggleGoal;
  final ValueChanged<String> onRoleChanged;

  const _Step5Content({
    required this.goals,
    required this.selected,
    required this.role,
    required this.onToggleGoal,
    required this.onRoleChanged,
  });

  @override
  State<_Step5Content> createState() => _Step5ContentState();
}

class _Step5ContentState extends State<_Step5Content> {
  late FixedExtentScrollController _roleController;

  @override
  void initState() {
    super.initState();
    final roles = ['Client', 'Trainer', 'Nutritionist'];
    final initialIndex = roles.indexOf(widget.role);
    _roleController = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Categories',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.goals.map((goal) {
              final isSelected = widget.selected.contains(goal);
              return _GoalChip(
                label: goal,
                isSelected: isSelected,
                onTap: () => widget.onToggleGoal(goal),
              );
            }).toList(),
          ),

          const SizedBox(height: 36),

          Text(
            'Role',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 180,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.15, 0.85, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: DesignTokens.accentOrange,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      color: DesignTokens.textPrimaryOf(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: _LoopingPicker(
                  scrollController: _roleController,
                  itemExtent: 50,
                  itemCount: 3,
                  initialIndex: ['Client', 'Trainer', 'Nutritionist'].indexOf(widget.role).clamp(0, 2),
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    final roles = ['Client', 'Trainer', 'Nutritionist'];
                    widget.onRoleChanged(roles[index]);
                  },
                  builder: (context, index) {
                    final roles = ['Client', 'Trainer', 'Nutritionist'];
                    final role = roles[index % 3];
                    final isSelected = role == widget.role;
                    final textPrimary = DesignTokens.textPrimaryOf(context);
                    return Center(
                      child: isSelected
                        ? ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                            ).createShader(bounds),
                            child: Text(
                              role,
                              style: TextStyle(
                                color: Colors.white, // This will be masked by the gradient
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Text(
                            role,
                            style: TextStyle(
                              color: textPrimary.withOpacity(0.8),
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Reusable Components
class _TextFieldCard extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? helperText;
  final Color? helperColor;

  const _TextFieldCard({
    required this.label,
    required this.controller,
    this.hint,
    required this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.helperText,
    this.helperColor,
  });

  @override
  State<_TextFieldCard> createState() => _TextFieldCardState();
}

class _TextFieldCardState extends State<_TextFieldCard> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use exact same structure as login page - Material handles gap automatically
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onChanged: (value) {
            if (widget.onChanged != null) {
              widget.onChanged!(value);
            }
            setState(() {}); // Trigger rebuild for label animation
          },
          style: TextStyle(
            color: textPrimary,
            fontWeight: DesignTokens.fontWeightMedium,
            fontSize: DesignTokens.fontSizeBody,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle: TextStyle(
              color: textSecondary,
              fontWeight: DesignTokens.fontWeightRegular,
            ),
            prefixIcon: widget.prefix != null
              ? null
              : Icon(widget.prefixIcon, color: textSecondary, size: 20),
            prefix: widget.prefix,
            suffixIcon: widget.suffix,
            filled: true,
            fillColor: surfaceColor,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              borderSide: const BorderSide(
                color: DesignTokens.accentOrange,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing16,
              vertical: DesignTokens.spacing16,
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: TextStyle(
              color: widget.helperColor ?? textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _PasswordChip extends StatelessWidget {
  final String label;
  final bool isValid;

  const _PasswordChip({
    required this.label,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isValid ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isValid
            ? DesignTokens.accentGreen.withOpacity(0.15)
            : DesignTokens.surfaceOf(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isValid
              ? DesignTokens.accentGreen
              : DesignTokens.borderColorOf(context),
            width: isValid ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                isValid ? Icons.check_circle : Icons.close,
                key: ValueKey(isValid),
                size: 14,
                color: isValid
                  ? DesignTokens.accentGreen
                  : DesignTokens.textSecondaryOf(context),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isValid ? FontWeight.w600 : FontWeight.w500,
                color: isValid
                  ? DesignTokens.accentGreen
                  : DesignTokens.textSecondaryOf(context),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String symbol;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.symbol,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final symbolColor = isDarkMode ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
            ? DesignTokens.accentOrange.withOpacity(0.15)
            : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
              ? DesignTokens.accentOrange
              : borderColor,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Symbol - always white/black, gradient when selected
            isSelected
              ? ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                  ).createShader(bounds),
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: Colors.white, // This will be masked by the gradient
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    symbolColor,
                    BlendMode.srcIn,
                  ),
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: symbolColor, // White in dark mode, black in light mode
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            // Name label
            Text(
              name,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _UnitToggle({
    required this.left,
    required this.right,
    required this.isLeft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);

    return SizedBox(
      width: 100, // Fixed width to ensure both toggles are same size
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isLeft
                      ? const LinearGradient(
                          colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                        )
                      : null,
                    color: isLeft ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                  ),
                  child: Center(
                    child: Text(
                      left,
                      style: TextStyle(
                        color: isLeft ? Colors.white : textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: !isLeft
                      ? const LinearGradient(
                          colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                        )
                      : null,
                    color: !isLeft ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                  ),
                  child: Center(
                    child: Text(
                      right,
                      style: TextStyle(
                        color: !isLeft ? Colors.white : textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
            ? DesignTokens.primaryGradient
            : null,
          color: isSelected
            ? null
            : DesignTokens.surfaceOf(context),
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          border: Border.all(
            color: isSelected
              ? Colors.transparent
              : DesignTokens.borderColorOf(context),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
              ? Colors.white
              : DesignTokens.textPrimaryOf(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CustomDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime maximumDate;
  final DateTime minimumDate;
  final ValueChanged<DateTime> onDateChanged;

  const _CustomDatePicker({
    required this.initialDate,
    required this.maximumDate,
    required this.minimumDate,
    required this.onDateChanged,
  });

  @override
  State<_CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<_CustomDatePicker> {
  late int selectedDay;
  late int selectedMonth;
  late int selectedYear;
  
  final List<String> shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    selectedDay = widget.initialDate.day;
    selectedMonth = widget.initialDate.month - 1;
    selectedYear = widget.initialDate.year;
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _updateDate() {
    final daysInMonth = _getDaysInMonth(selectedYear, selectedMonth);
    if (selectedDay > daysInMonth) {
      selectedDay = daysInMonth;
    }
    final newDate = DateTime(selectedYear, selectedMonth + 1, selectedDay);
    if (newDate.isBefore(widget.minimumDate)) {
      widget.onDateChanged(widget.minimumDate);
    } else if (newDate.isAfter(widget.maximumDate)) {
      widget.onDateChanged(widget.maximumDate);
    } else {
      widget.onDateChanged(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final minYear = widget.minimumDate.year;
    final maxYear = widget.maximumDate.year;
    
    final daysInMonth = _getDaysInMonth(selectedYear, selectedMonth);
    final days = List.generate(daysInMonth, (i) => i + 1);
    
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);

    return Row(
      children: [
        // Day picker (first)
        Expanded(
          child: _GradientPicker(
            scrollController: FixedExtentScrollController(
              initialItem: selectedDay > daysInMonth ? daysInMonth - 1 : selectedDay - 1
            ),
            itemExtent: 40,
            selectedIndex: selectedDay > daysInMonth ? daysInMonth - 1 : selectedDay - 1,
            onSelectedItemChanged: (index) {
              setState(() {
                selectedDay = days[index];
                _updateDate();
              });
            },
            children: days.map((day) {
              return day.toString();
            }).toList(),
          ),
        ),
        // Month picker (second)
        Expanded(
          child: _GradientPicker(
            scrollController: FixedExtentScrollController(initialItem: selectedMonth),
            itemExtent: 40,
            selectedIndex: selectedMonth,
            onSelectedItemChanged: (index) {
              setState(() {
                selectedMonth = index;
                _updateDate();
              });
            },
            children: shortMonths.map((month) {
              return month;
            }).toList(),
          ),
        ),
        // Year picker (third)
        Expanded(
          child: _GradientPicker(
            scrollController: FixedExtentScrollController(
              initialItem: selectedYear - minYear
            ),
            itemExtent: 40,
            selectedIndex: selectedYear - minYear,
            onSelectedItemChanged: (index) {
              setState(() {
                selectedYear = years[index];
                _updateDate();
              });
            },
            children: years.map((year) {
              return year.toString();
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _GradientPicker extends StatefulWidget {
  final FixedExtentScrollController scrollController;
  final double itemExtent;
  final int selectedIndex;
  final ValueChanged<int> onSelectedItemChanged;
  final List<String> children;

  const _GradientPicker({
    required this.scrollController,
    required this.itemExtent,
    required this.selectedIndex,
    required this.onSelectedItemChanged,
    required this.children,
  });

  @override
  State<_GradientPicker> createState() => _GradientPickerState();
}

class _GradientPickerState extends State<_GradientPicker> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(_GradientPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _currentIndex = widget.selectedIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);

    return CupertinoPicker(
      scrollController: widget.scrollController,
      itemExtent: widget.itemExtent,
      onSelectedItemChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
        widget.onSelectedItemChanged(index);
      },
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;
        final isSelected = index == _currentIndex;

        return Center(
          child: isSelected
            ? ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                ).createShader(bounds),
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white, // This will be masked by the gradient
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: textPrimary.withOpacity(0.5),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
        );
      }).toList(),
    );
  }
}

class _LoopingPicker extends StatefulWidget {
  final FixedExtentScrollController scrollController;
  final double itemExtent;
  final int itemCount;
  final int initialIndex;
  final ValueChanged<int> onSelectedItemChanged;
  final Widget Function(BuildContext, int) builder;

  const _LoopingPicker({
    required this.scrollController,
    required this.itemExtent,
    required this.itemCount,
    required this.initialIndex,
    required this.onSelectedItemChanged,
    required this.builder,
  });

  @override
  State<_LoopingPicker> createState() => _LoopingPickerState();
}

class _LoopingPickerState extends State<_LoopingPicker> {
  static const int _multiplier = 20; // Reduced multiplier for better performance
  late FixedExtentScrollController _controller;
  int _lastSelectedIndex = 0;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    final middleIndex = (widget.itemCount * _multiplier / 2).round() + widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: middleIndex);
    _lastSelectedIndex = middleIndex;
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || _isJumping) return;
    
    final currentIndex = _controller.selectedItem;
    final actualIndex = currentIndex % widget.itemCount;
    
    if (currentIndex != _lastSelectedIndex) {
      widget.onSelectedItemChanged(actualIndex);
      _lastSelectedIndex = currentIndex;
    }

    // Reset to middle when near edges for continuous looping
    final threshold = widget.itemCount * 2;
    if (currentIndex < threshold) {
      // Near the beginning, jump to middle
      _isJumping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients && mounted) {
          final newIndex = (widget.itemCount * _multiplier / 2).round() + actualIndex;
          _controller.jumpToItem(newIndex);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _isJumping = false;
          });
        }
      });
    } else if (currentIndex > widget.itemCount * (_multiplier - 2)) {
      // Near the end, jump to middle
      _isJumping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients && mounted) {
          final newIndex = (widget.itemCount * _multiplier / 2).round() + actualIndex;
          _controller.jumpToItem(newIndex);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _isJumping = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = widget.itemCount * _multiplier;
    
    return CupertinoPicker(
      scrollController: _controller,
      itemExtent: widget.itemExtent,
      onSelectedItemChanged: (index) {
        if (!_isJumping) {
          final actualIndex = index % widget.itemCount;
          widget.onSelectedItemChanged(actualIndex);
        }
      },
      children: List.generate(totalItems, (index) {
        return widget.builder(context, index);
      }),
    );
  }
}

