import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_deep_link.dart';
import '../../core/auth/signup_error_mapper.dart';
import '../../core/auth/signup_mode.dart';
import '../../core/auth/username_availability.dart';
import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_ui.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../widgets/auth/onboarding_role_goals.dart';
import '../../widgets/auth/onboarding_shell.dart';
import '../../widgets/auth/onboarding_success.dart';
import '../../services/user_goals_service.dart';
import '../../services/pending_referral_service.dart';
import '../../repositories/referral_repository.dart';
import '../../models/fitness_goal_taxonomy.dart';
import '../../models/onboarding_specialty_options.dart';
import '../../pages/profile/settings/info_pages.dart';

class SignupWizardPage extends StatefulWidget {
  const SignupWizardPage({
    super.key,
    this.initialReferralCode,
    this.mode = SignupMode.email,
  });

  final String? initialReferralCode;
  final SignupMode mode;

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
  UsernameAvailabilityStatus _userIdAvailabilityStatus =
      UsernameAvailabilityStatus.empty;
  bool _isCheckingUserId = false;
  String? _lastAvailableNormalized;
  Timer? _userIdDebounce;
  String? _emailValidationStatus; // 'valid', 'invalid', null — never live-available
  bool _emailConflict = false;
  bool _agreedLegal = false;
  bool _showAllSet = false;
  bool _transitionForward = true;
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
  final Set<String> _selectedGoalIds = {'lose_weight'};
  String _role = 'Client';
  final Set<String> _selectedSpecialtyIds = {};
  final _customSpecialty = TextEditingController();

  bool _isSubmitting = false;
  bool _referralApplied = false; // Guard: prevent double apply_referral_code

  bool get _isSocial => widget.mode == SignupMode.social;

  late final AnimationController _fadeController;
  late final AnimationController _stepTransitionController;

  @override
  void initState() {
    super.initState();
    _initReferralCode();
    if (_isSocial) unawaited(_prefillSocialIdentity());
    unawaited(_loadLegalVersions());
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _stepTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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

  Future<void> _prefillSocialIdentity() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) {
      _email.text = email;
      _emailValidationStatus = 'valid';
    }
    final meta = user?.userMetadata ?? {};
    final given = meta['given_name']?.toString().trim() ?? '';
    final family = meta['family_name']?.toString().trim() ?? '';
    if (given.isNotEmpty) _first.text = given;
    if (family.isNotEmpty) _last.text = family;
    if (_first.text.isEmpty && _last.text.isEmpty) {
      final full = (meta['full_name'] ?? meta['name'])?.toString().trim() ?? '';
      if (full.isNotEmpty) {
        final parts = full.split(RegExp(r'\s+'));
        _first.text = parts.first;
        if (parts.length > 1) _last.text = parts.sublist(1).join(' ');
      }
    }
    try {
      final raw = await supabase
          .rpc('get_my_profile')
          .timeout(const Duration(seconds: 15));
      Map<String, dynamic>? profile;
      if (raw is List && raw.isNotEmpty) {
        profile = Map<String, dynamic>.from(raw.first as Map);
      } else if (raw is Map) {
        profile = Map<String, dynamic>.from(raw);
      }
      final existing = profile?['username']?.toString().trim() ?? '';
      if (existing.isNotEmpty && mounted) {
        _userId.text = existing;
        _userIdAvailabilityStatus = UsernameAvailabilityStatus.available;
        _lastAvailableNormalized =
            UsernameAvailability.normalize(_userId.text).toLowerCase();
      }
    } catch (_) {}
    if (mounted) setState(() {});
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
    _userIdDebounce?.cancel();
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

  Future<bool> _validateStep1() async {
    final userIdText = UsernameAvailability.normalize(_userId.text);
    if (userIdText.isEmpty) {
      setState(() => _userIdAvailabilityStatus = UsernameAvailabilityStatus.invalid);
      return false;
    }
    if (!UsernameAvailability.isValidFormat(userIdText)) {
      setState(() => _userIdAvailabilityStatus = UsernameAvailabilityStatus.invalid);
      return false;
    }
    final changedSinceCheck =
        _lastAvailableNormalized != userIdText.toLowerCase();
    if (changedSinceCheck ||
        _userIdAvailabilityStatus != UsernameAvailabilityStatus.available) {
      await _checkUserIdAvailability(userIdText);
    }
    if (_userIdAvailabilityStatus == UsernameAvailabilityStatus.error) {
      return false;
    }
    if (_userIdAvailabilityStatus != UsernameAvailabilityStatus.available) {
      return false;
    }

    if (_isSocial) {
      return true;
    }

    if (_email.text.trim().isEmpty) {
      setState(() => _emailValidationStatus = 'invalid');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_email.text.trim())) {
      setState(() => _emailValidationStatus = 'invalid');
      return false;
    }
    if (_emailConflict) {
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

  void _onUserIdChanged(String raw) {
    final normalized = UsernameAvailability.normalize(raw);
    _userIdDebounce?.cancel();
    setState(() {
      if (normalized.isEmpty) {
        _userIdAvailabilityStatus = UsernameAvailabilityStatus.empty;
        _isCheckingUserId = false;
        return;
      }
      if (!UsernameAvailability.isValidFormat(normalized)) {
        _userIdAvailabilityStatus = UsernameAvailabilityStatus.invalid;
        _isCheckingUserId = false;
        return;
      }
      _userIdAvailabilityStatus = UsernameAvailabilityStatus.checking;
      _isCheckingUserId = true;
    });
    if (!UsernameAvailability.isValidFormat(normalized)) return;
    _userIdDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkUserIdAvailability(normalized));
    });
  }

  Future<void> _checkUserIdAvailability(String userId) async {
    final normalized = UsernameAvailability.normalize(userId);
    if (normalized.isEmpty || !UsernameAvailability.isValidFormat(normalized)) {
      if (!mounted) return;
      setState(() {
        _userIdAvailabilityStatus = normalized.isEmpty
            ? UsernameAvailabilityStatus.empty
            : UsernameAvailabilityStatus.invalid;
        _isCheckingUserId = false;
      });
      return;
    }

    setState(() {
      _isCheckingUserId = true;
      _userIdAvailabilityStatus = UsernameAvailabilityStatus.checking;
    });

    try {
      final available = await Supabase.instance.client
          .rpc(
            'is_username_available',
            params: {'p_username': normalized},
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final status = UsernameAvailability.fromRpc(available);
      setState(() {
        _userIdAvailabilityStatus = status;
        _isCheckingUserId = false;
        _lastAvailableNormalized =
            status == UsernameAvailabilityStatus.available
                ? normalized.toLowerCase()
                : null;
      });
    } catch (_) {
      // Fail closed: never treat RPC failure as available.
      if (!mounted) return;
      setState(() {
        _userIdAvailabilityStatus = UsernameAvailabilityStatus.error;
        _isCheckingUserId = false;
        _lastAvailableNormalized = null;
      });
    }
  }

  void _onEmailChanged(String email) {
    final emailTrimmed = email.trim();
    setState(() => _emailConflict = false);

    if (emailTrimmed.isEmpty) {
      setState(() => _emailValidationStatus = null);
      return;
    }

    final isValidFormat =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailTrimmed);
    setState(() {
      _emailValidationStatus = isValidFormat ? 'valid' : 'invalid';
    });
  }

  bool _validateRoleStep() {
    if (_role == 'Trainer' || _role == 'Nutritionist') {
      if (_selectedSpecialtyIds.isEmpty) {
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
      if (OnboardingSpecialtyOptions.otherSelected(_selectedSpecialtyIds) &&
          _customSpecialty.text.trim().isEmpty &&
          _selectedSpecialtyIds.length == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your specialty')),
        );
        return false;
      }
    }
    return true;
  }

  bool _validateGoalsStep() {
    if (_selectedGoalIds.isEmpty) {
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

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _next() async {
    if (_isSubmitting) return;

    if (_step == 0 && !await _validateStep1()) {
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
      _stepTransitionController.value = 0;
      setState(() {
        _transitionForward = true;
        _step++;
      });
      _page.jumpToPage(_step);
      await _stepTransitionController.forward();
    } else {
      await _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      _dismissKeyboard();
      _stepTransitionController.value = 0;
      setState(() {
        _transitionForward = false;
        _step--;
      });
      _page.jumpToPage(_step);
      _stepTransitionController.forward();
    } else if (context.canPop()) {
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

      final username = UsernameAvailability.normalize(_userId.text);
      if (username.isEmpty) {
        throw Exception('Username is required');
      }
      if (_lastAvailableNormalized != username.toLowerCase()) {
        await _checkUserIdAvailability(username);
        if (_userIdAvailabilityStatus !=
            UsernameAvailabilityStatus.available) {
          return;
        }
      }

      final phoneDigits = _phone.text.trim();
      final phone =
          phoneDigits.isEmpty ? null : '${_phoneCountryCode}$phoneDigits';

      final fullName = '${_first.text.trim()} ${_last.text.trim()}'.trim();
      final goals = FitnessGoalTaxonomy.toStorage(_selectedGoalIds);
      final role = _role.toLowerCase();
      final specialization = (_role == 'Trainer' || _role == 'Nutritionist')
          ? OnboardingSpecialtyOptions.persistSelection(
              role: _role,
              selectedIds: _selectedSpecialtyIds,
              otherText: _customSpecialty.text,
            )
          : <String>[];

      if (_isSocial) {
        await _finalizeSocial(
          supabase: supabase,
          username: username,
          fullName: fullName,
          phone: phone,
          heightCm: heightCm,
          weightKg: weightKg,
          weightKgRaw: weightKgRaw,
          role: role,
          goals: goals,
          specialization: specialization,
        );
        return;
      }

      final signUpData = <String, dynamic>{
        'username': username,
        'full_name': fullName,
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        if (phone != null) 'phone': phone,
        'dob': _formatDob(_dob),
        'gender': _gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'bmi': double.parse(_bmi.toStringAsFixed(2)),
        'goals': goals,
        'role': role,
        'terms_version': _termsVersion,
        'privacy_version': _privacyVersion,
      };

      if (specialization.isNotEmpty) {
        signUpData['specialization'] = specialization;
      }

      final response = await supabase.auth
          .signUp(
            email: _email.text.trim(),
            password: _pass.text,
            data: signUpData,
            emailRedirectTo: AuthDeepLink.callback,
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
                    'specialization': specialization,
                  })
                  .timeout(const Duration(seconds: 15));
            } catch (_) {
              // Non-fatal: handle_new_user trigger may have created the row
            }
          }

          if (!mounted) return;
          setState(() => _showAllSet = true);
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
      final mapped = SignupErrorMapper.map(e);
      if (mapped == SignupErrorMapper.emailConflict) {
        setState(() {
          _emailConflict = true;
          _step = 0;
        });
        _page.jumpToPage(0);
        return;
      }
      if (mapped == SignupErrorMapper.usernameTaken) {
        setState(() {
          _userIdAvailabilityStatus = UsernameAvailabilityStatus.taken;
          _lastAvailableNormalized = null;
          _step = 0;
        });
        _page.jumpToPage(0);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mapped.display),
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

  Future<void> _finalizeSocial({
    required SupabaseClient supabase,
    required String username,
    required String fullName,
    required String? phone,
    required int heightCm,
    required double weightKg,
    required double weightKgRaw,
    required String role,
    required List<String> goals,
    required List<String> specialization,
  }) async {
    if (supabase.auth.currentSession == null) {
      throw Exception('Not authenticated');
    }

    await supabase
        .rpc(
          'complete_cotrainr_profile',
          params: {
            'p_username': username,
            'p_role': role,
            'p_full_name': fullName.isEmpty ? null : fullName,
            'p_phone': phone,
            'p_dob': _formatDob(_dob),
            'p_gender': _gender,
            'p_height_cm': heightCm,
            'p_weight_kg': weightKg,
            'p_specialization':
                specialization.isEmpty ? null : specialization,
            'p_terms_version': _termsVersion,
            'p_privacy_version': _privacyVersion,
            'p_goals': goals,
          },
        )
        .timeout(const Duration(seconds: 15));

    if (!mounted) return;

    try {
      final goalsService = UserGoalsService();
      await goalsService.initializeGoals(weightKg: weightKgRaw);
    } catch (_) {}

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
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                ),
              ),
            );
          }
        }
      }
      await referralRepo.generateReferralCode();
      await PendingReferralService.clearPendingCode();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _showAllSet = true);
  }

  Future<void> _leaveAllSet() async {
    if (!mounted) return;
    context.go('/auth/permissions', extra: {'role': _role.toLowerCase()});
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
        return 'Your Goal';
      default:
        return 'Create Account';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0:
        return 'Start training, tracking and transforming.';
      case 1:
        return "Let's make this yours.";
      case 2:
        return 'A few details help us personalise Cotrainr.';
      case 3:
        return 'Set your height.';
      case 4:
        return 'Set your current weight.';
      case 5:
        return 'How will you use Cotrainr?';
      case 6:
        return 'What are you training toward?';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = AuthUi.pageBg(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AuthTheme.overlay(context),
      child: PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: true,
        body: _showAllSet
            ? OnboardingAllSetView(onContinue: () => unawaited(_leaveAllSet()))
            : AuthScreenBackground.onboarding(
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Column(
                children: [
                  OnboardingHeader(
                    title: _getStepTitle(_step),
                    subtitle: _getStepSubtitle(_step),
                    step: _step,
                    totalSteps: _totalSteps,
                    centerAlign: _step == 0,
                    afterProgress: (_step == 3 || _step == 4)
                        ? onboardingMeasureControlGap(context)
                        : (_step == 0 ? 12 : 8),
                  ),

              Expanded(
                child: AuthStepTransition(
                  animation: _stepTransitionController,
                  forward: _transitionForward,
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
                      onUserIdChanged: _onUserIdChanged,
                      emailValidationStatus: _emailValidationStatus,
                      emailConflict: _emailConflict,
                      onEmailChanged: _onEmailChanged,
                      onSignInInstead: () => context.go('/auth/login'),
                      isSocial: _isSocial,
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
                    OnboardingRoleStep(
                      role: _role,
                      selectedSpecialtyIds: _selectedSpecialtyIds,
                      customSpecialty: _customSpecialty,
                      onRoleChanged: (r) {
                        setState(() {
                          if (r != _role) {
                            _selectedSpecialtyIds.clear();
                            _customSpecialty.clear();
                          }
                          _role = r;
                        });
                      },
                      onToggleSpecialty: (id) {
                        setState(() {
                          if (_selectedSpecialtyIds.contains(id)) {
                            _selectedSpecialtyIds.remove(id);
                            if (id == 'other') _customSpecialty.clear();
                          } else {
                            _selectedSpecialtyIds.add(id);
                          }
                        });
                      },
                    ),
                    OnboardingGoalsStep(
                      selectedGoalIds: _selectedGoalIds,
                      agreedLegal: _agreedLegal,
                      onAgreedLegalChanged: (v) {
                        setState(() => _agreedLegal = v);
                      },
                      onToggleGoal: (id) {
                        setState(() {
                          if (_selectedGoalIds.contains(id) &&
                              _selectedGoalIds.length > 1) {
                            _selectedGoalIds.remove(id);
                          } else {
                            _selectedGoalIds.add(id);
                          }
                        });
                      },
                      onOpenTerms: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TermsOfServicePage(),
                        ),
                      ),
                      onOpenPrivacy: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ),

              OnboardingBottomActions(
                step: _step,
                isLast: _step == _lastStepIndex,
                isLoading: _isSubmitting,
                slowHint: _showSlowHint,
                onNext: _isSubmitting ? null : _next,
                onBack: _back,
                finishLabel: 'Finish',
              ),
            ],
          ),
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
  final UsernameAvailabilityStatus userIdAvailabilityStatus;
  final bool isCheckingUserId;
  final ValueChanged<String> onUserIdChanged;
  final String? emailValidationStatus;
  final bool emailConflict;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onSignInInstead;
  final bool isSocial;

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
    required this.emailConflict,
    required this.onEmailChanged,
    required this.onSignInInstead,
    this.isSocial = false,
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
    final textSecondary = AuthTheme.secondaryText(context);
    final pass = widget.pass.text;
    final passwordsMatch = widget.pass.text == widget.confirmPass.text && widget.confirmPass.text.isNotEmpty;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: AuthSectionCard(
        title: 'Account credentials',
        compact: true,
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
            hint: 'gopi_26',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.text,
            onChanged: widget.onUserIdChanged,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'@?[A-Za-z0-9_]')),
              LengthLimitingTextInputFormatter(21),
            ],
            suffix: widget.userIdAvailabilityStatus ==
                    UsernameAvailabilityStatus.checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : widget.userIdAvailabilityStatus ==
                        UsernameAvailabilityStatus.available
                    ? Icon(Icons.check_rounded,
                        color: AuthTheme.success(context), size: 20)
                    : widget.userIdAvailabilityStatus ==
                            UsernameAvailabilityStatus.taken
                        ? Icon(Icons.error_outline_rounded,
                            color: AuthTheme.error(context), size: 20)
                        : widget.userIdAvailabilityStatus ==
                                UsernameAvailabilityStatus.error
                            ? Icon(Icons.error_outline_rounded,
                                color: DesignTokens.accentYellow, size: 20)
                            : null,
            helperText: UsernameAvailability.helperText(
              widget.userIdAvailabilityStatus,
            ),
            helperColor: widget.userIdAvailabilityStatus ==
                    UsernameAvailabilityStatus.available
                ? AuthTheme.success(context)
                : widget.userIdAvailabilityStatus ==
                        UsernameAvailabilityStatus.checking
                    ? textSecondary
                    : AuthTheme.error(context),
          ),

          const SizedBox(height: 20),

          IgnorePointer(
            ignoring: widget.isSocial,
            child: _TextFieldCard(
            label: 'Email *',
            controller: widget.email,
            hint: 'your.email@example.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            onChanged: widget.onEmailChanged,
            suffix: widget.emailValidationStatus == 'invalid' ||
                    widget.emailConflict
                ? Icon(Icons.error_outline,
                    color: AuthTheme.error(context), size: 20)
                : null,
            helperText: widget.emailConflict
                ? 'An account already exists with this email.'
                : widget.emailValidationStatus == 'invalid'
                    ? 'Enter a valid email address.'
                    : null,
            helperColor: AuthTheme.error(context),
          ),
          ),
          if (widget.emailConflict && !widget.isSocial)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                button: true,
                label: 'Sign in instead',
                child: GestureDetector(
                  onTap: widget.onSignInInstead,
                  child: const Text(
                    'Sign in instead',
                    style: TextStyle(
                      color: CotrainrGradients.focus,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),

          if (!widget.isSocial) ...[
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
            helperColor: passwordsMatch ? AuthTheme.success(context) : AuthTheme.error(context),
          ),
          ],

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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _TextFieldCard(
            label: 'First Name',
            controller: first,
            hint: 'Enter your first name',
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 10),

          _TextFieldCard(
            label: 'Last Name',
            controller: last,
            hint: 'Enter your last name',
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 10),

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
                      color: AuthTheme.primaryText(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: AuthTheme.fieldBorder(context),
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

// Step 3: Age & Gender
class _StepAgeGenderContent extends StatelessWidget {
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
    }
    return '$years';
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AuthTheme.secondaryText(context);
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
          const SizedBox(height: 10),
          SizedBox(
            height: 268,
            child: AuthPickerFadeMask(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: CotrainrGradients.focus,
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
          const SizedBox(height: 8),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                'Age $ageText',
                key: ValueKey(ageText),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Gender *', style: sectionLabel),
          const SizedBox(height: 10),
          AuthGenderSelector(
            value: gender,
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 8),
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
    final textPrimary = AuthTheme.secondaryText(context);
    final borderColor = AuthTheme.fieldBorder(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          _ValueUnitBar(
            value: widget.heightInCm
                ? '${widget.heightCm.round()}'
                : "${widget.feet}' ${widget.inch}\"",
            left: 'cm',
            right: 'ft/in',
            isLeft: widget.heightInCm,
            onToggle: widget.onToggleHeightUnit,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.heightInCm
                ? _PickerFadeWrapper(
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        primaryColor: CotrainrGradients.focus,
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
                        builder: (context, index, distance) {
                          final value = 80 + (index % 151);
                          return _RotorLabel(
                            text: '$value cm',
                            distance: distance,
                            neutral: textPrimary,
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
                              primaryColor: CotrainrGradients.focus,
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
                              builder: (context, index, distance) {
                                final value = 3 + (index % 6);
                                return _RotorLabel(
                                  text: '$value ft',
                                  distance: distance,
                                  neutral: textPrimary,
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
                              primaryColor: CotrainrGradients.focus,
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
                              builder: (context, index, distance) {
                                final actual = index % 12;
                                return _RotorLabel(
                                  text: '$actual in',
                                  distance: distance,
                                  neutral: textPrimary,
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
    final textPrimary = AuthTheme.secondaryText(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          _ValueUnitBar(
            value: widget.weightInKg
                ? widget.weightKg.toStringAsFixed(1)
                : widget.weightLbs.toStringAsFixed(1),
            left: 'kg',
            right: 'lb',
            isLeft: widget.weightInKg,
            onToggle: (isKg) {
              widget.onToggleWeightUnit(isKg);
              _syncWeightTextFromValue();
              if (isKg) {
                _syncKgPicker(widget.weightKg);
              } else {
                _syncLbsPicker(widget.weightLbs);
              }
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _PickerFadeWrapper(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: CotrainrGradients.focus,
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
                        builder: (context, index, distance) {
                          final actualIndex = index % 1151;
                          final value =
                              (35 + actualIndex * 0.1).toStringAsFixed(1);
                          return _RotorLabel(
                            text: '$value kg',
                            distance: distance,
                            neutral: textPrimary,
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
                        builder: (context, index, distance) {
                          final actualIndex = index % 2531;
                          final value =
                              (77 + actualIndex * 0.1).toStringAsFixed(1);
                          return _RotorLabel(
                            text: '$value lbs',
                            distance: distance,
                            neutral: textPrimary,
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
    final textPrimary = AuthTheme.primaryText(context);
    final textSecondary = AuthTheme.secondaryText(context);

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
            ? AuthTheme.success(context).withValues(alpha: 0.14)
            : AuthTheme.mutedSurface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isValid
              ? AuthTheme.success(context)
              : AuthTheme.fieldBorder(context),
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
                  ? AuthTheme.success(context)
                  : AuthTheme.mutedText(context),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isValid ? FontWeight.w600 : FontWeight.w500,
                color: isValid
                  ? AuthTheme.success(context)
                  : AuthTheme.mutedText(context),
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
    final textPrimary = AuthTheme.primaryText(context);
    final borderColor = AuthTheme.fieldBorder(context);
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
          color: CotrainrGradients.focus,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: AuthTheme.fieldSurface(context),
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
            color: CotrainrGradients.focus,
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

class _RotorLabel extends StatelessWidget {
  const _RotorLabel({
    required this.text,
    required this.distance,
    required this.neutral,
  });

  final String text;
  final int distance;
  final Color neutral;

  @override
  Widget build(BuildContext context) {
    final selected = distance == 0;
    if (selected) {
      return Center(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              CotrainrGradients.primary.createShader(bounds),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final alpha = switch (distance) {
      1 => 0.92,
      2 => 0.62,
      _ => (0.38 - (distance - 3) * 0.06).clamp(0.22, 0.38),
    };
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: neutral.withValues(alpha: alpha),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ValueUnitBar extends StatelessWidget {
  const _ValueUnitBar({
    required this.value,
    required this.left,
    required this.right,
    required this.isLeft,
    required this.onToggle,
  });

  final String value;
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AuthTheme.primaryText(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AuthTheme.valueControlSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthTheme.fieldBorder(context)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 58),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                value,
                key: ValueKey(value),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _UnitToggle(
              left: left,
              right: right,
              isLeft: isLeft,
              onChanged: onToggle,
            ),
          ),
        ],
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
    final textPrimary = AuthTheme.primaryText(context);

    return Semantics(
      label: 'Unit, ${isLeft ? left : right}',
      child: Container(
        width: 96,
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AuthTheme.mutedSurface(context),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 46,
                decoration: BoxDecoration(
                  gradient: CotrainrGradients.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(true);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLeft ? Colors.black : textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(false);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: !isLeft ? Colors.black : textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
    final textPrimary = AuthTheme.secondaryText(context);

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
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    CotrainrGradients.primary.createShader(bounds),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: textPrimary.withValues(
                    alpha: (index - _currentIndex).abs() == 1 ? 0.90 : 0.55,
                  ),
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
  final Widget Function(BuildContext, int loopingIndex, int visualDistance)
      builder;

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
      setState(() => _lastSelectedIndex = currentIndex);
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
          _lastSelectedIndex = newIndex;
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              setState(() => _isJumping = false);
            }
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
          _lastSelectedIndex = newIndex;
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              setState(() => _isJumping = false);
            }
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
        setState(() => _lastSelectedIndex = index);
        if (!_isJumping) {
          final actualIndex = index % widget.itemCount;
          widget.onSelectedItemChanged(actualIndex);
        }
      },
      children: List.generate(totalItems, (index) {
        return widget.builder(
          context,
          index,
          (index - _lastSelectedIndex).abs(),
        );
      }),
    );
  }
}

