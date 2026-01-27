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
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    _stepTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _isCheckingUserId = false;
        _userIdAvailabilityStatus = response == null ? 'available' : 'taken';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingUserId = false;
        _userIdAvailabilityStatus = 'available';
      });
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    
    if (_step == 0 && !_validateStep1()) {
      return;
    }
    
    if (_step < 4) {
      // Animate step transition
      _stepTransitionController.reset();
      setState(() => _step++);
      _page.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _stepTransitionController.forward();
    } else {
      _submit();
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _page.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
        context.go('/home');
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

  Color _getStepColor(int step) {
    // Different color for each step
    switch (step) {
      case 0:
        return DesignTokens.accentOrange; // Step 1: Orange
      case 1:
        return DesignTokens.accentBlue; // Step 2: Blue
      case 2:
        return DesignTokens.accentPurple; // Step 3: Purple
      case 3:
        return DesignTokens.accentGreen; // Step 4: Green
      case 4:
        return DesignTokens.accentAmber; // Step 5: Amber
      default:
        return DesignTokens.accentOrange;
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Account Setup';
      case 1:
        return 'Personal Information';
      case 2:
        return 'DOB & Gender';
      case 3:
        return 'Height & Weight';
      case 4:
        return 'Goals & Role';
      default:
        return 'Account Setup';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0:
        return 'Create your unique user ID and secure password';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'Help us with your Age and Gender';
      case 3:
        return 'Select your measurements';
      case 4:
        return 'Choose your fitness goals and role';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = DesignTokens.backgroundOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            children: [
              // Header with back arrow and heading - Transparent
              Container(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing24,
                    vertical: DesignTokens.spacing8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _back,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: DesignTokens.textPrimaryOf(context),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStepTitle(_step),
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeH2,
                                fontWeight: DesignTokens.fontWeightBold,
                                color: DesignTokens.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getStepSubtitle(_step),
                              style: TextStyle(
                                color: DesignTokens.textSecondaryOf(context),
                                fontSize: DesignTokens.fontSizeMeta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing12),
              
              // Segmented Progress Bar - No background
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing24,
                ),
                child: Row(
                  children: List.generate(5, (index) {
                    final isCompleted = index < _step;
                    final isCurrent = index == _step;
                    
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index < 4 ? 4 : 0,
                        ),
                        decoration: BoxDecoration(
                          gradient: (isCompleted || isCurrent)
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD93D), // Yellow
                                    Color(0xFFFF8A00), // Orange
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: (isCompleted || isCurrent)
                              ? null
                              : DesignTokens.borderColorOf(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              // Content - Scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: PageView(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Step1(
                          userId: _userId,
                          email: _email,
                          pass: _pass,
                          confirmPass: _confirmPass,
                          userIdAvailabilityStatus: _userIdAvailabilityStatus,
                          isCheckingUserId: _isCheckingUserId,
                          onUserIdChanged: _checkUserIdAvailability,
                        ),
                        _Step2(
                          first: _first,
                          last: _last,
                          phone: _phone,
                        ),
                        _Step3(
                          dob: _dob,
                          gender: _gender,
                          onDobChanged: (d) {
                            HapticFeedback.selectionClick();
                            setState(() => _dob = d);
                          },
                          onGender: (g) {
                            HapticFeedback.selectionClick();
                            setState(() => _gender = g);
                          },
                        ),
                        _Step4(
                          heightInCm: _heightInCm,
                          weightInKg: _weightInKg,
                          heightCm: _heightCm,
                          feet: _feet,
                          inch: _inch,
                          weightKg: _weightKg,
                          weightLbs: _weightLbs,
                          bmi: _bmi,
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
                        _Step5(
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
                          onRole: (r) {
                            HapticFeedback.selectionClick();
                            setState(() => _role = r);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Next/Submit Button - Fixed at bottom - Transparent
              Container(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spacing24),
                  child: _NextButton(
                    text: _step == 4 ? 'Create Account' : 'Next',
                    onTap: _isSubmitting ? null : _next,
                    isLoading: _isSubmitting,
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
class _Step1 extends StatefulWidget {
  final TextEditingController userId;
  final TextEditingController email;
  final TextEditingController pass;
  final TextEditingController confirmPass;
  final String? userIdAvailabilityStatus;
  final bool isCheckingUserId;
  final ValueChanged<String> onUserIdChanged;

  const _Step1({
    required this.userId,
    required this.email,
    required this.pass,
    required this.confirmPass,
    required this.userIdAvailabilityStatus,
    required this.isCheckingUserId,
    required this.onUserIdChanged,
  });

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  bool _isValidPassword(String password) {
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
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final pass = widget.pass.text;
    final hasValidPassword = pass.isNotEmpty && _isValidPassword(pass);
    final passwordsMatch = widget.pass.text == widget.confirmPass.text && widget.confirmPass.text.isNotEmpty;

    return _StepShell(
      subtitle: '',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User ID
          TextFormField(
            controller: widget.userId,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  text: newValue.text.toLowerCase(),
                  selection: newValue.selection,
                );
              }),
            ],
            onChanged: (value) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (widget.userId.text == value) {
                  widget.onUserIdChanged(value);
                }
              });
            },
            style: TextStyle(
              color: textPrimary,
              fontWeight: DesignTokens.fontWeightMedium,
              fontSize: DesignTokens.fontSizeBody,
            ),
            decoration: InputDecoration(
              labelText: 'User ID',
              hintText: 'lowercase, numbers, _ only',
              prefixIcon: Icon(Icons.alternate_email, color: textSecondary, size: 20),
              suffixIcon: widget.isCheckingUserId
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.accentOrange),
                        ),
                      ),
                    )
                  : widget.userIdAvailabilityStatus == 'available'
                      ? Icon(Icons.check_circle, color: DesignTokens.accentGreen, size: 20)
                      : widget.userIdAvailabilityStatus == 'taken'
                          ? Icon(Icons.cancel, color: DesignTokens.accentRed, size: 20)
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
                borderSide: const BorderSide(color: DesignTokens.accentOrange, width: 2),
              ),
              helperText: widget.userIdAvailabilityStatus == 'available'
                  ? 'User ID is available'
                  : widget.userIdAvailabilityStatus == 'taken'
                      ? 'User ID is already taken'
                      : widget.userIdAvailabilityStatus == 'checking'
                          ? 'Checking availability...'
                          : 'Only lowercase letters, numbers, and underscore',
              helperStyle: TextStyle(
                color: widget.userIdAvailabilityStatus == 'available'
                    ? DesignTokens.accentGreen
                    : widget.userIdAvailabilityStatus == 'taken'
                        ? DesignTokens.accentRed
                        : textSecondary,
                fontSize: DesignTokens.fontSizeMeta,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          
          // Email
          _CleanField(
            label: 'Email',
            controller: widget.email,
            keyboardType: TextInputType.emailAddress,
            prefix: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          
          // Password
          TextFormField(
            controller: widget.pass,
            obscureText: _obscurePass,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: textPrimary,
              fontWeight: DesignTokens.fontWeightMedium,
              fontSize: DesignTokens.fontSizeBody,
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: textSecondary, size: 20),
              suffixIcon: IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _obscurePass = !_obscurePass);
                },
                icon: Icon(
                  _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: textSecondary,
                  size: 20,
                ),
              ),
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
                borderSide: const BorderSide(color: DesignTokens.accentOrange, width: 2),
              ),
              helperText: pass.isEmpty
                  ? 'Must have: 1 uppercase, 1 lowercase, 1 number, 1 special'
                  : hasValidPassword
                      ? 'Password is valid'
                      : 'Missing: ${!RegExp(r'[A-Z]').hasMatch(pass) ? "uppercase " : ""}${!RegExp(r'[a-z]').hasMatch(pass) ? "lowercase " : ""}${!RegExp(r'[0-9]').hasMatch(pass) ? "number " : ""}${!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass) ? "special char" : ""}',
              helperStyle: TextStyle(
                color: hasValidPassword ? DesignTokens.accentGreen : DesignTokens.accentRed,
                fontSize: DesignTokens.fontSizeMeta,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          
          // Confirm Password
          TextFormField(
            controller: widget.confirmPass,
            obscureText: _obscureConfirmPass,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: textPrimary,
              fontWeight: DesignTokens.fontWeightMedium,
              fontSize: DesignTokens.fontSizeBody,
            ),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: textSecondary, size: 20),
              suffixIcon: IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _obscureConfirmPass = !_obscureConfirmPass);
                },
                icon: Icon(
                  _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: textSecondary,
                  size: 20,
                ),
              ),
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
                borderSide: const BorderSide(color: DesignTokens.accentOrange, width: 2),
              ),
              helperText: widget.confirmPass.text.isEmpty
                  ? 'Re-enter your password'
                  : passwordsMatch
                      ? 'Passwords match'
                      : 'Passwords do not match',
              helperStyle: TextStyle(
                color: passwordsMatch ? DesignTokens.accentGreen : DesignTokens.accentRed,
                fontSize: DesignTokens.fontSizeMeta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Step 2: Profile
class _Step2 extends StatefulWidget {
  final TextEditingController first;
  final TextEditingController last;
  final TextEditingController phone;

  const _Step2({
    required this.first,
    required this.last,
    required this.phone,
  });

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      subtitle: '',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First name - full width
          _CleanField(
            label: 'First name',
            controller: widget.first,
            prefix: Icons.person_outline_rounded,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          // Last name - full width
          _CleanField(
            label: 'Last name',
            controller: widget.last,
            prefix: Icons.person_outline_rounded,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          // Phone with fixed country code
          Row(
            children: [
              // Fixed country code box
              Container(
                width: 60,
                height: 56,
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DesignTokens.borderColorOf(context),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+91',
                    style: TextStyle(
                      color: DesignTokens.textPrimaryOf(context),
                      fontWeight: DesignTokens.fontWeightSemiBold,
                      fontSize: DesignTokens.fontSizeBody,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              // Phone number field - Big
              Expanded(
                child: TextFormField(
                  controller: widget.phone,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: DesignTokens.textPrimaryOf(context),
                    fontWeight: DesignTokens.fontWeightMedium,
                    fontSize: DesignTokens.fontSizeBody,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: DesignTokens.textSecondaryOf(context),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: DesignTokens.surfaceOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: DesignTokens.borderColorOf(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: DesignTokens.borderColorOf(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: DesignTokens.accentOrange,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing16,
                      vertical: DesignTokens.spacing16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Step 3: DOB and Gender
class _Step3 extends StatelessWidget {
  final DateTime dob;
  final String gender;
  final ValueChanged<DateTime> onDobChanged;
  final ValueChanged<String> onGender;

  const _Step3({
    required this.dob,
    required this.gender,
    required this.onDobChanged,
    required this.onGender,
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
    final ageText = _calculateAge(dob);
    
    return _StepShell(
      subtitle: '',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modern DOB picker with blur effect - Bigger
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DesignTokens.borderColorOf(context),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Blur effect overlay
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        color: DesignTokens.surfaceOf(context).withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  // Date picker with short month names and gradient selected text
                  _DatePickerWithShortMonths(
                    initialDateTime: dob,
                    onDateTimeChanged: onDobChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          // Age display
          Text(
            'Age: $ageText',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: DesignTokens.fontSizeBody,
              fontWeight: DesignTokens.fontWeightMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing32),
          // Gender selection with swiping effect - center active, sides with opacity
          _SwipeableGenderSelector(
            selectedGender: gender,
            onGenderSelected: onGender,
          ),
        ],
      ),
    );
  }
}

// Step 4: Height and Weight
class _Step4 extends StatefulWidget {
  final bool heightInCm;
  final bool weightInKg;
  final double heightCm;
  final int feet;
  final int inch;
  final double weightKg;
  final double weightLbs;
  final double bmi;
  final ValueChanged<bool> onToggleHeightUnit;
  final ValueChanged<bool> onToggleWeightUnit;
  final ValueChanged<double> onHeightCm;
  final ValueChanged<int> onFeet;
  final ValueChanged<int> onInch;
  final ValueChanged<double> onWeightKg;
  final ValueChanged<double> onWeightLbs;

  const _Step4({
    required this.heightInCm,
    required this.weightInKg,
    required this.heightCm,
    required this.feet,
    required this.inch,
    required this.weightKg,
    required this.weightLbs,
    required this.bmi,
    required this.onToggleHeightUnit,
    required this.onToggleWeightUnit,
    required this.onHeightCm,
    required this.onFeet,
    required this.onInch,
    required this.onWeightKg,
    required this.onWeightLbs,
  });

  @override
  State<_Step4> createState() => _Step4State();
}

class _Step4State extends State<_Step4> {
  late FixedExtentScrollController _heightCmController;
  late FixedExtentScrollController _feetController;
  late FixedExtentScrollController _inchController;
  late FixedExtentScrollController _weightKgController;
  late FixedExtentScrollController _weightLbsController;

  @override
  void initState() {
    super.initState();
    _heightCmController = FixedExtentScrollController(initialItem: (widget.heightCm - 80).round());
    _feetController = FixedExtentScrollController(initialItem: widget.feet - 3);
    _inchController = FixedExtentScrollController(initialItem: widget.inch);
    _weightKgController = FixedExtentScrollController(initialItem: ((widget.weightKg - 20) * 2).round());
    _weightLbsController = FixedExtentScrollController(initialItem: (widget.weightLbs - 44).round());
  }

  @override
  void didUpdateWidget(_Step4 oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync height controllers
    if (oldWidget.heightCm != widget.heightCm) {
      final cmIndex = (widget.heightCm - 80).round().clamp(0, 150);
      if (_heightCmController.hasClients && _heightCmController.selectedItem != cmIndex) {
        _heightCmController.jumpToItem(cmIndex);
      }
      // Update ft/in when cm changes
      final totalInches = (widget.heightCm / 2.54).round();
      final feet = (totalInches / 12).floor().clamp(3, 8);
      final inches = (totalInches % 12).clamp(0, 11);
      if (oldWidget.feet != feet && _feetController.hasClients) {
        _feetController.jumpToItem((feet - 3).clamp(0, 5));
      }
      if (oldWidget.inch != inches && _inchController.hasClients) {
        _inchController.jumpToItem(inches.clamp(0, 11));
      }
    }
    // Sync weight controllers
    if (oldWidget.weightKg != widget.weightKg && widget.weightInKg) {
      final kgIndex = ((widget.weightKg - 20) * 2).round().clamp(0, 460);
      if (_weightKgController.hasClients && _weightKgController.selectedItem != kgIndex) {
        _weightKgController.jumpToItem(kgIndex);
      }
    }
    if (oldWidget.weightLbs != widget.weightLbs && !widget.weightInKg) {
      final lbsIndex = (widget.weightLbs - 44).round().clamp(0, 506);
      if (_weightLbsController.hasClients && _weightLbsController.selectedItem != lbsIndex) {
        _weightLbsController.jumpToItem(lbsIndex);
      }
    }
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
    final textPrimary = DesignTokens.textPrimaryOf(context);

    return _StepShell(
      subtitle: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Height section with icon and toggle
          Row(
            children: [
              Icon(
                Icons.height_rounded,
                color: DesignTokens.accentOrange,
                size: 20,
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                'Height',
                style: TextStyle(
                  color: DesignTokens.textSecondaryOf(context),
                  fontWeight: DesignTokens.fontWeightSemiBold,
                  fontSize: DesignTokens.fontSizeBody,
                ),
              ),
              const Spacer(),
              _SmallToggle(
                left: 'cm',
                right: 'ft/in',
                isLeft: widget.heightInCm,
                onChanged: widget.onToggleHeightUnit,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          AnimatedSwitcher(
            duration: DesignTokens.animationMedium,
            child: widget.heightInCm
                ? Container(
                    key: const ValueKey('cm'),
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DesignTokens.borderColorOf(context),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: Theme.of(context).brightness,
                          primaryColor: DesignTokens.accentOrange,
                          textTheme: CupertinoTextThemeData(
                            pickerTextStyle: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: DesignTokens.fontWeightSemiBold,
                            ),
                          ),
                        ),
                        child: CupertinoPicker(
                          scrollController: _heightCmController,
                          itemExtent: 50,
                          onSelectedItemChanged: (index) {
                            HapticFeedback.selectionClick();
                            final newHeightCm = (80 + index).toDouble();
                            widget.onHeightCm(newHeightCm);
                            // Auto-adjust ft/in when cm changes
                            final totalInches = (newHeightCm / 2.54).round();
                            final feet = (totalInches / 12).floor().clamp(3, 8);
                            final inches = (totalInches % 12).clamp(0, 11);
                            widget.onFeet(feet);
                            widget.onInch(inches);
                          },
                          children: List.generate(151, (index) {
                            final value = 80 + index;
                            final isSelected = value == widget.heightCm.round();
                            return Center(
                              child: _GradientPickerItem(
                                text: '$value cm',
                                isSelected: isSelected,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  )
                : Container(
                    key: const ValueKey('ftin'),
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DesignTokens.borderColorOf(context),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          // Feet rotator
                          Expanded(
                            child: CupertinoTheme(
                              data: CupertinoThemeData(
                                brightness: Theme.of(context).brightness,
                                primaryColor: DesignTokens.accentOrange,
                                textTheme: CupertinoTextThemeData(
                                  pickerTextStyle: TextStyle(
                                    color: textPrimary,
                                    fontSize: 22,
                                    fontWeight: DesignTokens.fontWeightSemiBold,
                                  ),
                                ),
                              ),
                              child: CupertinoPicker(
                                scrollController: _feetController,
                                itemExtent: 50,
                                onSelectedItemChanged: (index) {
                                  HapticFeedback.selectionClick();
                                  final feet = 3 + index;
                                  widget.onFeet(feet);
                                  // Auto-adjust cm when ft changes
                                  final totalInches = (feet * 12) + widget.inch;
                                  final heightCm = (totalInches * 2.54).round().toDouble();
                                  widget.onHeightCm(heightCm.clamp(80, 230));
                                },
                                children: List.generate(6, (index) {
                                  final value = 3 + index;
                                  final isSelected = value == widget.feet;
                                  return Center(
                                    child: _GradientPickerItem(
                                      text: '$value ft',
                                      isSelected: isSelected,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          // Inches rotator
                          Expanded(
                            child: CupertinoTheme(
                              data: CupertinoThemeData(
                                brightness: Theme.of(context).brightness,
                                primaryColor: DesignTokens.accentOrange,
                                textTheme: CupertinoTextThemeData(
                                  pickerTextStyle: TextStyle(
                                    color: textPrimary,
                                    fontSize: 22,
                                    fontWeight: DesignTokens.fontWeightSemiBold,
                                  ),
                                ),
                              ),
                              child: CupertinoPicker(
                                scrollController: _inchController,
                                itemExtent: 50,
                                onSelectedItemChanged: (index) {
                                  HapticFeedback.selectionClick();
                                  widget.onInch(index);
                                  // Auto-adjust cm when inch changes
                                  final totalInches = (widget.feet * 12) + index;
                                  final heightCm = (totalInches * 2.54).round().toDouble();
                                  if (heightCm >= 80 && heightCm <= 230) {
                                    widget.onHeightCm(heightCm);
                                    // Update the cm controller
                                    final cmIndex = (heightCm - 80).round().clamp(0, 150);
                                    if (_heightCmController.hasClients) {
                                      _heightCmController.jumpToItem(cmIndex);
                                    }
                                  }
                                },
                                children: List.generate(12, (index) {
                                  final isSelected = index == widget.inch;
                                  return Center(
                                    child: _GradientPickerItem(
                                      text: '$index in',
                                      isSelected: isSelected,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          // Weight section with icon and toggle
          Row(
            children: [
              Icon(
                Icons.monitor_weight_rounded,
                color: DesignTokens.accentOrange,
                size: 20,
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                'Weight',
                style: TextStyle(
                  color: DesignTokens.textSecondaryOf(context),
                  fontWeight: DesignTokens.fontWeightSemiBold,
                  fontSize: DesignTokens.fontSizeBody,
                ),
              ),
              const Spacer(),
              _SmallToggle(
                left: 'kg',
                right: 'lbs',
                isLeft: widget.weightInKg,
                onChanged: widget.onToggleWeightUnit,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          // Horizontal weight selector with ruler design
          AnimatedSwitcher(
            duration: DesignTokens.animationMedium,
            child: widget.weightInKg
                ? _HorizontalRulerWeightSelector(
                    value: widget.weightKg,
                    unit: 'kg',
                    min: 35,
                    max: 150,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      widget.onWeightKg(value);
                      // Auto-adjust lbs
                      final lbsValue = (value * 2.20462).round().toDouble();
                      widget.onWeightLbs(lbsValue);
                    },
                  )
                : _HorizontalRulerWeightSelector(
                    value: widget.weightLbs,
                    unit: 'lbs',
                    min: 44,
                    max: 550,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      widget.onWeightLbs(value);
                      // Auto-adjust kg
                      final kgValue = (value * 0.453592).roundToDouble();
                      widget.onWeightKg(kgValue);
                    },
                  ),
          ),
          ],
        ),
    );
  }
}

// Step 5: Goals and Role
class _Step5 extends StatelessWidget {
  final List<String> goals;
  final Set<String> selected;
  final String role;
  final ValueChanged<String> onToggleGoal;
  final ValueChanged<String> onRole;

  const _Step5({
    required this.goals,
    required this.selected,
    required this.role,
    required this.onToggleGoal,
    required this.onRole,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      subtitle: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fitness Goals',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontWeight: DesignTokens.fontWeightSemiBold,
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          // Goals dropdown selector
          _GoalsDropdown(
            goals: goals,
            selected: selected,
            onToggleGoal: onToggleGoal,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'Role',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontWeight: DesignTokens.fontWeightSemiBold,
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          // Role selector input box
          _RoleSelector(
            selectedRole: role,
            onRoleSelected: onRole,
          ),
          ],
        ),
    );
  }
}

// Shared Components
class _StepShell extends StatelessWidget {
  final String subtitle;
  final Widget child;

  const _StepShell({
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle.isNotEmpty) ...[
          Text(
            subtitle,
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: DesignTokens.fontSizeBodySmall,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing24),
        ],
        child,
      ],
    );
  }
}

class _CleanField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData prefix;

  const _CleanField({
    required this.label,
    required this.controller,
    this.keyboardType,
    required this.prefix,
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
        hintStyle: TextStyle(
          color: textSecondary,
        ),
        prefixIcon: Icon(prefix, color: textSecondary, size: 20),
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
          borderSide: const BorderSide(color: DesignTokens.accentOrange, width: 2),
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
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: DesignTokens.primaryGradient,
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

class _NextButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const _NextButton({
    required this.text,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton>
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
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: DesignTokens.primaryGradient,
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                        fontSize: DesignTokens.fontSizeBody,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Gender selector with swiping
class _GenderSelector extends StatefulWidget {
  final String selectedGender;
  final ValueChanged<String> onGenderSelected;

  const _GenderSelector({
    required this.selectedGender,
    required this.onGenderSelected,
  });

  @override
  State<_GenderSelector> createState() => _GenderSelectorState();
}

class _GenderSelectorState extends State<_GenderSelector> {
  late PageController _pageController;
  late int _currentIndex;

  final List<Map<String, dynamic>> _genders = [
    {'label': 'Male', 'icon': Icons.male_rounded},
    {'label': 'Female', 'icon': Icons.female_rounded},
    {'label': 'Other', 'icon': Icons.transgender_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _genders.indexWhere((g) => g['label'] == widget.selectedGender);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          HapticFeedback.selectionClick();
          widget.onGenderSelected(_genders[index]['label']);
        },
        itemCount: _genders.length,
        itemBuilder: (context, index) {
          final gender = _genders[index];
          final isSelected = index == _currentIndex;
          return _ModernGenderBox(
            icon: gender['icon'],
            label: gender['label'],
            selected: isSelected,
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          );
        },
      ),
    );
  }
}

class _ModernGenderBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModernGenderBox({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: DesignTokens.animationMedium,
        margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing8),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          gradient: selected ? DesignTokens.primaryGradient : null,
          color: selected ? null : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : borderColor,
            width: selected ? 0 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? Colors.white : textSecondary,
            ),
            const SizedBox(height: DesignTokens.spacing6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected
                    ? DesignTokens.fontWeightBold
                    : DesignTokens.fontWeightMedium,
                color: selected ? Colors.white : textSecondary,
                fontSize: DesignTokens.fontSizeBodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSecondary),
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.accentOrange.withValues(alpha: 0.15)
              : surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSecondary),
          border: Border.all(
            color: selected
                ? DesignTokens.accentOrange.withValues(alpha: 0.5)
                : borderColor,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: DesignTokens.fontWeightBold,
              color: selected ? textPrimary : textSecondary,
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
        ),
      ),
    );
  }
}

// Swipeable gender selector with fixed center, symbols only, looped selection
class _SwipeableGenderSelector extends StatefulWidget {
  final String selectedGender;
  final ValueChanged<String> onGenderSelected;

  const _SwipeableGenderSelector({
    required this.selectedGender,
    required this.onGenderSelected,
  });

  @override
  State<_SwipeableGenderSelector> createState() => _SwipeableGenderSelectorState();
}

class _SwipeableGenderSelectorState extends State<_SwipeableGenderSelector> {
  late PageController _pageController;
  late int _currentIndex;

  final List<Map<String, dynamic>> _genders = [
    {'label': 'Male', 'icon': Icons.male_rounded},
    {'label': 'Female', 'icon': Icons.female_rounded},
    {'label': 'Other', 'icon': Icons.transgender_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _genders.indexWhere((g) => g['label'] == widget.selectedGender);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(
      initialPage: 1000 + _currentIndex, // Start in middle for infinite scroll
      viewportFraction: 0.3,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Arrow pointing down above symbol
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: DesignTokens.textSecondaryOf(context),
        ),
        const SizedBox(height: 2),
        // Swipeable gender symbols with looping
        SizedBox(
          height: 60,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final actualIndex = index % _genders.length;
              setState(() => _currentIndex = actualIndex);
              HapticFeedback.selectionClick();
              widget.onGenderSelected(_genders[actualIndex]['label']);
              // Loop back to middle if needed for infinite scroll
              if (index < 500 || index > 1500) {
                _pageController.jumpToPage(1000 + actualIndex);
              }
            },
            itemBuilder: (context, index) {
              final actualIndex = index % _genders.length;
              final gender = _genders[actualIndex];
              final isCenter = actualIndex == _currentIndex;
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with gradient when selected
                  ShaderMask(
                    shaderCallback: (bounds) {
                      if (isCenter) {
                        return DesignTokens.primaryGradient.createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        );
                      }
                      return LinearGradient(
                        colors: [
                          DesignTokens.textSecondaryOf(context),
                          DesignTokens.textSecondaryOf(context),
                        ],
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      );
                    },
                    child: Icon(
                      gender['icon'],
                      size: 36,
                      color: Colors.white, // This will be masked by the gradient
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Gender name below icon
                  SizedBox(
                    width: 70,
                    child: Text(
                      gender['label'],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBodySmall,
                        fontWeight: isCenter
                            ? DesignTokens.fontWeightBold
                            : DesignTokens.fontWeightMedium,
                        color: isCenter
                            ? DesignTokens.textPrimaryOf(context)
                            : DesignTokens.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        // Arrow pointing up below symbol
        Icon(
          Icons.keyboard_arrow_up_rounded,
          size: 18,
          color: DesignTokens.textSecondaryOf(context),
        ),
      ],
    );
  }
}

// Small gender box
class _SmallGenderBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallGenderBox({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: DesignTokens.animationMedium,
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: selected ? DesignTokens.primaryGradient : null,
          color: selected ? null : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : borderColor,
            width: selected ? 0 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? Colors.white : textSecondary,
            ),
            const SizedBox(height: DesignTokens.spacing4),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected
                    ? DesignTokens.fontWeightBold
                    : DesignTokens.fontWeightMedium,
                color: selected ? Colors.white : textSecondary,
                fontSize: DesignTokens.fontSizeMeta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom date picker with short month names and gradient selected text
class _CustomDatePicker extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;

  const _CustomDatePicker({
    required this.initialDateTime,
    required this.onDateTimeChanged,
  });

  @override
  State<_CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<_CustomDatePicker> {
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDateTime;
    _dayController = FixedExtentScrollController(initialItem: _selectedDate.day - 1);
    _monthController = FixedExtentScrollController(initialItem: _selectedDate.month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _selectedDate.year - 1950,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateDate(int day, int month, int year) {
    final newDate = DateTime(year, month, day);
    if (newDate != _selectedDate) {
      setState(() => _selectedDate = newDate);
      widget.onDateTimeChanged(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return Row(
      children: [
        // Day picker
        Expanded(
          child: _ModernRotator(
            height: 240,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: DesignTokens.accentOrange,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: DesignTokens.fontWeightBold,
                  ),
                ),
              ),
              child: CupertinoPicker(
                scrollController: _dayController,
                itemExtent: 50,
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
                  final day = (index % daysInMonth) + 1;
                  _updateDate(day, _selectedDate.month, _selectedDate.year);
                },
                children: List.generate(31, (index) {
                  final day = index + 1;
                  return Center(
                    child: _GradientPickerItem(
                      text: day.toString(),
                      isSelected: day == _selectedDate.day,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        // Month picker
        Expanded(
          child: _ModernRotator(
            height: 240,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: DesignTokens.accentOrange,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: DesignTokens.fontWeightBold,
                  ),
                ),
              ),
              child: CupertinoPicker(
                scrollController: _monthController,
                itemExtent: 50,
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  final month = index + 1;
                  final daysInMonth = DateTime(_selectedDate.year, month + 1, 0).day;
                  final day = _selectedDate.day > daysInMonth ? daysInMonth : _selectedDate.day;
                  _updateDate(day, month, _selectedDate.year);
                },
                children: shortMonths.map((month) {
                  final index = shortMonths.indexOf(month);
                  return Center(
                    child: _GradientPickerItem(
                      text: month,
                      isSelected: index + 1 == _selectedDate.month,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        // Year picker
        Expanded(
          child: _ModernRotator(
            height: 240,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: DesignTokens.accentOrange,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: DesignTokens.fontWeightBold,
                  ),
                ),
              ),
              child: CupertinoPicker(
                scrollController: _yearController,
                itemExtent: 50,
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  final year = 1950 + index;
                  final daysInMonth = DateTime(year, _selectedDate.month + 1, 0).day;
                  final day = _selectedDate.day > daysInMonth ? daysInMonth : _selectedDate.day;
                  _updateDate(day, _selectedDate.month, year);
                },
                children: List.generate(75, (index) {
                  final year = 1950 + index;
                  return Center(
                    child: _GradientPickerItem(
                      text: year.toString(),
                      isSelected: year == _selectedDate.year,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Date picker with short month names
class _DatePickerWithShortMonths extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;

  const _DatePickerWithShortMonths({
    required this.initialDateTime,
    required this.onDateTimeChanged,
  });

  @override
  State<_DatePickerWithShortMonths> createState() => _DatePickerWithShortMonthsState();
}

class _DatePickerWithShortMonthsState extends State<_DatePickerWithShortMonths> {
  late DateTime _selectedDate;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  final List<String> _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  // For infinite looping - start in the middle
  static const int _monthLoopSize = 12;
  static const int _dayMiddleIndex = 1000;
  static const int _monthMiddleIndex = 1000;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDateTime;
    // Start in the middle for infinite scroll - always use 31 for day controller
    _dayController = FixedExtentScrollController(
      initialItem: _dayMiddleIndex + (_selectedDate.day - 1),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _monthMiddleIndex + (_selectedDate.month - 1),
    );
    _yearController = FixedExtentScrollController(initialItem: _selectedDate.year - 1950);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateDate(int day, int month, int year) {
    final newDate = DateTime(year, month, day);
    if (newDate != _selectedDate) {
      setState(() => _selectedDate = newDate);
      widget.onDateTimeChanged(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Day picker
          Expanded(
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: DesignTokens.accentOrange,
              ),
              child: Builder(
                builder: (context) {
                  final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
                  // Always use 31 days to prevent rotation, but hide invalid days
                  return CupertinoPicker(
                    scrollController: _dayController,
                    itemExtent: 50,
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      // Calculate actual day from looped index (always 31 days)
                      final actualIndex = index % 31;
                      final day = actualIndex + 1;
                      
                      // Only update if day is valid for current month
                      if (day <= daysInMonth) {
                        _updateDate(day, _selectedDate.month, _selectedDate.year);
                      }
                      
                      // Loop back to middle if needed for infinite scroll
                      if (index < _dayMiddleIndex - 500 || index > _dayMiddleIndex + 500) {
                        final newIndex = _dayMiddleIndex + actualIndex;
                        if (_dayController.hasClients) {
                          _dayController.jumpToItem(newIndex);
                        }
                      }
                    },
                    children: List.generate(31 * 50, (index) {
                      final actualIndex = index % 31;
                      final day = actualIndex + 1;
                      final isValidDay = day <= daysInMonth;
                      // Check if this is the selected day (regardless of index position)
                      final isSelected = day == _selectedDate.day && isValidDay;
                      return Center(
                        child: isValidDay
                            ? _GradientPickerItem(
                                text: day.toString(),
                                isSelected: isSelected,
                              )
                            : Opacity(
                                opacity: 0.0, // Invisible but maintains spacing
                                child: _GradientPickerItem(
                                  text: day.toString(),
                                  isSelected: false,
                                ),
                              ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacing8),
          // Month picker with short names
          Expanded(
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: DesignTokens.accentOrange,
              ),
              child: CupertinoPicker(
                scrollController: _monthController,
                itemExtent: 50,
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  // Calculate actual month from looped index
                  final actualIndex = index % _monthLoopSize;
                  final month = actualIndex + 1;
                  
                  // Preserve the selected day if valid for new month, otherwise use max day
                  final daysInMonth = DateTime(_selectedDate.year, month + 1, 0).day;
                  final day = _selectedDate.day > daysInMonth ? daysInMonth : _selectedDate.day;
                  
                  _updateDate(day, month, _selectedDate.year);
                  
                  // Immediately update day controller to prevent rotation
                  Future.microtask(() {
                    if (mounted && _dayController.hasClients) {
                      final dayIndex = _dayMiddleIndex + (day - 1);
                      _dayController.jumpToItem(dayIndex);
                    }
                  });
                  
                  // Loop back to middle if needed for infinite scroll
                  if (index < _monthMiddleIndex - 500 || index > _monthMiddleIndex + 500) {
                    final newIndex = _monthMiddleIndex + actualIndex;
                    if (_monthController.hasClients) {
                      _monthController.jumpToItem(newIndex);
                    }
                  }
                },
                children: List.generate(_monthLoopSize * 100, (index) {
                  final actualIndex = index % _monthLoopSize;
                  final month = _shortMonths[actualIndex];
                  // Check if this is the selected month (regardless of index position)
                  final isSelected = actualIndex + 1 == _selectedDate.month;
                  return Center(
                    child: _GradientPickerItem(
                      text: month,
                      isSelected: isSelected,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacing8),
          // Year picker
          Expanded(
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: DesignTokens.accentOrange,
              ),
              child: CupertinoPicker(
                scrollController: _yearController,
                itemExtent: 50,
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  final year = 1950 + index;
                  final daysInMonth = DateTime(year, _selectedDate.month + 1, 0).day;
                  final day = _selectedDate.day > daysInMonth ? daysInMonth : _selectedDate.day;
                  _updateDate(day, _selectedDate.month, year);
                },
                children: List.generate(75, (index) {
                  final year = 1950 + index;
                  final isSelected = year == _selectedDate.year;
                  return Center(
                    child: _GradientPickerItem(
                      text: year.toString(),
                      isSelected: isSelected,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Gradient picker item for selected text
class _GradientPickerItem extends StatelessWidget {
  final String text;
  final bool isSelected;

  const _GradientPickerItem({
    required this.text,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return ShaderMask(
        shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 24,
            fontWeight: DesignTokens.fontWeightBold,
            color: Colors.white,
          ),
        ),
      );
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: DesignTokens.fontWeightMedium,
        color: DesignTokens.textSecondaryOf(context),
      ),
    );
  }
}

// Modern rotator widget with enhanced design
class _ModernRotator extends StatelessWidget {
  final double height;
  final Widget child;
  final Key? key;

  const _ModernRotator({
    this.key,
    required this.height,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Gradient overlay at top and bottom
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surfaceColor,
                      surfaceColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: height * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      surfaceColor,
                      surfaceColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Center highlight line
            Center(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: DesignTokens.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Picker content
            child,
          ],
        ),
      ),
    );
  }
}

// Vertical weight selector with scale design
class _VerticalWeightSelector extends StatefulWidget {
  final double value;
  final String unit;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _VerticalWeightSelector({
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_VerticalWeightSelector> createState() => _VerticalWeightSelectorState();
}

class _VerticalWeightSelectorState extends State<_VerticalWeightSelector> {
  late FixedExtentScrollController _controller;

  int _getIndexForValue(double value) {
    if (widget.unit == 'kg') {
      return ((value - widget.min) * 2).round().clamp(0, ((widget.max - widget.min) * 2).round());
    } else {
      return (value - widget.min).round().clamp(0, (widget.max - widget.min).round());
    }
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _getIndexForValue(widget.value);
    _controller = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(_VerticalWeightSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.unit != widget.unit) {
      final newIndex = _getIndexForValue(widget.value);
      if (_controller.hasClients && _controller.selectedItem != newIndex) {
        _controller.jumpToItem(newIndex);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final itemCount = widget.unit == 'kg'
        ? ((widget.max - widget.min) * 2).round() + 1
        : (widget.max - widget.min).round() + 1;
    
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Scale markers on left
          Container(
            width: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (index) {
                final isMajor = index % 2 == 0;
                return Container(
                  width: isMajor ? 3 : 2,
                  height: isMajor ? 12 : 8,
                  color: DesignTokens.borderColorOf(context),
                );
              }),
            ),
          ),
          const SizedBox(width: DesignTokens.spacing8),
          // Vertical picker
          Expanded(
            child: Stack(
              children: [
                CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(context).brightness,
                    primaryColor: DesignTokens.accentOrange,
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: DesignTokens.fontWeightBold,
                      ),
                    ),
                  ),
                  child: CupertinoPicker(
                    scrollController: _controller,
                    itemExtent: 50,
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      final newValue = widget.unit == 'kg' 
                          ? (widget.min + index * 0.5).clamp(widget.min, widget.max)
                          : (widget.min + index).toDouble().clamp(widget.min, widget.max);
                      widget.onChanged(newValue);
                    },
                    children: List.generate(itemCount, (index) {
                      final value = widget.unit == 'kg'
                          ? (widget.min + index * 0.5).clamp(widget.min, widget.max)
                          : (widget.min + index).toDouble();
                      final isSelected = widget.unit == 'kg'
                          ? (value - widget.value).abs() < 0.3
                          : (value - widget.value).abs() < 1;
                      return Center(
                        child: _GradientPickerItem(
                          text: '${value.toStringAsFixed(widget.unit == 'kg' ? 1 : 0)} ${widget.unit}',
                          isSelected: isSelected,
                        ),
                      );
                    }),
                  ),
                ),
                // Center highlight line
                Positioned(
                  top: 65,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignTokens.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Weight slider with ruler design - completely rebuilt
class _HorizontalRulerWeightSelector extends StatefulWidget {
  final double value;
  final String unit;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _HorizontalRulerWeightSelector({
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_HorizontalRulerWeightSelector> createState() => _HorizontalRulerWeightSelectorState();
}

class _HorizontalRulerWeightSelectorState extends State<_HorizontalRulerWeightSelector> {
  late ScrollController _scrollController;
  // 10 lines per unit: 9 small lines (0.1-0.9) + 1 big line (whole number)
  // Each 0.1 unit = pixelsPerUnit / 10
  final double _pixelsPerUnit = 120.0; // 12 pixels per line for good spacing

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start at first big line (min value)
      _scrollToValue(widget.min, animate: false);
    });
  }

  @override
  void didUpdateWidget(_HorizontalRulerWeightSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.unit != widget.unit) {
      _scrollToValue(widget.value, animate: true);
    }
  }

  void _scrollToValue(double value, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final roundedValue = value.round().toDouble().clamp(widget.min, widget.max);
    final offset = (roundedValue - widget.min) * _pixelsPerUnit;
    
    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final newValue = (offset / _pixelsPerUnit) + widget.min;
    final clampedValue = newValue.clamp(widget.min, widget.max);
    final roundedValue = (clampedValue * 10).round() / 10.0;
    
    if ((roundedValue - widget.value).abs() > 0.05) {
      widget.onChanged(roundedValue);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final range = widget.max - widget.min;
    final totalWidth = range * _pixelsPerUnit + screenWidth;
    
    return Column(
      children: [
        // Weight display
        Text(
          '${widget.value.toStringAsFixed(widget.unit == 'kg' ? 1 : 0)} ${widget.unit}',
          style: TextStyle(
            fontSize: 36,
            fontWeight: DesignTokens.fontWeightBold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: DesignTokens.spacing24),
        // Ruler slider
        Container(
          height: 100,
          child: Stack(
            children: [
              // Scrollable ruler
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification || 
                      notification is ScrollEndNotification) {
                    _onScroll();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const _WeightSliderPhysics(),
                  child: Container(
                    width: totalWidth,
                    height: 100,
                    child: CustomPaint(
                      painter: _WeightRulerPainter(
                        min: widget.min,
                        max: widget.max,
                        pixelsPerUnit: _pixelsPerUnit,
                        screenWidth: screenWidth,
                        textColor: DesignTokens.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ),
              ),
              // Center indicator line with orange gradient
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
                  child: Container(
                    width: 1.0,
                    height: 100,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Fast and smooth scroll physics
class _WeightSliderPhysics extends ClampingScrollPhysics {
  const _WeightSliderPhysics({super.parent});

  @override
  _WeightSliderPhysics applyTo(ScrollPhysics? ancestor) {
    return _WeightSliderPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 5.0;
  @override
  double get maxFlingVelocity => 30000.0;
}

// Ruler painter - draws lines and numbers
class _WeightRulerPainter extends CustomPainter {
  final double min;
  final double max;
  final double pixelsPerUnit;
  final double screenWidth;
  final Color textColor;

  _WeightRulerPainter({
    required this.min,
    required this.max,
    required this.pixelsPerUnit,
    required this.screenWidth,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = textColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    final majorPaint = Paint()
      ..color = textColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.0;

    final centerX = screenWidth / 2;
    final rulerY = size.height * 0.65;
    final majorHeight = 40.0;
    final minorHeight = 22.0;

    // Calculate visible range
    final padding = 300.0;
    final visibleStart = ((centerX - padding) / pixelsPerUnit * 10).floor() / 10.0 + min;
    final visibleEnd = (((centerX + size.width + padding) / pixelsPerUnit) * 10).ceil() / 10.0 + min;

    // Draw all lines in visible range
    for (double value = visibleStart; value <= visibleEnd; value += 0.1) {
      if (value < min || value > max) continue;
      
      final x = (value - min) * pixelsPerUnit;
      final decimalPart = (value - value.floor()).abs();
      final isMajor = decimalPart < 0.01 || decimalPart > 0.99;
      
      final height = isMajor ? majorHeight : minorHeight;
      final paint = isMajor ? majorPaint : minorPaint;

      // Draw line pointing up
      canvas.drawLine(
        Offset(x, rulerY),
        Offset(x, rulerY - height),
        paint,
      );
      
      // Draw number below big lines
      if (isMajor) {
        final wholeNumber = value.round();
        if (wholeNumber >= min && wholeNumber <= max) {
          final text = wholeNumber.toString();
          final textPainter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, rulerY + 12),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WeightRulerPainter oldDelegate) {
    return oldDelegate.min != min || oldDelegate.max != max;
  }
}

// Goals dropdown selector
class _GoalsDropdown extends StatefulWidget {
  final List<String> goals;
  final Set<String> selected;
  final ValueChanged<String> onToggleGoal;

  const _GoalsDropdown({
    required this.goals,
    required this.selected,
    required this.onToggleGoal,
  });

  @override
  State<_GoalsDropdown> createState() => _GoalsDropdownState();
}

class _GoalsDropdownState extends State<_GoalsDropdown> {
  String? _selectedGoal;

  @override
  void initState() {
    super.initState();
    // Set initial selected goal if any
    if (widget.selected.isNotEmpty) {
      _selectedGoal = widget.selected.first;
    }
  }

  @override
  void didUpdateWidget(_GoalsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected.isNotEmpty && widget.selected != oldWidget.selected) {
      _selectedGoal = widget.selected.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGoal,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          icon: Icon(
            Icons.arrow_drop_down,
            color: DesignTokens.textSecondaryOf(context),
          ),
          hint: Text(
            'Select fitness goals',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
          style: TextStyle(
            color: DesignTokens.textPrimaryOf(context),
            fontWeight: DesignTokens.fontWeightMedium,
            fontSize: DesignTokens.fontSizeBody,
          ),
          items: widget.goals.map((goal) {
            final isSelected = widget.selected.contains(goal);
            return DropdownMenuItem<String>(
              value: goal,
              child: Row(
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: DesignTokens.accentOrange,
                      size: 20,
                    )
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: DesignTokens.textSecondaryOf(context),
                      size: 20,
                    ),
                  const SizedBox(width: DesignTokens.spacing8),
                  Expanded(
                    child: Text(goal),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedGoal = value);
              HapticFeedback.selectionClick();
              widget.onToggleGoal(value);
            }
          },
        ),
      ),
    );
  }
}

// Role selector input box
class _RoleSelector extends StatefulWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleSelected;

  const _RoleSelector({
    required this.selectedRole,
    required this.onRoleSelected,
  });

  @override
  State<_RoleSelector> createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<_RoleSelector> {
  late FixedExtentScrollController _controller;
  final List<String> _roles = ['Client', 'Trainer', 'Nutritionist'];

  @override
  void initState() {
    super.initState();
    final initialIndex = _roles.indexOf(widget.selectedRole);
    _controller = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void didUpdateWidget(_RoleSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      final newIndex = _roles.indexOf(widget.selectedRole);
      if (newIndex >= 0 && _controller.hasClients && _controller.selectedItem != newIndex) {
        _controller.jumpToItem(newIndex);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.borderColorOf(context),
          width: 1.5,
        ),
      ),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: DesignTokens.accentOrange,
        ),
        child: CupertinoPicker(
          scrollController: _controller,
          itemExtent: 50,
          onSelectedItemChanged: (index) {
            HapticFeedback.selectionClick();
            widget.onRoleSelected(_roles[index]);
          },
          children: _roles.map((role) {
            final isSelected = role == widget.selectedRole;
            return Center(
              child: _GradientPickerItem(
                text: role,
                isSelected: isSelected,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Modern toggle switch design
class _ModernToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _ModernToggle({
    required this.left,
    required this.right,
    required this.isLeft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!isLeft);
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: DesignTokens.animationMedium,
              curve: Curves.easeOutCubic,
              left: isLeft ? 4 : null,
              right: isLeft ? null : 4,
              top: 4,
              bottom: 4,
              width: (MediaQuery.of(context).size.width - 48 - 8) / 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      left,
                      style: TextStyle(
                        fontWeight: isLeft
                            ? DesignTokens.fontWeightBold
                            : DesignTokens.fontWeightMedium,
                        color: isLeft ? Colors.white : textSecondary,
                        fontSize: DesignTokens.fontSizeBody,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      right,
                      style: TextStyle(
                        fontWeight: !isLeft
                            ? DesignTokens.fontWeightBold
                            : DesignTokens.fontWeightMedium,
                        color: !isLeft ? Colors.white : textSecondary,
                        fontSize: DesignTokens.fontSizeBody,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Small toggle for inline use
class _SmallToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _SmallToggle({
    required this.left,
    required this.right,
    required this.isLeft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!isLeft);
      },
      child: Container(
        height: 32,
        width: 100,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: DesignTokens.animationMedium,
              curve: Curves.easeOutCubic,
              left: isLeft ? 2 : null,
              right: isLeft ? null : 2,
              top: 2,
              bottom: 2,
              width: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      left,
                      style: TextStyle(
                        fontWeight: isLeft
                            ? DesignTokens.fontWeightBold
                            : DesignTokens.fontWeightMedium,
                        color: isLeft ? Colors.white : textSecondary,
                        fontSize: DesignTokens.fontSizeBodySmall,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      right,
                      style: TextStyle(
                        fontWeight: !isLeft
                            ? DesignTokens.fontWeightBold
                            : DesignTokens.fontWeightMedium,
                        color: !isLeft ? Colors.white : textSecondary,
                        fontSize: DesignTokens.fontSizeBodySmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

