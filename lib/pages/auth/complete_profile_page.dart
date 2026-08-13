import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_error_mapper.dart';
import '../../core/auth/signup_error_mapper.dart';
import '../../models/provider_specialty_taxonomy.dart';
import '../../pages/profile/settings/info_pages.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../widgets/auth/auth_ui.dart';

/// Completes Cotrainr profile after OAuth when username was not set at signup.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _userId = TextEditingController();
  final _fullName = TextEditingController();
  String _role = 'Client';
  final Set<String> _specializations = {};
  bool _agreedLegal = false;
  bool _isSubmitting = false;
  bool _showSlowHint = false;
  String? _formError;
  String? _userIdStatus; // available | taken | error | checking
  String _termsVersion = '2026-08-01';
  String _privacyVersion = '2026-08-01';
  Timer? _userIdDebounce;
  Timer? _slowHint;

  @override
  void initState() {
    super.initState();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final name = meta?['full_name']?.toString() ??
        meta?['name']?.toString() ??
        '';
    if (name.isNotEmpty) _fullName.text = name;
    _userId.addListener(_onUserIdChanged);
    unawaited(_loadLegalVersions());
  }

  Future<void> _loadLegalVersions() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('current_legal_versions')
          .timeout(const Duration(seconds: 15));
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

  void _onUserIdChanged() {
    _userIdDebounce?.cancel();
    final value = _userId.text.trim();
    if (value.isEmpty || !RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(value)) {
      setState(() {
        _userIdStatus = null;
      });
      return;
    }
    setState(() => _userIdStatus = 'checking');
    _userIdDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_checkUsername(value));
    });
  }

  Future<void> _checkUsername(String userId) async {
    try {
      final available = await Supabase.instance.client.rpc(
        'is_username_available',
        params: {'p_username': userId},
      ).timeout(const Duration(seconds: 15));
      if (!mounted || _userId.text.trim() != userId) return;
      setState(() {
        _userIdStatus = available == true ? 'available' : 'taken';
      });
    } catch (_) {
      if (!mounted || _userId.text.trim() != userId) return;
      setState(() => _userIdStatus = 'error');
    }
  }

  @override
  void dispose() {
    _userIdDebounce?.cancel();
    _slowHint?.cancel();
    _userId.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    final userId = _userId.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(userId)) {
      setState(() => _formError = SignupErrorMapper.invalidUsername.display);
      return;
    }
    if (_userIdStatus == 'taken') {
      setState(() => _formError = SignupErrorMapper.usernameTaken.display);
      return;
    }
    if (_userIdStatus == 'error' || _userIdStatus == 'checking') {
      setState(
        () => _formError = SignupErrorMapper.usernameCheckFailed.display,
      );
      return;
    }
    if ((_role == 'Trainer' || _role == 'Nutritionist') &&
        _specializations.isEmpty) {
      setState(
        () => _formError =
            'Select at least one specialty for your provider role.',
      );
      return;
    }
    if (!_agreedLegal) {
      setState(
        () => _formError =
            'Please agree to the Terms of Service and Privacy Policy.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
      _showSlowHint = false;
    });
    _slowHint?.cancel();
    _slowHint = Timer(const Duration(seconds: 3), () {
      if (mounted && _isSubmitting) setState(() => _showSlowHint = true);
    });

    try {
      await Supabase.instance.client.rpc(
        'complete_cotrainr_profile',
        params: {
          'p_username': userId,
          'p_role': _role.toLowerCase(),
          'p_full_name': _fullName.text.trim(),
          'p_specialization': (_role == 'Trainer' || _role == 'Nutritionist')
              ? ProviderSpecialtyTaxonomy.normalizeList(_specializations)
              : null,
          'p_terms_version': _termsVersion,
          'p_privacy_version': _privacyVersion,
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      // Same path as email signup: permissions → Home / Verification.
      context.go(
        '/auth/permissions',
        extra: {'role': _role.toLowerCase()},
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _formError = AuthErrorMapper.timeout.display);
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = SignupErrorMapper.map(e).display);
    } finally {
      _slowHint?.cancel();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showSlowHint = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final pageBg = AuthUi.pageBg(context);

    return Scaffold(
      backgroundColor: pageBg,
      body: AuthScreenBackground(
        scrimStrength: 0.4,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) context.go('/welcome');
                        },
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      'Complete your Cotrainr profile',
                      style: AuthUi.pageTitle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a User ID and how you’ll use Cotrainr.',
                      style: AuthUi.pageSubtitle(context),
                    ),
                    const SizedBox(height: 20),
                    AuthSectionCard(
                      title: 'Account',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTapToTypeField(
                            controller: _userId,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            style: AuthUi.fieldTextStyle(context, large: true),
                            decoration: AuthUi.fieldDecoration(
                              context,
                              large: true,
                              label: 'User ID',
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                                color: textSecondary,
                              ),
                            ),
                          ),
                          if (_userIdStatus != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              switch (_userIdStatus) {
                                'available' => 'User ID is available',
                                'taken' => 'This User ID is already taken',
                                'checking' => 'Checking User ID…',
                                _ =>
                                  'Unable to check User ID right now. Try again.',
                              },
                              style: TextStyle(
                                fontSize: 12,
                                color: switch (_userIdStatus) {
                                  'available' => DesignTokens.accentGreen,
                                  'taken' || 'error' => DesignTokens.accentRed,
                                  _ => textSecondary,
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          AuthTapToTypeField(
                            controller: _fullName,
                            textInputAction: TextInputAction.done,
                            style: AuthUi.fieldTextStyle(context, large: true),
                            decoration: AuthUi.fieldDecoration(
                              context,
                              large: true,
                              label: 'Full name (optional)',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AuthSectionCard(
                      title: 'Your role',
                      child: Column(
                        children: [
                          for (final role in const [
                            'Client',
                            'Trainer',
                            'Nutritionist',
                          ])
                            RadioListTile<String>(
                              value: role,
                              groupValue: _role,
                              title: Text(role),
                              activeColor: DesignTokens.accentOrange,
                              onChanged: _isSubmitting
                                  ? null
                                  : (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _role = v;
                                        if (v == 'Client') {
                                          _specializations.clear();
                                        }
                                      });
                                    },
                            ),
                          if (_role == 'Trainer' ||
                              _role == 'Nutritionist') ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Select at least one specialty',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final specialty
                                    in ProviderSpecialtyTaxonomy.forRole(
                                  _role.toLowerCase(),
                                ))
                                  FilterChip(
                                    label: Text(specialty.label),
                                    selected: _specializations
                                        .contains(specialty.id),
                                    onSelected: _isSubmitting
                                        ? null
                                        : (sel) {
                                            setState(() {
                                              if (sel) {
                                                _specializations
                                                    .add(specialty.id);
                                              } else {
                                                _specializations
                                                    .remove(specialty.id);
                                              }
                                            });
                                          },
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedLegal,
                          activeColor: DesignTokens.accentOrange,
                          onChanged: _isSubmitting
                              ? null
                              : (v) => setState(() => _agreedLegal = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'I agree to the ',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const TermsOfServicePage(),
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
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const PrivacyPolicyPage(),
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
                    if (_formError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _formError!,
                        style: TextStyle(
                          color: DesignTokens.accentRed,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (_showSlowHint) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Taking a little longer than usual…',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AuthPrimaryButton(
                      label: 'Continue',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
