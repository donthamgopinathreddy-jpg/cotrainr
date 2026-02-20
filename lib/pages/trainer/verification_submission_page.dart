import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/verification_repository.dart';

class VerificationSubmissionPage extends StatefulWidget {
  const VerificationSubmissionPage({super.key});

  @override
  State<VerificationSubmissionPage> createState() => _VerificationSubmissionPageState();
}

class _VerificationSubmissionPageState extends State<VerificationSubmissionPage> {
  final _verificationRepo = VerificationRepository();

  String? _selectedGovIdType;
  File? _certificateImage;
  File? _govIdImage;

  final List<String> _govIdTypes = [
    'Aadhar Card',
    'Driving License',
    'Passport',
    'PAN Card',
    'Voter ID',
    'Other',
  ];

  bool _isSubmitting = false;
  bool _isLoading = true;
  String _providerRole = 'trainer';
  String? _submissionStatus;
  String? _rejectionNotes;

  bool get _isNutritionist => _providerRole == 'nutritionist';
  String get _pageTitle => _isNutritionist ? 'Nutritionist Verification' : 'Trainer Verification';
  String get _credentialLabel => _isNutritionist ? 'Upload License/Degree' : 'Upload Training Certificate';

  @override
  void initState() {
    super.initState();
    _loadRoleAndSubmission();
  }

  Future<void> _loadRoleAndSubmission() async {
    try {
      final role = await _verificationRepo.getProviderRole();
      final sub = await _verificationRepo.getMyLatestSubmission();
      if (mounted) {
        setState(() {
          _providerRole = role;
          _submissionStatus = sub?['status'] as String?;
          _rejectionNotes = sub?['rejection_notes'] as String?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _providerRole = 'trainer';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickCertificateImage() async {
    HapticFeedback.lightImpact();
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image != null && mounted) setState(() => _certificateImage = File(image.path));
  }

  Future<void> _pickGovIdImage() async {
    HapticFeedback.lightImpact();
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image != null && mounted) setState(() => _govIdImage = File(image.path));
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
              Navigator.pop(context);
            },
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          title: Text(_pageTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_submissionStatus == 'approved') {
      return _buildStatusScreen(
        icon: Icons.verified,
        iconColor: DesignTokens.accentGreen,
        title: 'You\'re Verified!',
        message: 'Your ${_isNutritionist ? 'Nutritionist' : 'Trainer'} account has been verified. You can now accept clients and access all features.',
      );
    }

    if (_submissionStatus == 'rejected') {
      return _buildStatusScreen(
        icon: Icons.cancel,
        iconColor: DesignTokens.accentRed,
        title: 'Verification Rejected',
        message: (_rejectionNotes != null && _rejectionNotes!.isNotEmpty) ? _rejectionNotes! : 'You can submit new documents below.',
        secondaryMessage: (_rejectionNotes != null && _rejectionNotes!.isNotEmpty) ? 'You can submit new documents below.' : null,
        action: ElevatedButton(
          onPressed: () => setState(() => _submissionStatus = null),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Submit New Documents'),
        ),
      );
    }

    if (_submissionStatus == 'pending') {
      return _buildStatusScreen(
        icon: Icons.hourglass_empty,
        iconColor: AppColors.orange,
        title: 'Pending Review',
        message: 'Your documents have been submitted. Please wait up to 24 hours for verification. You will be notified once your account is verified.',
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(_pageTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: _credentialLabel, icon: Icons.school_outlined),
            const SizedBox(height: 16),
            _buildImageUpload(
              label: _credentialLabel,
              image: _certificateImage,
              onTap: _pickCertificateImage,
              icon: Icons.upload_file,
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Government ID Verification', icon: Icons.verified_user_outlined),
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusButton)),
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Submit Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
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
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(_pageTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        elevation: 0,
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondaryOf(context)),
              ),
              if (secondaryMessage != null && secondaryMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  secondaryMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondaryOf(context)),
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
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.orange),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusButton), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusButton), borderSide: BorderSide(color: DesignTokens.borderColorOf(context), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusButton), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
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
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryOf(context))),
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
              border: Border.all(color: DesignTokens.borderColorOf(context), width: 1),
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                        child: Image.file(image, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
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
                          decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(icon, color: AppColors.orange, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text('Upload image', style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
          ),
        ),
      ],
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
          decoration: BoxDecoration(gradient: AppColors.stepsGradient, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
      ],
    );
  }
}
