import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/signup_error_mapper.dart';
import '../../theme/design_tokens.dart';
import '../../theme/account_hub_theme.dart';
import '../../widgets/auth/auth_ui.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../services/user_goals_service.dart';
import '../../services/pending_referral_service.dart';
import '../../repositories/referral_repository.dart';
import '../../models/provider_specialty_taxonomy.dart';
import '../../pages/profile/settings/info_pages.dart';

class SignupWizardPage extends StatefulWidget {
  const SignupWizardPage({super.key, this.initialReferralCode});

  final String? initialReferralCode;

  @override
  State<SignupWizardPage> createState() => _SignupWizardPageState();
}

class _SignupWizardPageState extends State<SignupWizardPage>
    with TickerProviderStateMixin {
  static const _totalSteps = 7;
  static const _lastStepIndex = _totalSteps - 1;
  static const _roleStepIndex = 5;

  final _page = PageController();
  int _step = 0;

  // Step 1
  final _userId = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  final _referralCode = TextEditingController();
  String? _userIdAvailabilityStatus;
  bool _isCheckingUserId = false;
  String? _emailValidationStatus; // 'valid', 'invalid', 'taken', null
  bool _isCheckingEmail = false;
  bool _agreedLegal = false;
  bool _showSlowHint = false;
  String _termsVersion = '2026-08-01';
  String _privacyVersion = '2026-08-01';
  Timer? _slowHintTimer;

  // Step 2
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  String _phoneCountryCode = '+91';

  // Step 3 — date of birth + gender
  DateTime _dob = DateTime(2002, 1, 1);
  String _gender = 'Male';

  // Step 4 — height
  bool _heightInCm = true;
  double _heightCm = 170;
  int _feet = 5;
  int _inch = 7;

  // Step 5 — weight
  bool _weightInKg = true;
  double _weightKg = 70;
  double _weightLbs = 154;

  // Step 6 — goals, role, provider specialties
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
  final Set<String> _selectedSpecializations = {};
  final _customSpecialty = TextEditingController();

  static const _trainerSpecialties = ProviderSpecialtyTaxonomy.trainer;
  static const _nutritionistSpecialties =
      ProviderSpecialtyTaxonomy.nutritionist;

  bool _isSubmitting = false;
  bool _referralApplied = false; // Guard: prevent double apply_referral_code

  late final AnimationController _fadeController;
  late final AnimationController _stepTransitionController;

  @override
  void initState() {
    super.initState();
    _initReferralCode();
    unawaited(_loadLegalVersions());
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _stepTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _stepTransitionController.forward();
  }

  Future<void> _loadLegalVersions() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('current_legal_versions')
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is List && raw.isNotEmpty) {
        final row = Map<String, dynamic>.from(raw.first as Map);
        setState(() {
          _termsVersion = row['terms_version']?.toString() ?? _termsVersion;
          _privacyVersion =
              row['privacy_version']?.toString() ?? _privacyVersion;
        });
      } else if (raw is Map) {
        setState(() {
          _termsVersion = raw['terms_version']?.toString() ?? _termsVersion;
          _privacyVersion =
              raw['privacy_version']?.toString() ?? _privacyVersion;
        });
      }
    } catch (_) {}
  }

  Future<void> _initReferralCode() async {
    final fromRoute = widget.initialReferralCode;
    final fromDeepLink = await PendingReferralService.getPendingCode();
    final code = fromRoute ?? fromDeepLink;
    if (code != null && mounted) {
      _referralCode.text = code;
    }
  }

  @override
  void dispose() {
    _slowHintTimer?.cancel();
    _page.dispose();
    _userId.dispose();
    _referralCode.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _customSpecialty.dispose();
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
        const SnackBar(content: Text('Username is required')),
      );
      return false;
    }
    // Database requirement: 3-20 chars, A-Za-z0-9_ only
    if (userIdText.length < 3 || userIdText.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be 3-20 characters')),
      );
      return false;
    }
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(userIdText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username can only contain letters, numbers, and underscore')),
      );
      return false;
    }
    if (_userIdAvailabilityStatus == 'error') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SignupErrorMapper.usernameCheckFailed.display)),
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
    // Database requirement: 3-20 chars, A-Za-z0-9_ only
    if (userId.isEmpty || !RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(userId)) {
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
      final available = await Supabase.instance.client
          .rpc(
            'is_username_available',
            params: {'p_username': userId},
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _userIdAvailabilityStatus =
            (available == true) ? 'available' : 'taken';
        _isCheckingUserId = false;
      });
    } catch (_) {
      // Fail closed: never treat RPC failure as available.
      if (!mounted) return;
      setState(() {
        _userIdAvailabilityStatus = 'error';
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

    final isValidFormat =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailTrimmed);

    if (!isValidFormat) {
      setState(() {
        _emailValidationStatus = 'invalid';
        _isCheckingEmail = false;
      });
      return;
    }

    // Format-valid is enough pre-signup; Auth returns a clear error if taken.
    if (mounted) {
      setState(() {
        _emailValidationStatus = 'valid';
        _isCheckingEmail = false;
      });
    }
  }

  bool _validateRoleStep() {
    if (_role == 'Trainer' || _role == 'Nutritionist') {
      if (_selectedSpecializations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _role == 'Trainer'
                  ? 'Select or add at least one training specialty'
                  : 'Select or add at least one nutrition specialty',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  bool _validateGoalsStep() {
    if (_selectedGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one fitness goal')),
      );
      return false;
    }
    if (!_agreedLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SignupErrorMapper.legalRequired.display)),
      );
      return false;
    }
    return true;
  }

  void _addCustomSpecialty() {
    final value = _customSpecialty.text.trim();
    if (value.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSpecializations.add(value);
      _customSpecialty.clear();
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _next() {
    if (_isSubmitting) return;

    if (_step == 0 && !_validateStep1()) {
      return;
    }

    if (_step == _roleStepIndex && !_validateRoleStep()) {
      return;
    }

    if (_step == _lastStepIndex && !_validateGoalsStep()) {
      return;
    }

    if (_step < _lastStepIndex) {
      _dismissKeyboard();
      _stepTransitionController.reset();
      setState(() => _step++);
      _page.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      _stepTransitionController.forward();
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      _dismissKeyboard();
      _stepTransitionController.reset();
      setState(() => _step--);
      _page.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      _stepTransitionController.forward();
    } else {
      context.pop();
    }
  }

  String _formatDob(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_agreedLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SignupErrorMapper.legalRequired.display)),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _showSlowHint = false;
    });
    _slowHintTimer?.cancel();
    _slowHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isSubmitting) setState(() => _showSlowHint = true);
    });

    try {
      final supabase = Supabase.instance.client;

      final heightCmRaw =
          _heightInCm ? _heightCm : ((_feet * 30.48) + (_inch * 2.54));
      final weightKgRaw =
          _weightInKg ? _weightKg : (_weightLbs * 0.45359237);
      // Integer/rounded — Postgres trigger casts height to INTEGER
      final heightCm = heightCmRaw.round();
      final weightKg =
          double.parse(weightKgRaw.clamp(20.0, 400.0).toStringAsFixed(2));

      final username = _userId.text.trim();
      if (username.isEmpty) {
        throw Exception('Username is required');
      }

      final phoneDigits = _phone.text.trim();
      final phone =
          phoneDigits.isEmpty ? null : '${_phoneCountryCode}$phoneDigits';

      final signUpData = <String, dynamic>{
        'username': username,
        'full_name': '${_first.text.trim()} ${_last.text.trim()}'.trim(),
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        if (phone != null) 'phone': phone,
        'dob': _formatDob(_dob),
        'gender': _gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'bmi': double.parse(_bmi.toStringAsFixed(2)),
        'goals': _selectedGoals.toList(),
        'role': _role.toLowerCase(),
      };

      if (_role == 'Trainer' || _role == 'Nutritionist') {
        signUpData['specialization'] =
            ProviderSpecialtyTaxonomy.normalizeList(_selectedSpecializations);
      }

      final response = await supabase.auth
          .signUp(
            email: _email.text.trim(),
            password: _pass.text,
            data: signUpData,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.user != null) {
        var session = response.session;

        if (session == null) {
          try {
            final signInResponse = await supabase.auth
                .signInWithPassword(
                  email: _email.text.trim(),
                  password: _pass.text,
                )
                .timeout(const Duration(seconds: 15));
            session = signInResponse.session;
          } catch (_) {
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
          try {
            await supabase
                .rpc(
                  'record_legal_acceptance',
                  params: {
                    'p_terms_version': _termsVersion,
                    'p_privacy_version': _privacyVersion,
                  },
                )
                .timeout(const Duration(seconds: 15));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(SignupErrorMapper.map(e).display),
                backgroundColor: DesignTokens.accentRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCard),
                ),
              ),
            );
            return;
          }

          // Initialize user goals (calculate water goal from weight)
          final goalsService = UserGoalsService();
          await goalsService.initializeGoals(weightKg: weightKgRaw);

          // Referral: apply code AFTER signup, once only, then generate code for new user
          final referralRepo = ReferralRepository();
          try {
            final codeToApply = _referralCode.text.trim().toUpperCase();
            if (codeToApply.isNotEmpty && !_referralApplied) {
              final result = await referralRepo.applyReferralCode(codeToApply);
              _referralApplied = true;
              final status = result['status'] as String?;
              final msg = result['message'] as String? ?? '';
              if (mounted) {
                if (status == 'success' || status == 'already_used') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg.isNotEmpty ? msg : 'Referral applied!'),
                      backgroundColor: DesignTokens.accentGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusCard),
                      ),
                    ),
                  );
                } else if (status == 'invalid_code' ||
                    status == 'self_referral') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        msg.isNotEmpty
                            ? msg
                            : 'Referral code could not be applied',
                      ),
                      backgroundColor: DesignTokens.accentRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusCard),
                      ),
                    ),
                  );
                }
              }
            }
            await referralRepo.generateReferralCode();
            await PendingReferralService.clearPendingCode();
          } catch (_) {
            // Non-fatal: user is signed up, referral is optional
          }

          // Role is set only by trusted handle_new_user from signup metadata.
          // Do NOT call sync_profile_role_from_auth (revoked for clients).

          if (_role == 'Trainer' || _role == 'Nutritionist') {
            try {
              await supabase
                  .from('providers')
                  .upsert({
                    'user_id': response.user!.id,
                    'provider_type': _role.toLowerCase(),
                    'specialization': ProviderSpecialtyTaxonomy.normalizeList(
                      _selectedSpecializations,
                    ),
                  })
                  .timeout(const Duration(seconds: 15));
            } catch (_) {
              // Non-fatal: handle_new_user trigger may have created the row
            }
          }

          final role = _role.toLowerCase();
          if (!mounted) return;

          // Redirect to permissions page first
          context.go('/auth/permissions', extra: {'role': role});
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created! Please check your email to confirm.',
              ),
              backgroundColor: DesignTokens.accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/auth/login');
        }
      } else {
        throw Exception('Signup failed');
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SignupErrorMapper.map(TimeoutException('signup')).display),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SignupErrorMapper.map(e).display),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
        ),
      );
    } finally {
      _slowHintTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showSlowHint = false;
        });
      }
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Create your account';
      case 1:
        return 'Personal Info';
      case 2:
        return 'About You';
      case 3:
        return 'Height';
      case 4:
        return 'Weight';
      case 5:
        return 'Your Role';
      case 6:
        return 'Fitness Goals';
      default:
        return 'Create Account';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0:
        return 'Start training, tracking and transforming.';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'Your age and gender';
      case 3:
        return 'Enter or scroll your height';
      case 4:
        return 'Enter or scroll your weight';
      case 5:
        return 'How will you use Cotrainr?';
      case 6:
        return 'What are you working toward?';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final pageBg = AuthUi.pageBg(context);
    final cs = Theme.of(context).colorScheme;
    final isMetricStep = _step == 3 || _step == 4;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: pageBg,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: AuthScreenBackground(
          scrimStrength: 0.48,
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Column(
                children: [
                  Container(
                    padding:
                        EdgeInsets.fromLTRB(16, 4, 16, isMetricStep ? 6 : 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _back,
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                                color: cs.onSurface,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AuthUi.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_step + 1}/$_totalSteps',
                                style: const TextStyle(
                                  color: AuthUi.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.06),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey(_step),
                            crossAxisAlignment: _step == 0
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStepTitle(_step),
                                textAlign: _step == 0
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: AuthUi.pageTitle(context).copyWith(
                                  fontSize: isMetricStep ? 22 : 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStepSubtitle(_step),
                                textAlign: _step == 0
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: AuthUi.pageSubtitle(context).copyWith(
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AuthProgressBar(step: _step, totalSteps: _totalSteps),
                      ],
                    ),
                  ),

              // Content Section with better spacing
              Expanded(
                child: AuthStepTransition(
                  animation: _stepTransitionController,
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                    _Step1Content(
                      userId: _userId,
                      email: _email,
                      pass: _pass,
                      confirmPass: _confirmPass,
                      referralCode: _referralCode,
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
                    _StepAgeGenderContent(
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
                    _StepHeightContent(
                      heightInCm: _heightInCm,
                      heightCm: _heightCm,
                      feet: _feet,
                      inch: _inch,
                      onToggleHeightUnit: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _heightInCm = v);
                      },
                      onHeightCm: (v) => setState(() => _heightCm = v),
                      onFeet: (v) => setState(() => _feet = v),
                      onInch: (v) => setState(() => _inch = v),
                    ),
                    _StepWeightContent(
                      weightInKg: _weightInKg,
                      weightKg: _weightKg,
                      weightLbs: _weightLbs,
                      onToggleWeightUnit: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _weightInKg = v);
                      },
                      onWeightKg: (v) => setState(() => _weightKg = v),
                      onWeightLbs: (v) => setState(() => _weightLbs = v),
                    ),
                    _StepRoleContent(
                      role: _role,
                      trainerSpecialties: _trainerSpecialties,
                      nutritionistSpecialties: _nutritionistSpecialties,
                      selectedSpecializations: _selectedSpecializations,
                      customSpecialty: _customSpecialty,
                      onRoleChanged: (r) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (r != _role) {
                            _selectedSpecializations.clear();
                          }
                          _role = r;
                        });
                      },
                      onToggleSpecialization: (s) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_selectedSpecializations.contains(s)) {
                            _selectedSpecializations.remove(s);
                          } else {
                            _selectedSpecializations.add(s);
                          }
                        });
                      },
                      onAddCustomSpecialty: _addCustomSpecialty,
                    ),
                    _StepGoalsContent(
                      goals: _goals,
                      selectedGoals: _selectedGoals,
                      agreedLegal: _agreedLegal,
                      onAgreedLegalChanged: (v) {
                        setState(() => _agreedLegal = v);
                      },
                      onToggleGoal: (g) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_selectedGoals.contains(g) &&
                              _selectedGoals.length > 1) {
                            _selectedGoals.remove(g);
                          } else {
                            _selectedGoals.add(g);
                          }
                        });
                      },
                    ),
                  ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showSlowHint) ...[
                        Text(
                          'Taking a little longer than usual…',
                          style: TextStyle(
                            color: DesignTokens.textSecondaryOf(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      AuthPrimaryButton(
                        label:
                            _step == _lastStepIndex ? 'Create Account' : 'Next',
                        isLoading: _isSubmitting,
                        trailingIcon: _isSubmitting
                            ? null
                            : Icons.arrow_forward_rounded,
                        onPressed: _isSubmitting ? null : _next,
                      ),
                    ],
                  ),
                ),
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

// Step 1: Credentials
class _Step1Content extends StatefulWidget {
  final TextEditingController userId;
  final TextEditingController email;
  final TextEditingController pass;
  final TextEditingController confirmPass;
  final TextEditingController referralCode;
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
    required this.referralCode,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: AuthSectionCard(
        title: 'Account credentials',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            '* Required  ·  (optional) can be skipped',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _TextFieldCard(
            label: 'User ID *',
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
              // Database requirement: A-Za-z0-9_ only, 3-20 chars
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              LengthLimitingTextInputFormatter(20), // Max 20 chars
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
            helperText: widget.userIdAvailabilityStatus == 'taken'
              ? 'Username already taken'
              : widget.userIdAvailabilityStatus == 'error'
              ? 'Unable to check User ID right now. Try again.'
              : widget.userId.text.isNotEmpty && (widget.userId.text.length < 3 || widget.userId.text.length > 20)
              ? 'Must be 3-20 characters'
              : null,
            helperColor: DesignTokens.accentRed,
          ),

          const SizedBox(height: 16),

          _TextFieldCard(
            label: 'Email *',
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

          const SizedBox(height: 16),

          _TextFieldCard(
            label: 'Password *',
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
            label: 'Confirm Password *',
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

          const SizedBox(height: 20),

          _TextFieldCard(
            label: 'Referral Code (optional)',
            controller: widget.referralCode,
            hint: 'Enter a friend\'s code (optional)',
            prefixIcon: Icons.card_giftcard_outlined,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(12),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  text: newValue.text.toUpperCase(),
                  selection: newValue.selection,
                );
              }),
            ],
          ),
        ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: AuthSectionCard(
        title: 'Personal details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _TextFieldCard(
            label: 'First Name (optional)',
            controller: first,
            hint: 'Enter your first name',
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 16),

          _TextFieldCard(
            label: 'Last Name (optional)',
            controller: last,
            hint: 'Enter your last name',
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 16),

          _TextFieldCard(
            label: 'Phone Number (optional)',
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
      ),
    );
  }
}

// Step 3: Age & Gender
class _StepAgeGenderContent extends StatelessWidget {
  static const _genderLabels = ['Male', 'Female', 'Other'];

  final DateTime dob;
  final String gender;
  final ValueChanged<DateTime> onDobChanged;
  final ValueChanged<String> onGenderChanged;

  const _StepAgeGenderContent({
    required this.dob,
    required this.gender,
    required this.onDobChanged,
    required this.onGenderChanged,
  });

  int _genderIndex(String value) {
    switch (value) {
      case 'Female':
        return 1;
      case 'Other':
        return 2;
      default:
        return 0;
    }
  }

  String _genderFromIndex(int index) {
    switch (index) {
      case 1:
        return 'Female';
      case 2:
        return 'Other';
      default:
        return 'Male';
    }
  }

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
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final ageText = _calculateAge(dob);
    final sectionLabel = TextStyle(
      color: textSecondary,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date of birth *', style: sectionLabel),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: AuthPickerFadeMask(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: DesignTokens.accentOrange,
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
          const SizedBox(height: 18),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: DesignTokens.accentOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: DesignTokens.accentOrange.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                'Age: $ageText',
                style: TextStyle(
                  color: DesignTokens.accentOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text('Gender *', style: sectionLabel),
          const SizedBox(height: 16),
          AuthPickerFadeMask(
            child: AuthSidewaysWheelPicker(
              items: _genderLabels,
              selectedIndex: _genderIndex(gender),
              height: 100,
              itemExtent: 96,
              selectedFontSize: 20,
              unselectedFontSize: 16,
              onSelected: (index) => onGenderChanged(_genderFromIndex(index)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

bool _isCompleteMetricInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '.') return false;
  if (trimmed.endsWith('.')) return false;
  return double.tryParse(trimmed) != null;
}

double _roundToDecimals(double value, int decimals) {
  final factor = math.pow(10, decimals).toDouble();
  return (value * factor).round() / factor;
}

// Step 4: Height (full screen + typing)
class _StepHeightContent extends StatefulWidget {
  final bool heightInCm;
  final double heightCm;
  final int feet;
  final int inch;
  final ValueChanged<bool> onToggleHeightUnit;
  final ValueChanged<double> onHeightCm;
  final ValueChanged<int> onFeet;
  final ValueChanged<int> onInch;

  const _StepHeightContent({
    required this.heightInCm,
    required this.heightCm,
    required this.feet,
    required this.inch,
    required this.onToggleHeightUnit,
    required this.onHeightCm,
    required this.onFeet,
    required this.onInch,
  });

  @override
  State<_StepHeightContent> createState() => _StepHeightContentState();
}

class _StepHeightContentState extends State<_StepHeightContent> {
  late FixedExtentScrollController _heightCmController;
  late FixedExtentScrollController _feetController;
  late FixedExtentScrollController _inchController;
  late TextEditingController _cmTextController;
  late TextEditingController _feetTextController;
  late TextEditingController _inchTextController;
  bool _syncingFromPicker = false;

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
    _cmTextController = TextEditingController(
      text: widget.heightCm.round().toString(),
    );
    _feetTextController = TextEditingController(text: '${widget.feet}');
    _inchTextController = TextEditingController(text: '${widget.inch}');
  }

  @override
  void didUpdateWidget(covariant _StepHeightContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_syncingFromPicker) return;
    if (oldWidget.heightInCm != widget.heightInCm) {
      if (widget.heightInCm) {
        _syncCmTextFromValue(widget.heightCm);
        _syncCmPicker(widget.heightCm);
      } else {
        _feetTextController.text = '${widget.feet}';
        _inchTextController.text = '${widget.inch}';
        _syncImperialPickers(widget.feet, widget.inch);
      }
      return;
    }
    if (oldWidget.heightCm != widget.heightCm && widget.heightInCm) {
      _syncCmTextFromValue(widget.heightCm);
      _syncCmPicker(widget.heightCm);
    }
    if ((oldWidget.feet != widget.feet || oldWidget.inch != widget.inch) &&
        !widget.heightInCm) {
      _feetTextController.text = '${widget.feet}';
      _inchTextController.text = '${widget.inch}';
      _syncImperialPickers(widget.feet, widget.inch);
    }
  }

  void _syncCmTextFromValue(double cm) {
    _cmTextController.text = cm.round().toString();
  }

  void _syncCmPicker(double cm) {
    final snapped = cm.round().clamp(80, 230);
    _syncingFromPicker = true;
    if (_heightCmController.hasClients) {
      _heightCmController.jumpToItem((snapped - 80).clamp(0, 150));
    }
    _syncingFromPicker = false;
  }

  void _syncImperialPickers(int feet, int inch) {
    _syncingFromPicker = true;
    if (_feetController.hasClients) {
      _feetController.jumpToItem((feet - 3).clamp(0, 5));
    }
    if (_inchController.hasClients) {
      _inchController.jumpToItem(inch.clamp(0, 11));
    }
    _syncingFromPicker = false;
  }

  @override
  void dispose() {
    _heightCmController.dispose();
    _feetController.dispose();
    _inchController.dispose();
    _cmTextController.dispose();
    _feetTextController.dispose();
    _inchTextController.dispose();
    super.dispose();
  }

  void _applyCmFromText(String raw) {
    if (!_isCompleteMetricInput(raw)) return;
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) return;
    final snapped = parsed.round().clamp(80, 230).toDouble();
    widget.onHeightCm(snapped);
    final totalInches = (snapped / 2.54).round();
    widget.onFeet((totalInches / 12).floor().clamp(3, 8));
    widget.onInch((totalInches % 12).clamp(0, 11));
    _syncCmPicker(snapped);
    _cmTextController.text = snapped.toStringAsFixed(0);
  }

  void _applyImperialFromText() {
    final ft = int.tryParse(_feetTextController.text.trim());
    final inch = int.tryParse(_inchTextController.text.trim());
    if (ft == null || inch == null) return;
    final feet = ft.clamp(3, 8);
    final inches = inch.clamp(0, 11);
    widget.onFeet(feet);
    widget.onInch(inches);
    final cm = ((feet * 30.48) + (inches * 2.54)).clamp(80.0, 230.0);
    widget.onHeightCm(_roundToDecimals(cm, 1));
    _syncImperialPickers(feet, inches);
    _syncCmPicker(cm);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Height *',
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _UnitToggle(
              left: 'cm',
              right: 'ft/in',
              isLeft: widget.heightInCm,
              onChanged: widget.onToggleHeightUnit,
            ),
          ),
          const SizedBox(height: 20),
          if (widget.heightInCm)
            _MetricTextField(
              controller: _cmTextController,
              suffix: 'cm',
              hint: '170',
              allowDecimal: true,
              onSubmitted: _applyCmFromText,
              onChanged: _applyCmFromText,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _MetricTextField(
                    controller: _feetTextController,
                    suffix: 'ft',
                    hint: '5',
                    onSubmitted: (_) => _applyImperialFromText(),
                    onChanged: (_) => _applyImperialFromText(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTextField(
                    controller: _inchTextController,
                    suffix: 'in',
                    hint: '7',
                    onSubmitted: (_) => _applyImperialFromText(),
                    onChanged: (_) => _applyImperialFromText(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Type a value or scroll below',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.heightInCm
                ? _PickerFadeWrapper(
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        primaryColor: DesignTokens.accentOrange,
                        textTheme: CupertinoTextThemeData(
                          pickerTextStyle: TextStyle(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: _LoopingPicker(
                        scrollController: _heightCmController,
                        itemExtent: 48,
                        itemCount: 151,
                        initialIndex: (widget.heightCm - 80).round().clamp(0, 150),
                        onSelectedItemChanged: (index) {
                          if (_syncingFromPicker) return;
                          HapticFeedback.selectionClick();
                          final newHeightCm = (80 + (index % 151)).toDouble();
                          widget.onHeightCm(newHeightCm);
                          _cmTextController.text = newHeightCm.toStringAsFixed(0);
                          final totalInches = (newHeightCm / 2.54).round();
                          widget.onFeet((totalInches / 12).floor().clamp(3, 8));
                          widget.onInch((totalInches % 12).clamp(0, 11));
                        },
                        builder: (context, index) {
                          final value = 80 + (index % 151);
                          final isSelected = value == widget.heightCm.round();
                          return Center(
                            child: Text(
                              '$value cm',
                              style: TextStyle(
                                color: isSelected
                                    ? DesignTokens.accentOrange
                                    : textPrimary.withValues(alpha: 0.55),
                                fontSize: isSelected ? 24 : 18,
                                fontWeight:
                                    isSelected ? FontWeight.w800 : FontWeight.w500,
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
                        child: _PickerFadeWrapper(
                          child: CupertinoTheme(
                            data: CupertinoThemeData(
                              brightness: Theme.of(context).brightness,
                              primaryColor: DesignTokens.accentOrange,
                              textTheme: CupertinoTextThemeData(
                                pickerTextStyle: TextStyle(
                                  color: textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            child: _LoopingPicker(
                              scrollController: _feetController,
                              itemExtent: 48,
                              itemCount: 6,
                              initialIndex: (widget.feet - 3).clamp(0, 5),
                              onSelectedItemChanged: (index) {
                                if (_syncingFromPicker) return;
                                HapticFeedback.selectionClick();
                                widget.onFeet(3 + (index % 6));
                                _feetTextController.text = '${3 + (index % 6)}';
                                _applyImperialFromText();
                              },
                              builder: (context, index) {
                                final value = 3 + (index % 6);
                                final isSelected = value == widget.feet;
                                return Center(
                                  child: Text(
                                    '$value ft',
                                    style: TextStyle(
                                      color: isSelected
                                          ? DesignTokens.accentOrange
                                          : textPrimary.withValues(alpha: 0.55),
                                      fontSize: isSelected ? 24 : 18,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: borderColor),
                      Expanded(
                        child: _PickerFadeWrapper(
                          child: CupertinoTheme(
                            data: CupertinoThemeData(
                              brightness: Theme.of(context).brightness,
                              primaryColor: DesignTokens.accentOrange,
                              textTheme: CupertinoTextThemeData(
                                pickerTextStyle: TextStyle(
                                  color: textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            child: _LoopingPicker(
                              scrollController: _inchController,
                              itemExtent: 48,
                              itemCount: 12,
                              initialIndex: widget.inch.clamp(0, 11),
                              onSelectedItemChanged: (index) {
                                if (_syncingFromPicker) return;
                                HapticFeedback.selectionClick();
                                widget.onInch(index % 12);
                                _inchTextController.text = '${index % 12}';
                                _applyImperialFromText();
                              },
                              builder: (context, index) {
                                final value = index % 12;
                                final isSelected = value == widget.inch;
                                return Center(
                                  child: Text(
                                    '$value in',
                                    style: TextStyle(
                                      color: isSelected
                                          ? DesignTokens.accentOrange
                                          : textPrimary.withValues(alpha: 0.55),
                                      fontSize: isSelected ? 24 : 18,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
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
        ],
      ),
    );
  }
}

// Step 6: Weight
class _StepWeightContent extends StatefulWidget {
  final bool weightInKg;
  final double weightKg;
  final double weightLbs;
  final ValueChanged<bool> onToggleWeightUnit;
  final ValueChanged<double> onWeightKg;
  final ValueChanged<double> onWeightLbs;

  const _StepWeightContent({
    required this.weightInKg,
    required this.weightKg,
    required this.weightLbs,
    required this.onToggleWeightUnit,
    required this.onWeightKg,
    required this.onWeightLbs,
  });

  @override
  State<_StepWeightContent> createState() => _StepWeightContentState();
}

class _StepWeightContentState extends State<_StepWeightContent> {
  late FixedExtentScrollController _weightKgController;
  late FixedExtentScrollController _weightLbsController;
  late TextEditingController _weightTextController;
  late int _selectedWeightKgIndex;
  late int _selectedWeightLbsIndex;
  bool _syncingFromPicker = false;

  @override
  void initState() {
    super.initState();
    _selectedWeightKgIndex = ((widget.weightKg - 35) / 0.1).round().clamp(0, 1150);
    _weightKgController = FixedExtentScrollController(
      initialItem: _selectedWeightKgIndex,
    );
    _selectedWeightLbsIndex = ((widget.weightLbs - 77) / 0.1).round().clamp(0, 2530);
    _weightLbsController = FixedExtentScrollController(
      initialItem: _selectedWeightLbsIndex,
    );
    _weightTextController = TextEditingController(
      text: widget.weightInKg
          ? widget.weightKg.toStringAsFixed(1)
          : widget.weightLbs.toStringAsFixed(1),
    );
  }

  @override
  void didUpdateWidget(covariant _StepWeightContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_syncingFromPicker) return;
    if (oldWidget.weightInKg != widget.weightInKg) {
      _syncWeightTextFromValue();
      return;
    }
    if (widget.weightInKg && oldWidget.weightKg != widget.weightKg) {
      _syncWeightTextFromValue();
      _syncKgPicker(widget.weightKg);
    }
    if (!widget.weightInKg && oldWidget.weightLbs != widget.weightLbs) {
      _syncWeightTextFromValue();
      _syncLbsPicker(widget.weightLbs);
    }
  }

  void _syncWeightTextFromValue() {
    final value = widget.weightInKg ? widget.weightKg : widget.weightLbs;
    _weightTextController.text = _roundToDecimals(value, 1).toStringAsFixed(1);
  }

  void _syncKgPicker(double kg) {
    _selectedWeightKgIndex =
        ((_roundToDecimals(kg, 1) - 35) * 10).round().clamp(0, 1150);
    _syncingFromPicker = true;
    if (_weightKgController.hasClients) {
      _weightKgController.jumpToItem(_selectedWeightKgIndex);
    }
    _syncingFromPicker = false;
  }

  void _syncLbsPicker(double lbs) {
    _selectedWeightLbsIndex =
        ((_roundToDecimals(lbs, 1) - 77) * 10).round().clamp(0, 2530);
    _syncingFromPicker = true;
    if (_weightLbsController.hasClients) {
      _weightLbsController.jumpToItem(_selectedWeightLbsIndex);
    }
    _syncingFromPicker = false;
  }

  @override
  void dispose() {
    _weightKgController.dispose();
    _weightLbsController.dispose();
    _weightTextController.dispose();
    super.dispose();
  }

  void _applyWeightFromText(String raw) {
    if (!_isCompleteMetricInput(raw)) return;
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) return;
    if (widget.weightInKg) {
      final kg = _roundToDecimals(parsed.clamp(35.0, 150.0), 1);
      final lbs = _roundToDecimals(kg * 2.2046226218, 1);
      widget.onWeightKg(kg);
      widget.onWeightLbs(lbs);
      _syncKgPicker(kg);
      _syncLbsPicker(lbs);
      _weightTextController.text = kg.toStringAsFixed(1);
    } else {
      final lbs = _roundToDecimals(parsed.clamp(77.0, 330.0), 1);
      final kg = _roundToDecimals(lbs * 0.45359237, 1);
      widget.onWeightLbs(lbs);
      widget.onWeightKg(kg);
      _syncLbsPicker(lbs);
      _syncKgPicker(kg);
      _weightTextController.text = lbs.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Weight *',
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _UnitToggle(
              left: 'kg',
              right: 'lbs',
              isLeft: widget.weightInKg,
              onChanged: (isKg) {
                widget.onToggleWeightUnit(isKg);
                _syncWeightTextFromValue();
                if (isKg) {
                  _syncKgPicker(widget.weightKg);
                } else {
                  _syncLbsPicker(widget.weightLbs);
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          _MetricTextField(
            controller: _weightTextController,
            suffix: widget.weightInKg ? 'kg' : 'lbs',
            hint: widget.weightInKg ? '70.0' : '154.0',
            allowDecimal: true,
            onSubmitted: _applyWeightFromText,
            onChanged: _applyWeightFromText,
          ),
          const SizedBox(height: 8),
          Text(
            'Type a value or scroll below',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _PickerFadeWrapper(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: DesignTokens.accentOrange,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: widget.weightInKg
                    ? _LoopingPicker(
                        scrollController: _weightKgController,
                        itemExtent: 48,
                        itemCount: 1151,
                        initialIndex: _selectedWeightKgIndex,
                        onSelectedItemChanged: (index) {
                          if (_syncingFromPicker) return;
                          final actualIndex = index % 1151;
                          setState(() {
                            _selectedWeightKgIndex = actualIndex;
                          });
                          HapticFeedback.selectionClick();
                          final newWeightKg =
                              _roundToDecimals(35.0 + actualIndex * 0.1, 1);
                          final newWeightLbs =
                              _roundToDecimals(newWeightKg * 2.2046226218, 1);
                          widget.onWeightKg(newWeightKg);
                          widget.onWeightLbs(newWeightLbs);
                          _weightTextController.text =
                              newWeightKg.toStringAsFixed(1);
                        },
                        builder: (context, index) {
                          final actualIndex = index % 1151;
                          final value =
                              (35 + actualIndex * 0.1).toStringAsFixed(1);
                          final isSelected =
                              actualIndex == _selectedWeightKgIndex;
                          return Center(
                            child: Text(
                              '$value kg',
                              style: TextStyle(
                                color: isSelected
                                    ? DesignTokens.accentOrange
                                    : textPrimary.withValues(alpha: 0.55),
                                fontSize: isSelected ? 24 : 18,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      )
                    : _LoopingPicker(
                        scrollController: _weightLbsController,
                        itemExtent: 48,
                        itemCount: 2531,
                        initialIndex: _selectedWeightLbsIndex,
                        onSelectedItemChanged: (index) {
                          if (_syncingFromPicker) return;
                          final actualIndex = index % 2531;
                          setState(() {
                            _selectedWeightLbsIndex = actualIndex;
                          });
                          HapticFeedback.selectionClick();
                          final newWeightLbs =
                              _roundToDecimals(77.0 + actualIndex * 0.1, 1);
                          final newWeightKg =
                              _roundToDecimals(newWeightLbs * 0.45359237, 1);
                          widget.onWeightLbs(newWeightLbs);
                          widget.onWeightKg(newWeightKg);
                          _weightTextController.text =
                              newWeightLbs.toStringAsFixed(1);
                        },
                        builder: (context, index) {
                          final actualIndex = index % 2531;
                          final value =
                              (77 + actualIndex * 0.1).toStringAsFixed(1);
                          final isSelected =
                              actualIndex == _selectedWeightLbsIndex;
                          return Center(
                            child: Text(
                              '$value lbs',
                              style: TextStyle(
                                color: isSelected
                                    ? DesignTokens.accentOrange
                                    : textPrimary.withValues(alpha: 0.55),
                                fontSize: isSelected ? 24 : 18,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
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

// Step 6: Role & provider specialties
class _StepRoleContent extends StatelessWidget {
  final String role;
  final List<ProviderSpecialty> trainerSpecialties;
  final List<ProviderSpecialty> nutritionistSpecialties;
  final Set<String> selectedSpecializations;
  final TextEditingController customSpecialty;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onToggleSpecialization;
  final VoidCallback onAddCustomSpecialty;

  const _StepRoleContent({
    required this.role,
    required this.trainerSpecialties,
    required this.nutritionistSpecialties,
    required this.selectedSpecializations,
    required this.customSpecialty,
    required this.onRoleChanged,
    required this.onToggleSpecialization,
    required this.onAddCustomSpecialty,
  });

  @override
  Widget build(BuildContext context) {
    final isProvider = role == 'Trainer' || role == 'Nutritionist';
    final specialtyOptions =
        role == 'Trainer' ? trainerSpecialties : nutritionistSpecialties;
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your role *',
            style: TextStyle(
              color: DesignTokens.textPrimaryOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.person_outline_rounded,
            title: 'Client',
            subtitle: 'Find trainers, log workouts, and track nutrition',
            isSelected: role == 'Client',
            onTap: () => onRoleChanged('Client'),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.fitness_center_rounded,
            title: 'Trainer',
            subtitle: 'Coach clients, schedule sessions, and grow your brand',
            isSelected: role == 'Trainer',
            onTap: () => onRoleChanged('Trainer'),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.restaurant_rounded,
            title: 'Nutritionist',
            subtitle: 'Create meal plans and guide clients on nutrition',
            isSelected: role == 'Nutritionist',
            onTap: () => onRoleChanged('Nutritionist'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            child: isProvider
                ? Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: AuthSectionCard(
                      title: role == 'Trainer'
                          ? 'Your specialties *'
                          : 'Your focus areas *',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role == 'Trainer'
                                ? 'Required — pick at least one specialty.'
                                : 'Required — pick at least one focus area.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...specialtyOptions.map((item) {
                                final isSelected =
                                    selectedSpecializations.contains(item.id);
                                return _GoalChip(
                                  label: item.label,
                                  isSelected: isSelected,
                                  onTap: () => onToggleSpecialization(item.id),
                                );
                              }),
                              ...selectedSpecializations
                                  .where(
                                    (s) => !specialtyOptions
                                        .any((opt) => opt.id == s),
                                  )
                                  .map(
                                    (item) => _GoalChip(
                                      label: ProviderSpecialtyTaxonomy
                                          .labelFor(item),
                                      isSelected: true,
                                      onTap: () =>
                                          onToggleSpecialization(item),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: AuthTapToTypeField(
                                  controller: customSpecialty,
                                  style: AuthUi.fieldTextStyle(
                                    context,
                                    large: true,
                                  ).copyWith(
                                    color: DesignTokens.textPrimaryOf(context),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: role == 'Trainer'
                                        ? 'Add custom (e.g. CrossFit)'
                                        : 'Add custom (e.g. Gut Health)',
                                    hintStyle: TextStyle(
                                      color: textSecondary,
                                      fontSize: 15,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.04),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: DesignTokens.accentOrange,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                  ),
                                  onChanged: (_) {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              Material(
                                color: DesignTokens.accentOrange,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: onAddCustomSpecialty,
                                  borderRadius: BorderRadius.circular(14),
                                  child: const SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// Step 7: Fitness goals
class _StepGoalsContent extends StatelessWidget {
  final List<String> goals;
  final Set<String> selectedGoals;
  final ValueChanged<String> onToggleGoal;
  final bool agreedLegal;
  final ValueChanged<bool> onAgreedLegalChanged;

  const _StepGoalsContent({
    required this.goals,
    required this.selectedGoals,
    required this.onToggleGoal,
    required this.agreedLegal,
    required this.onAgreedLegalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DesignTokens.accentOrange.withValues(alpha: 0.16),
                  AccountHubTheme.cardBg(context),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DesignTokens.accentOrange.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: DesignTokens.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick your goals *',
                        style: TextStyle(
                          color: DesignTokens.textPrimaryOf(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Required — choose at least one. You can change these later.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Selected',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DesignTokens.accentOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${selectedGoals.length}',
                  style: const TextStyle(
                    color: DesignTokens.accentOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AuthSectionCard(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.35,
              ),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final isSelected = selectedGoals.contains(goal);
                return _GoalTile(
                  label: goal,
                  isSelected: isSelected,
                  onTap: () => onToggleGoal(goal),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: agreedLegal,
                activeColor: DesignTokens.accentOrange,
                onChanged: (v) => onAgreedLegalChanged(v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'I agree to the ',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TermsOfServicePage(),
                          ),
                        ),
                        child: Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: DesignTokens.accentOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        ),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: DesignTokens.accentOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
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

class _GoalTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? DesignTokens.primaryGradient : null,
          color: isSelected ? null : DesignTokens.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : DesignTokens.borderColorOf(context),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : textPrimary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
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
  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthTapToTypeField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onChanged: (value) {
            widget.onChanged?.call(value);
            setState(() {});
          },
          style: AuthUi.fieldTextStyle(context, large: true).copyWith(
            color: textPrimary,
          ),
          decoration: AuthUi.fieldDecoration(
            context,
            large: true,
            label: widget.label,
            hint: widget.hint,
            prefix: widget.prefix,
            prefixIcon: widget.prefix == null
                ? Icon(widget.prefixIcon, color: textSecondary, size: 22)
                : null,
            suffixIcon: widget.suffix,
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

class _MetricTextField extends StatefulWidget {
  final TextEditingController controller;
  final String suffix;
  final String hint;
  final bool allowDecimal;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _MetricTextField({
    required this.controller,
    required this.suffix,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    this.allowDecimal = false,
  });

  @override
  State<_MetricTextField> createState() => _MetricTextFieldState();
}

class _MetricTextFieldState extends State<_MetricTextField> {
  final _focusNode = FocusNode();
  bool _keyboardEnabled = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _enableKeyboard() {
    if (_keyboardEnabled) return;
    setState(() => _keyboardEnabled = true);
    Future.microtask(() => _focusNode.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final hintText =
        _keyboardEnabled ? widget.hint : '${widget.hint} · tap';

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      readOnly: !_keyboardEnabled,
      showCursor: _keyboardEnabled,
      enableInteractiveSelection: _keyboardEnabled,
      onTap: _enableKeyboard,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(widget.allowDecimal ? r'^\d*\.?\d*' : r'\d*'),
        ),
      ],
      textAlign: TextAlign.center,
      style: TextStyle(
        color: textPrimary,
        fontSize: 42,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.1,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: textPrimary.withValues(alpha: 0.25),
          fontSize: _keyboardEnabled ? 42 : 28,
          fontWeight: FontWeight.w800,
        ),
        suffixText: widget.suffix,
        suffixStyle: TextStyle(
          color: DesignTokens.accentOrange,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: DesignTokens.surfaceOf(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: DesignTokens.accentOrange,
            width: 2,
          ),
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: () => widget.onSubmitted(widget.controller.text),
    );
  }
}

class _PickerFadeWrapper extends StatelessWidget {
  final Widget child;

  const _PickerFadeWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.12, 0.88, 1.0],
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.accentOrange.withValues(alpha: 0.1)
              : surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? DesignTokens.accentOrange : borderColor,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isSelected ? DesignTokens.primaryGradient : null,
                color: isSelected
                    ? null
                    : textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? Colors.white : textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected ? DesignTokens.primaryGradient : null,
                color: isSelected ? null : Colors.transparent,
                border: isSelected
                    ? null
                    : Border.all(color: borderColor, width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.accentOrange.withValues(alpha: 0.12)
              : surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? DesignTokens.accentOrange : borderColor,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? DesignTokens.accentOrange.withValues(alpha: 0.18)
                    : textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? DesignTokens.accentOrange : textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? DesignTokens.accentOrange
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? DesignTokens.accentOrange
                      : borderColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                  : null,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: textPrimary.withOpacity(0.5),
                  fontSize: 16,
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

