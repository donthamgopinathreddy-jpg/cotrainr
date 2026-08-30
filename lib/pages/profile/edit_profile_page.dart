import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/profile_images_provider.dart';
import '../../services/nutrition_planner_local_storage.dart';
import '../../services/storage_service.dart';
import '../../repositories/profile_repository.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import 'edit_profile_save_state.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _userIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _goalWeightController = TextEditingController();
  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];

  // Unit toggles: true = metric (cm/kg), false = imperial (ft/in/lb)
  bool _useMetricHeight = true;
  bool _useMetricWeight = true;

  // Additional controllers for imperial units
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();

  final StorageService _storageService = StorageService();
  final ProfileRepository _profileRepo = ProfileRepository();
  final NutritionPlannerLocalStorage _plannerStorage =
      NutritionPlannerLocalStorage();
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isInitializing = true;
  bool _emailVerified = false;

  String _baselineFirstName = '';
  String _baselineLastName = '';
  String _baselineEmail = '';
  String _baselinePhone = '';
  String _baselineDob = '';
  String _baselineGender = 'Male';
  String _baselineHeight = '';
  String _baselineHeightFeet = '';
  String _baselineHeightInches = '';
  String _baselineWeight = '';
  String _baselineGoalWeight = '';
  bool _baselineUseMetricHeight = true;
  bool _baselineUseMetricWeight = true;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _firstNameController,
      _lastNameController,
      _emailController,
      _phoneController,
      _dobController,
      _heightController,
      _heightFeetController,
      _heightInchesController,
      _weightController,
      _goalWeightController,
    ]) {
      c.addListener(_onFormChanged);
    }
    _loadProfileData();
  }

  void _onFormChanged() {
    if (!_isInitializing && mounted) setState(() {});
  }

  void _captureBaseline() {
    _baselineFirstName = _firstNameController.text;
    _baselineLastName = _lastNameController.text;
    _baselineEmail = _emailController.text;
    _baselinePhone = _phoneController.text;
    _baselineDob = _dobController.text;
    _baselineGender = _selectedGender;
    _baselineHeight = _heightController.text;
    _baselineHeightFeet = _heightFeetController.text;
    _baselineHeightInches = _heightInchesController.text;
    _baselineWeight = _weightController.text;
    _baselineGoalWeight = _goalWeightController.text;
    _baselineUseMetricHeight = _useMetricHeight;
    _baselineUseMetricWeight = _useMetricWeight;
  }

  bool get _isDirty {
    if (_isInitializing) return false;
    return _firstNameController.text != _baselineFirstName ||
        _lastNameController.text != _baselineLastName ||
        _emailController.text != _baselineEmail ||
        _phoneController.text != _baselinePhone ||
        _dobController.text != _baselineDob ||
        _selectedGender != _baselineGender ||
        _heightController.text != _baselineHeight ||
        _heightFeetController.text != _baselineHeightFeet ||
        _heightInchesController.text != _baselineHeightInches ||
        _weightController.text != _baselineWeight ||
        _goalWeightController.text != _baselineGoalWeight ||
        _useMetricHeight != _baselineUseMetricHeight ||
        _useMetricWeight != _baselineUseMetricWeight;
  }

  String get _heightValidationRaw {
    if (_useMetricHeight) return _heightController.text;
    final feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
    final inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
    if (feet == 0 && inches == 0) return '';
    return ((feet * 12) + inches).toString();
  }

  bool get _formLooksValid => editProfileFormLooksValid(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        dob: _dobController.text,
        heightRaw: _heightValidationRaw,
        weightRaw: _weightController.text,
        goalWeight: _goalWeightController.text,
      );

  bool get _canSave => editProfileCanSave(
        dirty: _isDirty,
        valid: _formLooksValid,
        saving: _isLoading,
      );

  Future<void> _loadProfileData({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() => _isInitializing = true);
    }

    try {
      // Auth ready guard: wait a bit if user is null (cold start)
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      }

      // Hard timeout on profile fetch
      final profile = await _profileRepo.fetchMyProfile().timeout(
        const Duration(seconds: 8),
      );

      if (!mounted) return;

      if (profile != null) {
        // Parse full_name into first and last name
        final fullName = profile['full_name'] as String? ?? '';
        final nameParts = fullName.split(' ');
        if (nameParts.isNotEmpty) {
          _firstNameController.text = nameParts.first;
          if (nameParts.length > 1) {
            _lastNameController.text = nameParts.sublist(1).join(' ');
          }
        }

        // Set other fields
        _userIdController.text = profile['username'] as String? ?? '';
        _emailController.text = profile['email'] as String? ?? '';
        _phoneController.text = profile['phone'] as String? ?? '';

        // Date of birth
        final dob = profile['date_of_birth'];
        if (dob != null) {
          if (dob is String) {
            _dobController.text = dob;
          } else if (dob is DateTime) {
            _dobController.text =
                '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
          }
        }

        // Gender
        final gender = profile['gender'] as String?;
        if (gender != null && _genders.contains(gender)) {
          _selectedGender = gender;
        }

        // Height and weight - always load in metric (cm/kg)
        final height = profile['height_cm'] as int?;
        if (height != null) {
          _heightController.text = height.toString();
        }

        final weight = profile['weight_kg'];
        if (weight != null) {
          if (weight is num) {
            _weightController.text = weight.toStringAsFixed(1);
          } else {
            _weightController.text = weight.toString();
          }
        }

        final planner = await _plannerStorage.loadSavedState();
        if (planner != null) {
          _goalWeightController.text =
              planner.targetWeightKg.toStringAsFixed(1);
        }

        final user = Supabase.instance.client.auth.currentUser;
        _emailVerified = user?.emailConfirmedAt != null;

        // Load profile images
        if (mounted) {
          try {
            final avatarUrl = profile['avatar_url'] as String?;
            final coverUrl = profile['cover_url'] as String?;
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              ref
                  .read(profileImagesProvider.notifier)
                  .updateProfileImage(avatarUrl);
            }
            if (coverUrl != null && coverUrl.isNotEmpty) {
              ref
                  .read(profileImagesProvider.notifier)
                  .updateCoverImage(coverUrl);
            }
          } catch (e) {
            // Don't fail the whole load if image provider update fails
          }
        }

        // Force UI rebuild after controller updates
        if (mounted) {
          _captureBaseline();
          setState(() {});
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('EditProfilePage: load failed: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We couldn’t load your profile. Try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _userIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _goalWeightController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image != null && mounted) {
      // Show cropping screen with square preset (1:1 aspect ratio for profile)
      final croppedPath = await _showCropDialog(
        context,
        image.path,
        aspectRatio: 1.0, // Square for profile picture
        title: 'Crop Profile Picture',
      );

      if (croppedPath != null && mounted) {
        ref
            .read(profileImagesProvider.notifier)
            .updateProfileImage(croppedPath);
        // Upload immediately
        await _uploadProfileImage(File(croppedPath));
      }
    }
  }

  Future<void> _pickCoverImage() async {
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image != null && mounted) {
      // Show cropping screen with cover preset (2:1 aspect ratio for cover - recommended)
      final croppedPath = await _showCropDialog(
        context,
        image.path,
        aspectRatio:
            2.0, // 2:1 aspect ratio for cover image (recommended for better UX)
        title: 'Crop Cover Picture',
      );

      if (croppedPath != null && mounted) {
        ref.read(profileImagesProvider.notifier).updateCoverImage(croppedPath);
        // Upload immediately
        await _uploadCoverImage(File(croppedPath));
      }
    }
  }

  Future<String?> _showCropDialog(
    BuildContext context,
    String imagePath, {
    required double aspectRatio,
    required String title,
  }) async {
    // Read image file as bytes
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CropDialog(
        imageBytes: imageBytes,
        aspectRatio: aspectRatio,
        title: title,
      ),
    );
  }

  void _convertHeightUnits(bool toMetric) {
    if (toMetric) {
      // Convert from feet/inches to cm
      final feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
      final inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
      if (feet > 0 || inches > 0) {
        final totalInches = (feet * 12) + inches;
        final heightCm = (totalInches * 2.54).round();
        _heightController.text = heightCm.toString();
      }
    } else {
      // Convert from cm to feet/inches
      final heightCm = int.tryParse(_heightController.text.trim());
      if (heightCm != null && heightCm > 0) {
        final totalInches = (heightCm / 2.54).round();
        final feet = totalInches ~/ 12;
        final inches = totalInches % 12;
        _heightFeetController.text = feet.toString();
        _heightInchesController.text = inches.toString();
      }
    }
  }

  void _convertWeightUnits(bool toMetric) {
    if (toMetric) {
      // Convert from lbs to kg
      final weightLb = double.tryParse(_weightController.text.trim());
      if (weightLb != null && weightLb > 0) {
        final weightKg = weightLb * 0.453592;
        _weightController.text = weightKg.toStringAsFixed(1);
      }
    } else {
      // Convert from kg to lbs
      final weightKg = double.tryParse(_weightController.text.trim());
      if (weightKg != null && weightKg > 0) {
        final weightLb = weightKg / 0.453592;
        _weightController.text = weightLb.toStringAsFixed(1);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Parse existing date if available
    DateTime initialDate = DateTime(1990, 1, 15);
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('-');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (e) {
        // Use default if parsing fails
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    // Store reference before async operation
    ScaffoldMessengerState? scaffoldMessenger;
    if (mounted) {
      scaffoldMessenger = ScaffoldMessenger.of(context);
    }

    setState(() => _isUploadingImage = true);
    try {
      final url = await _storageService.uploadAvatar(imageFile);
      if (url != null && mounted) {
        await _profileRepo.updateProfile({'avatar_url': url});
        ref.read(profileImagesProvider.notifier).updateProfileImage(url);
        if (mounted && scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Profile picture uploaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EditProfilePage: avatar upload failed: $e');
      if (mounted && scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Cannot save profile picture. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _uploadCoverImage(File imageFile) async {
    // Store reference before async operation
    ScaffoldMessengerState? scaffoldMessenger;
    if (mounted) {
      scaffoldMessenger = ScaffoldMessenger.of(context);
    }

    setState(() => _isUploadingImage = true);
    try {
      final url = await _storageService.uploadCoverImage(imageFile);
      if (url != null && mounted) {
        await CachedNetworkImage.evictFromCache(url);
        final withoutQuery = Uri.tryParse(url)?.replace(queryParameters: {}).toString();
        if (withoutQuery != null && withoutQuery != url) {
          await CachedNetworkImage.evictFromCache(withoutQuery);
        }
        await _profileRepo.updateProfile({'cover_url': url});
        ref.read(profileImagesProvider.notifier).updateCoverImage(url);
        if (mounted && scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Cover picture uploaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EditProfilePage: cover upload failed: $e');
      if (mounted && scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Cannot save cover picture. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_canSave) return;
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    // Store references before async operations - must be done while widget is mounted
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      // Combine first and last name into full_name
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      // Prepare update data
      // profiles.email is server-owned (frozen by enforce_profiles_fields and
      // stripped by update_my_profile) — auth.updateUser below owns changes.
      final updates = <String, dynamic>{
        'full_name': fullName,
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
      };

      // Also update email in auth.users if it changed
      final currentEmail = Supabase.instance.client.auth.currentUser?.email;
      final newEmail = _emailController.text.trim();
      if (currentEmail != null &&
          currentEmail != newEmail &&
          newEmail.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(email: newEmail),
          );
        } catch (e) {
          // Never log the address itself.
          if (kDebugMode) {
            debugPrint('EditProfilePage: auth email update failed: $e');
          }
        }
      }

      // Add date of birth if provided
      if (_dobController.text.isNotEmpty) {
        updates['date_of_birth'] = _dobController.text.trim();
      }

      // Add height if provided (always convert to cm for storage)
      if (_useMetricHeight) {
        if (_heightController.text.isNotEmpty) {
          final height = int.tryParse(_heightController.text.trim());
          if (height != null) {
            updates['height_cm'] = height;
          }
        }
      } else {
        // Convert from feet and inches to cm
        final feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
        final inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
        if (feet > 0 || inches > 0) {
          final totalInches = (feet * 12) + inches;
          final heightCm = (totalInches * 2.54).round();
          updates['height_cm'] = heightCm;
        }
      }

      // Add weight if provided (always convert to kg for storage)
      if (_useMetricWeight) {
        if (_weightController.text.isNotEmpty) {
          final weight = double.tryParse(_weightController.text.trim());
          if (weight != null) {
            updates['weight_kg'] = weight;
          }
        }
      } else {
        // Convert from lbs to kg
        if (_weightController.text.isNotEmpty) {
          final weightLb = double.tryParse(_weightController.text.trim());
          if (weightLb != null) {
            final weightKg = weightLb * 0.453592;
            updates['weight_kg'] = weightKg;
          }
        }
      }

      // Update profile in Supabase
      await _profileRepo.updateProfile(updates);

      final goalWeight = double.tryParse(_goalWeightController.text.trim());
      if (goalWeight != null && goalWeight > 0) {
        final existing = await _plannerStorage.loadSavedState();
        if (existing != null) {
          await _plannerStorage.savePlannerState(
            SavedNutritionPlannerState(
              goalCalories: existing.goalCalories,
              goalProtein: existing.goalProtein,
              goalCarbs: existing.goalCarbs,
              goalFats: existing.goalFats,
              goalFiber: existing.goalFiber,
              goalWaterMl: existing.goalWaterMl,
              bmr: existing.bmr,
              maintenanceCalories: existing.maintenanceCalories,
              goalType: existing.goalType,
              activityLevel: existing.activityLevel,
              formulaVersion: existing.formulaVersion,
              plannerAge: existing.plannerAge,
              plannerGender: existing.plannerGender,
              plannerHeightCm: existing.plannerHeightCm,
              currentWeightKg: (updates['weight_kg'] as num?)?.toDouble() ??
                  existing.currentWeightKg,
              targetWeightKg: goalWeight,
              timelineDays: existing.timelineDays,
              weeklyChangeKg: existing.weeklyChangeKg,
              savedAt: DateTime.now(),
            ),
          );
        }
      }

      if (mounted) {
        try {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Profile saved successfully'),
              duration: Duration(seconds: 2),
            ),
          );
          // Navigate back immediately - no delay needed
          navigator.pop();
        } catch (e) {
          // Widget was disposed, ignore
          if (kDebugMode) debugPrint('EditProfilePage: save completion: $e');
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('EditProfilePage: save failed: $e\n$st');
      if (mounted) {
        try {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('We couldn’t save your profile. Try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e2) {
          // Widget was disposed, ignore
          if (kDebugMode) debugPrint('EditProfilePage: error handling: $e2');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double? _currentHeightCm() {
    if (_useMetricHeight) {
      return int.tryParse(_heightController.text.trim())?.toDouble();
    }
    final feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
    final inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
    if (feet == 0 && inches == 0) return null;
    return ((feet * 12) + inches) * 2.54;
  }

  double? _currentWeightKg() {
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) return null;
    return _useMetricWeight ? raw : raw * 0.453592;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profileImages = ref.watch(profileImagesProvider);
    final bgColor = AccountHubTheme.pageBg(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: const CotrainrBackButton(),
        title: Text(
          'Edit Profile',
          style: AppTextStyles.screenTitle(context),
        ),
        actions: [
          HubAppBarSaveAction(
            enabled: _canSave,
            saving: _isLoading,
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadProfileData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: RefreshIndicator(
                    color: DesignTokens.accentOrange,
                    backgroundColor: DesignTokens.surfaceOf(context),
                    onRefresh: () => _loadProfileData(showLoading: false),
                    child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _EditSection(
                        title: 'Profile',
                        delayMs: 0,
                        child: Row(
                          children: [
                            Expanded(
                              child: _PhotoSelector(
                                label: 'Profile Photo',
                                imagePath: profileImages.profileImagePath,
                                onTap: _isUploadingImage
                                    ? () {}
                                    : _pickProfileImage,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _PhotoSelector(
                                label: 'Cover Photo',
                                imagePath: profileImages.coverImagePath,
                                onTap: _isUploadingImage
                                    ? () {}
                                    : _pickCoverImage,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _EditSection(
                        title: 'Personal Information',
                        delayMs: 40,
                        child: Column(
                          children: [
                            _FormField(
                              controller: _firstNameController,
                              label: 'First Name',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              controller: _userIdController,
                              label: 'Username / User ID',
                              icon: Icons.badge_outlined,
                              enabled: false,
                              helperText: 'Cannot be changed',
                            ),
                          ],
                        ),
                      ),
                      _EditSection(
                        title: 'Contact',
                        delayMs: 80,
                        child: Column(
                          children: [
                            _FormField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              suffix: _emailVerified
                                  ? const Icon(Icons.verified_rounded,
                                      color: AccountHubTheme.goalsGreen,
                                      size: 20)
                                  : null,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final emailRe = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                if (!emailRe.hasMatch(v)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.isEmpty) return null;
                                if (v.length < 8) return 'Enter a valid phone';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      _EditSection(
                        title: 'Health Information',
                        delayMs: 120,
                        child: Column(
                          children: [
                            _FormField(
                              controller: _dobController,
                              label: 'Date of Birth',
                              icon: Icons.calendar_today_outlined,
                              readOnly: true,
                              onTap: () => _selectDate(context),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final parsed = DateTime.tryParse(v);
                                if (parsed != null &&
                                    parsed.isAfter(DateTime.now())) {
                                  return 'Cannot be in the future';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _GenderSelector(
                              selectedGender: _selectedGender,
                              genders: _genders,
                              onChanged: (v) =>
                                  setState(() => _selectedGender = v),
                            ),
                            const SizedBox(height: 12),
                            _HeightWeightField(
                              label: 'Height',
                              icon: Icons.height,
                              useMetric: _useMetricHeight,
                              metricController: _heightController,
                              imperialFeetController: _heightFeetController,
                              imperialInchesController: _heightInchesController,
                              onUnitToggle: (useMetric) {
                                setState(() {
                                  _useMetricHeight = useMetric;
                                  _convertHeightUnits(useMetric);
                                });
                              },
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _HeightWeightField(
                              label: 'Weight',
                              icon: Icons.monitor_weight_outlined,
                              useMetric: _useMetricWeight,
                              metricController: _weightController,
                              onUnitToggle: (useMetric) {
                                setState(() {
                                  _useMetricWeight = useMetric;
                                  _convertWeightUnits(useMetric);
                                });
                              },
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _FormField(
                              controller: _goalWeightController,
                              label: 'Goal Weight (kg)',
                              icon: Icons.flag_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return null;
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      _EditSection(
                        title: 'Live Fitness Preview',
                        delayMs: 160,
                        child: _BmiPreviewCard(
                          heightCm: _currentHeightCm(),
                          weightKg: _currentWeightKg(),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                if (_isUploadingImage)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: PressableCard(
                    onTap: _canSave ? _saveProfile : null,
                    borderRadius: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _canSave
                            ? DesignTokens.accentOrange
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _canSave
                                      ? Colors.white
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio;
  final String title;

  const _CropDialog({
    required this.imageBytes,
    required this.aspectRatio,
    required this.title,
  });

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final CropController _cropController = CropController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Crop area
            Flexible(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Crop(
                    image: widget.imageBytes,
                    controller: _cropController,
                    aspectRatio: widget.aspectRatio,
                    onCropped: (CropResult result) async {
                      try {
                        // In crop_your_image 2.0.0, CropResult is a sealed class
                        // Use pattern matching to extract croppedImage from CropSuccess
                        Uint8List? imageData;

                        // Pattern match on CropResult variants
                        if (result is CropSuccess) {
                          // CropSuccess has croppedImage property
                          final success = result as dynamic;
                          imageData = success.croppedImage as Uint8List?;
                        } else {
                          // Handle error case
                          final error = result as dynamic;
                          throw Exception(
                            'Crop failed: ${error.error?.toString() ?? 'Unknown error'}',
                          );
                        }

                        if (imageData == null || imageData.isEmpty) {
                          throw Exception(
                            'Invalid crop result: cropped image is empty.',
                          );
                        }

                        debugPrint(
                          'Successfully extracted ${imageData.length} bytes from crop result',
                        );

                        // Save cropped image to temporary file
                        final directory = Directory.systemTemp;
                        final fileName =
                            'cropped_${DateTime.now().millisecondsSinceEpoch}.png';
                        final file = File('${directory.path}/$fileName');
                        await file.writeAsBytes(imageData);

                        if (mounted) {
                          // Store navigator reference before async operation
                          final navigator = Navigator.of(context);
                          navigator.pop(file.path);
                        }
                      } catch (e) {
                        debugPrint('Crop error: $e');
                        if (mounted) {
                          // Store scaffold messenger reference before showing snackbar
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'We couldn’t edit that image. Try again.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ElevatedButton(
                        onPressed: () => _cropController.crop(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Crop'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  final String title;
  final Widget child;
  final int delayMs;

  const _EditSection({
    required this.title,
    required this.child,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 280 + delayMs),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - t)),
              child: child,
            ),
          );
        },
        child: HubSectionCard(
          title: title,
          child: child,
        ),
      ),
    );
  }
}

class _BmiPreviewCard extends StatelessWidget {
  final double? heightCm;
  final double? weightKg;

  const _BmiPreviewCard({required this.heightCm, required this.weightKg});

  @override
  Widget build(BuildContext context) {
    final h = heightCm ?? 0;
    final w = weightKg ?? 0;
    final bmi = h > 0 && w > 0
        ? ProfileRepository.calculateBMI(h, w)
        : 0.0;
    final status =
        bmi > 0 ? ProfileRepository.getBMIStatus(bmi) : '—';
    final heightM = h / 100;
    const healthyMax = 24.9;
    final targetWeight =
        heightM > 0 ? healthyMax * heightM * heightM : 0.0;
    final diff = w > 0 && targetWeight > 0 ? (w - targetWeight).abs() : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BMI ', style: AccountHubTheme.rowSubtitle(context)),
              Text(
                bmi > 0 ? bmi.toStringAsFixed(1) : '—',
                style: AccountHubTheme.rowTitle(context),
              ),
              const Spacer(),
              Text(status, style: AccountHubTheme.rowSubtitle(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Target BMI 24.9 · Target ${targetWeight > 0 ? '${targetWeight.toStringAsFixed(1)} kg' : '—'}',
            style: AccountHubTheme.rowSubtitle(context),
          ),
          if (diff > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${diff.toStringAsFixed(1)} kg to healthy range',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AccountHubTheme.goalsGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoSelector extends StatelessWidget {
  final String label;
  final String? imagePath;
  final VoidCallback onTap;

  const _PhotoSelector({
    required this.label,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PressableCard(
      onTap: onTap,
      borderRadius: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth.clamp(0.0, 160.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: imagePath != null && imagePath!.isNotEmpty
                          ? Image(
                              image: imagePath!.startsWith('http')
                                  ? NetworkImage(imagePath!)
                                  : FileImage(File(imagePath!))
                                      as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.add_photo_alternate,
                                size: 36,
                                color:
                                    colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final String? hintText;
  final String? helperText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.hintText,
    this.helperText,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged,
      style: TextStyle(
        color: enabled
            ? colorScheme.onSurface
            : colorScheme.onSurface.withOpacity(0.5),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        suffixIcon: suffix,
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.7)),
        filled: true,
        fillColor: colorScheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.18)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(
            color: Color(0xFFFF8A00),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String selectedGender;
  final List<String> genders;
  final ValueChanged<String> onChanged;

  const _GenderSelector({
    required this.selectedGender,
    required this.genders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Gender',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
          ),
          child: Row(
            children: genders.map((gender) {
              final isSelected = gender == selectedGender;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(gender),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        gender,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _HeightWeightField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool useMetric;
  final TextEditingController metricController;
  final TextEditingController? imperialFeetController;
  final TextEditingController? imperialInchesController;
  final ValueChanged<bool> onUnitToggle;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _HeightWeightField({
    required this.label,
    required this.icon,
    required this.useMetric,
    required this.metricController,
    this.imperialFeetController,
    this.imperialInchesController,
    required this.onUnitToggle,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHeight =
        imperialFeetController != null && imperialInchesController != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and Toggle
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              // Unit Toggle
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UnitToggleButton(
                      label: isHeight ? 'cm' : 'kg',
                      isSelected: useMetric,
                      onTap: () => onUnitToggle(true),
                    ),
                    _UnitToggleButton(
                      label: isHeight ? 'ft/in' : 'lb',
                      isSelected: !useMetric,
                      onTap: () => onUnitToggle(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Input Fields
        if (isHeight && !useMetric)
          // Height in feet and inches
          Row(
            children: [
              Expanded(
                child: _FormField(
                  controller: imperialFeetController!,
                  label: 'Feet',
                  icon: Icons.height,
                  keyboardType: TextInputType.number,
                  validator: validator,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FormField(
                  controller: imperialInchesController!,
                  label: 'Inches',
                  icon: Icons.height,
                  keyboardType: TextInputType.number,
                  validator: validator,
                  onChanged: onChanged,
                ),
              ),
            ],
          )
        else
          // Single input field (metric or weight in lbs)
          _FormField(
            controller: metricController,
            label: useMetric
                ? (isHeight ? 'Height (cm)' : 'Weight (kg)')
                : (isHeight ? 'Height' : 'Weight (lb)'),
            icon: icon,
            keyboardType: TextInputType.number,
            validator: validator,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF8A00), Color(0xFFFFD93D)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
