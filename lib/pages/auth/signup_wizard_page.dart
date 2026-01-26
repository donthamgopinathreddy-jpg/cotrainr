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
  final _scrollController = ScrollController();
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
    
    // Add listeners to text controllers to check completion
    _userId.addListener(_checkAndScroll);
    _email.addListener(_checkAndScroll);
    _pass.addListener(_checkAndScroll);
    _confirmPass.addListener(_checkAndScroll);
    _first.addListener(_checkAndScroll);
    _last.addListener(_checkAndScroll);
    _phone.addListener(_checkAndScroll);
  }

  @override
  void dispose() {
    _page.dispose();
    _scrollController.dispose();
    _userId.removeListener(_checkAndScroll);
    _email.removeListener(_checkAndScroll);
    _pass.removeListener(_checkAndScroll);
    _confirmPass.removeListener(_checkAndScroll);
    _first.removeListener(_checkAndScroll);
    _last.removeListener(_checkAndScroll);
    _phone.removeListener(_checkAndScroll);
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
      // Reset scroll position for new step
      _scrollController.jumpTo(0);
      
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

  bool _isStepComplete(int step) {
    switch (step) {
      case 0: // Step 1: Credentials
        final pass = _pass.text;
        final hasValidPassword = pass.isNotEmpty && 
          RegExp(r'[A-Z]').hasMatch(pass) &&
          RegExp(r'[a-z]').hasMatch(pass) &&
          RegExp(r'[0-9]').hasMatch(pass) &&
          RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass);
        return _userId.text.trim().isNotEmpty &&
               _email.text.trim().isNotEmpty &&
               hasValidPassword &&
               _pass.text == _confirmPass.text &&
               _confirmPass.text.isNotEmpty &&
               _userIdAvailabilityStatus == 'available';
      case 1: // Step 2: Personal Info
        return _first.text.trim().isNotEmpty &&
               _last.text.trim().isNotEmpty &&
               _phone.text.trim().isNotEmpty;
      case 2: // Step 3: DOB & Gender
        return _gender.isNotEmpty;
      case 3: // Step 4: Height & Weight
        return true; // Always complete (has default values)
      case 4: // Step 5: Goals & Role
        return _selectedGoals.isNotEmpty && _role.isNotEmpty;
      default:
        return false;
    }
  }

  void _checkAndScroll() {
    if (_isStepComplete(_step)) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = DesignTokens.backgroundOf(context);
    final progress = (_step + 1) / 5;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
              // Clean Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing24,
                  vertical: DesignTokens.spacing20,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _back,
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: DesignTokens.textPrimaryOf(context),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeH2,
                          fontWeight: DesignTokens.fontWeightBold,
                          color: DesignTokens.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    // Step count with different style
                    Row(
                      children: [
                        Text(
                          '${_step + 1}',
                          style: TextStyle(
                            color: _getStepColor(_step),
                            fontWeight: DesignTokens.fontWeightBold,
                            fontSize: DesignTokens.fontSizeH2,
                          ),
                        ),
                        Text(
                          '/5',
                          style: TextStyle(
                            color: DesignTokens.textSecondaryOf(context),
                            fontWeight: DesignTokens.fontWeightMedium,
                            fontSize: DesignTokens.fontSizeBody,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Progress Bar with different colors for each step
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing24,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: [
                        Container(
                          color: DesignTokens.borderColorOf(context),
                        ),
                        AnimatedContainer(
                          duration: DesignTokens.animationMedium,
                          curve: DesignTokens.animationCurve,
                          width: MediaQuery.of(context).size.width * progress,
                          decoration: BoxDecoration(
                            color: _getStepColor(_step),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              // Content
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing24,
                  ),
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
                        countryCode: _phoneCountryCode,
                        onCountryCodeChanged: (code) => setState(() => _phoneCountryCode = code),
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
              
              const SizedBox(height: DesignTokens.spacing20),
              
              // Next/Submit Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing24,
                  vertical: DesignTokens.spacing20,
                ),
                child: _CleanButton(
                  text: _step == 4 ? 'Create Account' : 'Continue',
                  onTap: _isSubmitting ? null : _next,
                  isLoading: _isSubmitting,
                ),
              ),
              ],
            ),
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
      title: 'Account Setup',
      subtitle: 'Create your unique user ID and secure password',
      child: Column(
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
          const SizedBox(height: DesignTokens.spacing16),
          
          // Email
          _CleanField(
            label: 'Email',
            controller: widget.email,
            keyboardType: TextInputType.emailAddress,
            prefix: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          
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
          const SizedBox(height: DesignTokens.spacing16),
          
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
  final String countryCode;
  final ValueChanged<String> onCountryCodeChanged;

  const _Step2({
    required this.first,
    required this.last,
    required this.phone,
    required this.countryCode,
    required this.onCountryCodeChanged,
  });

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {
  final Map<String, String> _countryCodes = {
    'India': '+91',
    'United States': '+1',
    'United Kingdom': '+44',
    'Canada': '+1',
    'Australia': '+61',
    'Germany': '+49',
    'France': '+33',
    'Japan': '+81',
    'China': '+86',
    'Brazil': '+55',
  };

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Personal Information',
      subtitle: 'Tell us about yourself',
      child: Column(
        children: [
          // First name - full width
          _CleanField(
            label: 'First name',
            controller: widget.first,
            prefix: Icons.person_outline_rounded,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          // Last name - full width
          _CleanField(
            label: 'Last name',
            controller: widget.last,
            prefix: Icons.person_outline_rounded,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          // Phone with country code
          Row(
            children: [
              // Country code selector
              Container(
                width: 100,
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DesignTokens.borderColorOf(context),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.countryCode,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing12),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: DesignTokens.textSecondaryOf(context),
                    ),
                    style: TextStyle(
                      color: DesignTokens.textPrimaryOf(context),
                      fontWeight: DesignTokens.fontWeightMedium,
                      fontSize: DesignTokens.fontSizeBody,
                    ),
                    items: _countryCodes.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.value,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.onCountryCodeChanged(value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              // Phone number field
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

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Date of Birth & Gender',
      subtitle: 'Help us personalize your experience',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modern DOB picker with blur effect
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceOf(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DesignTokens.borderColorOf(context),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Blur effect overlay
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        color: DesignTokens.surfaceOf(context).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  // Date picker
                  CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      primaryColor: DesignTokens.accentOrange,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: DesignTokens.textPrimaryOf(context),
                          fontSize: 22,
                          fontWeight: DesignTokens.fontWeightSemiBold,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: dob,
                      maximumDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                      minimumDate: DateTime(1950, 1, 1),
                      onDateTimeChanged: onDobChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GenderChip(
                text: 'Male',
                selected: gender == 'Male',
                onTap: () => onGender('Male'),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              _GenderChip(
                text: 'Female',
                selected: gender == 'Female',
                onTap: () => onGender('Female'),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              _GenderChip(
                text: 'Other',
                selected: gender == 'Other',
                onTap: () => onGender('Other'),
              ),
            ],
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
      title: 'Height & Weight',
      subtitle: 'Select your measurements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Height',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontWeight: DesignTokens.fontWeightSemiBold,
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Row(
            children: [
              _TogglePill(
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
                ? _ModernRotator(
                    key: const ValueKey('cm'),
                    height: 180,
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
                          widget.onHeightCm((80 + index).toDouble());
                        },
                        children: List.generate(151, (index) {
                          final value = 80 + index;
                          return Center(
                            child: Text('$value cm'),
                          );
                        }),
                      ),
                    ),
                  )
                : Row(
                    key: const ValueKey('ftin'),
                    children: [
                      Expanded(
                        child: _ModernRotator(
                          height: 180,
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
                                widget.onFeet(3 + index);
                              },
                              children: List.generate(6, (index) {
                                final value = 3 + index;
                                return Center(child: Text('$value ft'));
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing12),
                      Expanded(
                        child: _ModernRotator(
                          height: 180,
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
                              },
                              children: List.generate(12, (index) {
                                return Center(child: Text('$index in'));
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          // Weight section with icon
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
            ],
          ),
          const SizedBox(height: DesignTokens.spacing8),
          _TogglePill(
            left: 'kg',
            right: 'lbs',
            isLeft: widget.weightInKg,
            onChanged: widget.onToggleWeightUnit,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          AnimatedSwitcher(
            duration: DesignTokens.animationMedium,
            child: widget.weightInKg
                ? _ModernRotator(
                    key: const ValueKey('kg'),
                    height: 180,
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
                        scrollController: _weightKgController,
                        itemExtent: 50,
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          widget.onWeightKg((20 + index * 0.5).clamp(20, 250));
                        },
                        children: List.generate(461, (index) {
                          final value = (20 + index * 0.5).toStringAsFixed(1);
                          return Center(child: Text('$value kg'));
                        }),
                      ),
                    ),
                  )
                : _ModernRotator(
                    key: const ValueKey('lbs'),
                    height: 180,
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
                        scrollController: _weightLbsController,
                        itemExtent: 50,
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          widget.onWeightLbs((44 + index).toDouble().clamp(44, 550));
                        },
                        children: List.generate(507, (index) {
                          final value = 44 + index;
                          return Center(child: Text('$value lbs'));
                        }),
                      ),
                    ),
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
      title: 'Goals & Role',
      subtitle: 'Choose your fitness goals and role',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Wrap(
            spacing: DesignTokens.spacing10,
            runSpacing: DesignTokens.spacing10,
            children: goals.map((g) {
              final isOn = selected.contains(g);
              return InkWell(
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                onTap: () => onToggleGoal(g),
                child: AnimatedContainer(
                  duration: DesignTokens.animationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing16,
                    vertical: DesignTokens.spacing12,
                  ),
                  decoration: BoxDecoration(
                    color: isOn
                        ? DesignTokens.accentOrange.withValues(alpha: 0.15)
                        : DesignTokens.surfaceOf(context),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                    border: Border.all(
                      color: isOn
                          ? DesignTokens.accentOrange.withValues(alpha: 0.5)
                          : DesignTokens.borderColorOf(context),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontWeight: DesignTokens.fontWeightSemiBold,
                      color: isOn
                          ? DesignTokens.textPrimaryOf(context)
                          : DesignTokens.textSecondaryOf(context),
                      fontSize: DesignTokens.fontSizeBodySmall,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          Text(
            'Role',
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontWeight: DesignTokens.fontWeightSemiBold,
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  text: 'Client',
                  selected: role == 'Client',
                  onTap: () => onRole('Client'),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              Expanded(
                child: _ChoiceChip(
                  text: 'Trainer',
                  selected: role == 'Trainer',
                  onTap: () => onRole('Trainer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Shared Components
class _StepShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing20),
      child: ListView(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeH2,
              fontWeight: DesignTokens.fontWeightBold,
              color: DesignTokens.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing6),
          Text(
            subtitle,
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: DesignTokens.fontSizeBody,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          child,
        ],
      ),
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

class _GenderChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing20,
          vertical: DesignTokens.spacing10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.accentOrange.withValues(alpha: 0.15)
              : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? DesignTokens.accentOrange
                : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: selected ? DesignTokens.fontWeightSemiBold : DesignTokens.fontWeightMedium,
            color: selected ? DesignTokens.accentOrange : textSecondary,
            fontSize: DesignTokens.fontSizeBodySmall,
          ),
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

// Modern rotator widget with blur effect
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Blur effect overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: surfaceColor.withValues(alpha: 0.8),
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

class _TogglePill extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _TogglePill({
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
    final textSecondary = DesignTokens.textSecondaryOf(context);
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniToggle(
            text: left,
            selected: isLeft,
            onTap: () => onChanged(true),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _MiniToggle(
            text: right,
            selected: !isLeft,
            onTap: () => onChanged(false),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;

  const _MiniToggle({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.accentOrange.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: DesignTokens.fontWeightBold,
            color: selected ? textPrimary : textSecondary,
            fontSize: DesignTokens.fontSizeBodySmall,
          ),
        ),
      ),
    );
  }
}
