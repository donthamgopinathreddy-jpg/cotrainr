import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/provider_professional_provider.dart';
import '../../repositories/verification_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/provider/provider_professional_form_fields.dart';
import '../../widgets/provider/provider_professional_form_validation.dart';

/// Two-phase provider onboarding: professional info → verification documents.
class VerificationSubmissionPage extends ConsumerStatefulWidget {
  const VerificationSubmissionPage({super.key});

  @override
  ConsumerState<VerificationSubmissionPage> createState() =>
      _VerificationSubmissionPageState();
}

class _VerificationSubmissionPageState
    extends ConsumerState<VerificationSubmissionPage> {
  final _verificationRepo = VerificationRepository();

  // Phase control: 0 = professional, 1 = documents
  int _phase = 0;

  // Documents (preserved across back navigation)
  String? _selectedGovIdType;
  File? _certificateImage;
  File? _govIdImage;

  final List<String> _govIdTypes = const [
    'Aadhar Card',
    'Driving License',
    'Passport',
    'PAN Card',
    'Voter ID',
    'Other',
  ];

  // Professional form
  final _headlineCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  final Set<String> _specialties = {};
  final Set<String> _sessionModes = {};
  final List<String> _languages = [];

  bool _isSubmitting = false;
  bool _isSavingProfessional = false;
  bool _isLoading = true;
  bool _hydrated = false;
  String? _loadError;
  String _providerRole = 'trainer';
  String? _submissionStatus;
  String? _rejectionNotes;

  // Preserved optional fields so Phase 1 save does not wipe them
  double? _existingHourlyRate;
  bool _existingAccepting = true;

  bool get _isNutritionist => _providerRole == 'nutritionist';
  String get _pageTitle =>
      _isNutritionist ? 'Nutritionist Verification' : 'Trainer Verification';
  String get _credentialLabel =>
      _isNutritionist ? 'Upload License/Degree' : 'Upload Training Certificate';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _bioCtrl.dispose();
    _experienceCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final role = await _verificationRepo.getProviderRole();
      final sub = await _verificationRepo.getMyLatestSubmission();
      await ref.read(myProviderProfessionalProvider.notifier).refresh();

      // Provider row may still be creating right after signup.
      if (ref.read(myProviderProfessionalProvider).valueOrNull == null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await ref.read(myProviderProfessionalProvider.notifier).refresh();
      }

      if (!mounted) return;
      setState(() {
        _providerRole = role;
        _submissionStatus = sub?['status'] as String?;
        _rejectionNotes = sub?['rejection_notes'] as String?;
        _isLoading = false;
      });
      _hydrateProfessional();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _providerRole = 'trainer';
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _hydrateProfessional() {
    if (_hydrated) return;
    final profile = ref.read(myProviderProfessionalProvider).valueOrNull;
    if (profile != null) {
      _providerRole = profile.providerType;
      if ((profile.professionalHeadline ?? '').trim().isNotEmpty) {
        _headlineCtrl.text = profile.professionalHeadline!.trim();
      }
      if ((profile.bio ?? '').trim().isNotEmpty) {
        _bioCtrl.text = profile.bio!.trim();
      }
      // Prefill experience when headline already set, or when > 0
      if (profile.experienceYears != null &&
          (profile.experienceYears! > 0 ||
              (profile.professionalHeadline ?? '').trim().isNotEmpty)) {
        _experienceCtrl.text = '${profile.experienceYears}';
      }
      if (profile.specializationIds.isNotEmpty) {
        _specialties
          ..clear()
          ..addAll(profile.specializationIds);
      }
      if (profile.sessionModes.isNotEmpty) {
        _sessionModes
          ..clear()
          ..addAll(profile.sessionModes);
      }
      if (profile.languages.isNotEmpty) {
        _languages
          ..clear()
          ..addAll(profile.languages);
      }
      _existingHourlyRate = profile.hourlyRate;
      _existingAccepting = profile.acceptingNewClients;
      _hydrated = true;
      return;
    }

    // No provider row yet — fall back to auth metadata role + empty form
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final metaRole = meta?['role']?.toString().toLowerCase();
    if (metaRole == 'nutritionist' || metaRole == 'trainer') {
      _providerRole = metaRole!;
    }
    final specs = meta?['specialization'];
    if (specs is List && _specialties.isEmpty) {
      _specialties.addAll(specs.map((e) => e.toString()));
    }
    _hydrated = true;
  }

  Future<void> _continueFromProfessional() async {
    final err = ProviderProfessionalFormValidation.validate(
      headline: _headlineCtrl.text,
      experienceText: _experienceCtrl.text,
      bio: _bioCtrl.text,
      specializationIds: _specialties,
      languages: _languages,
      sessionModes: _sessionModes,
    );
    if (err != null) {
      _showSnack(err);
      return;
    }

    setState(() => _isSavingProfessional = true);
    HapticFeedback.mediumImpact();
    try {
      final exp = int.parse(_experienceCtrl.text.trim());
      await ref.read(myProviderProfessionalProvider.notifier).save(
            providerType: _providerRole,
            professionalHeadline: _headlineCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            experienceYears: exp,
            specializationIds: _specialties.toList(),
            sessionModes: _sessionModes.toList(),
            languages: _languages,
            hourlyRate: _existingHourlyRate,
            acceptingNewClients: _existingAccepting,
          );
      if (!mounted) return;
      setState(() {
        _isSavingProfessional = false;
        _phase = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingProfessional = false);
      _showSnack(
        'Could not save professional profile: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _pickCertificateImage() async {
    HapticFeedback.lightImpact();
    final image = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image != null && mounted) {
      setState(() => _certificateImage = File(image.path));
    }
  }

  Future<void> _pickGovIdImage() async {
    HapticFeedback.lightImpact();
    final image = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image != null && mounted) {
      setState(() => _govIdImage = File(image.path));
    }
  }

  Future<void> _submitVerification() async {
    if (_certificateImage == null) {
      _showSnack('Please upload $_credentialLabel');
      return;
    }
    if (_selectedGovIdType == null) {
      _showSnack('Please select government ID type');
      return;
    }
    if (_govIdImage == null) {
      _showSnack('Please upload government ID image');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await _verificationRepo.submitVerification(
        providerType: _providerRole,
        govIdType: _selectedGovIdType!,
        certificateFile: _certificateImage!,
        govIdFile: _govIdImage!,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submissionStatus = 'pending';
          _rejectionNotes = null;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.stepsGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Documents Submitted',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your verification documents have been submitted successfully. Please wait up to 24 hours for verification. You will be notified once your account is verified.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(myProviderProfessionalProvider, (prev, next) {
      if (!_hydrated && next.hasValue) {
        setState(_hydrateProfessional);
      }
    });

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: CotrainrAppBar(
          title: _pageTitle,
          fallbackRoute: '/home',
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null && !_hydrated) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: CotrainrAppBar(
          title: _pageTitle,
          fallbackRoute: '/home',
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _bootstrap,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_submissionStatus == 'approved') {
      return _buildStatusScreen(
        icon: Icons.verified,
        iconColor: DesignTokens.accentGreen,
        title: "You're Verified!",
        message:
            'Your ${_isNutritionist ? 'Nutritionist' : 'Trainer'} account has been verified. You can now accept clients and access all features.',
        action: OutlinedButton(
          onPressed: () => context.push('/profile/professional'),
          child: const Text('Edit professional profile'),
        ),
      );
    }

    if (_submissionStatus == 'rejected') {
      return _buildStatusScreen(
        icon: Icons.cancel,
        iconColor: DesignTokens.accentRed,
        title: 'Verification Rejected',
        message: (_rejectionNotes != null && _rejectionNotes!.isNotEmpty)
            ? _rejectionNotes!
            : 'You can update your profile and submit new documents.',
        secondaryMessage: (_rejectionNotes != null &&
                _rejectionNotes!.isNotEmpty)
            ? 'Update professional info if needed, then upload new documents.'
            : null,
        action: ElevatedButton(
          onPressed: () => setState(() {
            _submissionStatus = null;
            _phase = 0;
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Resubmit'),
        ),
      );
    }

    if (_submissionStatus == 'pending') {
      return _buildStatusScreen(
        icon: Icons.hourglass_empty,
        iconColor: AppColors.orange,
        title: 'Pending Review',
        message:
            'Your documents have been submitted. Please wait up to 24 hours for verification. You will be notified once your account is verified.',
        action: OutlinedButton(
          onPressed: () => context.push('/profile/professional'),
          child: const Text('Edit professional profile'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _pageTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: CotrainrBackButton(
          fallbackRoute: '/home',
          onPressed: () {
            HapticFeedback.lightImpact();
            if (_phase == 1) {
              setState(() => _phase = 0);
              return;
            }
            CotrainrBackButton.popOrFallback(context, fallbackRoute: '/home');
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _PhaseIndicator(phase: _phase),
          ),
          Expanded(
            child: _phase == 0
                ? _buildProfessionalPhase()
                : _buildDocumentsPhase(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalPhase() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Complete your professional profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Clients will see your headline, bio, experience, specialties, languages, and session modes on your public profile.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 20),
        _field(
          label: 'Professional headline',
          child: TextField(
            controller: _headlineCtrl,
            maxLength: ProviderProfessionalFormValidation.headlineMaxLen,
            decoration: _decoration(
              ProviderProfessionalFormValidation.headlinePlaceholder(
                _providerRole,
              ),
            ),
          ),
        ),
        _field(
          label: 'Years of experience',
          child: TextField(
            controller: _experienceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decoration('0–60'),
          ),
        ),
        _field(
          label: 'Professional bio',
          child: TextField(
            controller: _bioCtrl,
            maxLines: 5,
            maxLength: ProviderProfessionalFormValidation.bioMaxLen,
            decoration: _decoration(
              'Describe your coaching style, experience, and who you help…',
            ),
          ),
        ),
        _field(
          label: 'Specialties',
          child: ProviderSpecialtySelector(
            providerType: _providerRole,
            selectedIds: _specialties,
            onChanged: (next) => setState(() {
              _specialties
                ..clear()
                ..addAll(next);
            }),
          ),
        ),
        _field(
          label: 'Languages',
          child: ProviderLanguageSelector(
            languages: _languages,
            customController: _languageCtrl,
            onChanged: (next) => setState(() {
              _languages
                ..clear()
                ..addAll(next);
            }),
          ),
        ),
        _field(
          label: 'Session modes',
          child: ProviderSessionModeSelector(
            providerType: _providerRole,
            selectedIds: _sessionModes,
            onChanged: (next) => setState(() {
              _sessionModes
                ..clear()
                ..addAll(next);
            }),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                _isSavingProfessional ? null : _continueFromProfessional,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusButton),
              ),
            ),
            child: _isSavingProfessional
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsPhase() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Verify your credentials',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Certificate and government ID images are private. Only admins review them — they are never shown on your public profile.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: _credentialLabel, icon: Icons.school_outlined),
        const SizedBox(height: 16),
        _buildImageUpload(
          label: _credentialLabel,
          image: _certificateImage,
          onTap: _pickCertificateImage,
          icon: Icons.upload_file,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Government ID Verification',
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'ID Type',
          value: _selectedGovIdType,
          items: _govIdTypes,
          icon: Icons.credit_card,
          onChanged: (v) => setState(() => _selectedGovIdType = v),
          hint: 'Select ID type',
        ),
        const SizedBox(height: 16),
        _buildImageUpload(
          label: 'Government ID Image',
          image: _govIdImage,
          onTap: _pickGovIdImage,
          icon: Icons.upload_file,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _phase = 0),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusButton),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusButton),
                  ),
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      counterText: '',
    );
  }

  Widget _buildStatusScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? secondaryMessage,
    Widget? action,
  }) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CotrainrAppBar(
        title: _pageTitle,
        fallbackRoute: '/home',
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              if (secondaryMessage != null && secondaryMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  secondaryMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 32),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    required String hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.orange),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: BorderSide(
            color: DesignTokens.borderColorOf(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
        hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
      ),
      style: TextStyle(color: AppColors.textPrimaryOf(context), fontSize: 16),
      dropdownColor: colorScheme.surface,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.orange),
    );
  }

  Widget _buildImageUpload({
    required String label,
    required File? image,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              border: Border.all(
                color: DesignTokens.borderColorOf(context),
                width: 1,
              ),
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusButton),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: AppColors.orange, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upload image',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  final int phase;

  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 1, 'Professional', phase >= 0),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 2,
            color: phase >= 1
                ? AppColors.orange
                : DesignTokens.borderColorOf(context),
          ),
        ),
        const SizedBox(width: 8),
        _chip(context, 2, 'Documents', phase >= 1),
      ],
    );
  }

  Widget _chip(BuildContext context, int n, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppColors.orange.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.orange : DesignTokens.borderColorOf(context),
        ),
      ),
      child: Text(
        '$n. $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active
              ? AppColors.orange
              : AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.stepsGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}
