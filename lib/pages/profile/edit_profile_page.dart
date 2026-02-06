import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../../providers/profile_images_provider.dart';
import '../../services/storage_service.dart';
import '../../repositories/profile_repository.dart';

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
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  
  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  
  final StorageService _storageService = StorageService();
  final ProfileRepository _profileRepo = ProfileRepository();
  bool _isLoading = false;
  bool _isUploadingImage = false;
  
  String? _pendingProfileImagePath;
  String? _pendingCoverImagePath;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _userIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
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
        setState(() {
          _pendingProfileImagePath = croppedPath;
        });
        ref.read(profileImagesProvider.notifier).updateProfileImage(croppedPath);
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
        aspectRatio: 2.0, // 2:1 aspect ratio for cover image (recommended for better UX)
        title: 'Crop Cover Picture',
      );
      
      if (croppedPath != null && mounted) {
        setState(() {
          _pendingCoverImagePath = croppedPath;
        });
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 15),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dobController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() => _isUploadingImage = true);
    try {
      final url = await _storageService.uploadAvatar(imageFile);
      if (url != null && mounted) {
        await _profileRepo.updateProfile({'avatar_url': url});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture uploaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading profile picture: $e'),
            duration: const Duration(seconds: 3),
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
    setState(() => _isUploadingImage = true);
    try {
      final url = await _storageService.uploadCoverImage(imageFile);
      if (url != null && mounted) {
        await _profileRepo.updateProfile({'cover_url': url});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover picture uploaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading cover picture: $e'),
            duration: const Duration(seconds: 3),
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
    if (_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          duration: Duration(seconds: 1),
        ),
      );
      // Auto dismiss after 1 second and navigate back to settings
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context); // Go back to settings
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profileImages = ref.watch(profileImagesProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onBackground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile and Cover Photo Section
            Row(
              children: [
                Expanded(
                  child: _PhotoSelector(
                    label: 'Profile Photo',
                    imagePath: profileImages.profileImagePath,
                    onTap: _pickProfileImage,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PhotoSelector(
                    label: 'Cover Photo',
                    imagePath: profileImages.coverImagePath,
                    onTap: _pickCoverImage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // First Name
            _FormField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Last Name
            _FormField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // User ID (non-editable)
            _FormField(
              controller: _userIdController,
              label: 'User ID',
              icon: Icons.badge_outlined,
              enabled: false,
            ),
            const SizedBox(height: 16),
            // Email
            _FormField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Password
            _FormField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              hintText: 'Leave empty to keep current password',
            ),
            const SizedBox(height: 16),
            // Phone Number
            _FormField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Date of Birth
            _FormField(
              controller: _dobController,
              label: 'Date of Birth',
              icon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your date of birth';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Gender
            _GenderSelector(
              selectedGender: _selectedGender,
              genders: _genders,
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
            const SizedBox(height: 16),
            // Height and Weight Row
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    controller: _heightController,
                    label: 'Height (cm)',
                    icon: Icons.height,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FormField(
                    controller: _weightController,
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
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
                          throw Exception('Crop failed: ${error.error?.toString() ?? 'Unknown error'}');
                        }
                        
                        if (imageData == null || imageData.isEmpty) {
                          throw Exception('Invalid crop result: cropped image is empty.');
                        }
                        
                        debugPrint('Successfully extracted ${imageData.length} bytes from crop result');
                        
                        // Save cropped image to temporary file
                        final directory = Directory.systemTemp;
                        final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.png';
                        final file = File('${directory.path}/$fileName');
                        await file.writeAsBytes(imageData);
                        
                        if (mounted) {
                          Navigator.pop(context, file.path);
                        }
                      } catch (e) {
                        debugPrint('Crop error: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error cropping image: ${e.toString()}'),
                              duration: const Duration(seconds: 2),
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
                    child: ElevatedButton(
                      onPressed: () => _cropController.crop(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Crop'),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: imagePath != null && imagePath!.isNotEmpty
                    ? DecorationImage(
                        image: imagePath!.startsWith('http')
                            ? NetworkImage(imagePath!)
                            : FileImage(File(imagePath!)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
                color: imagePath == null || imagePath!.isEmpty
                    ? colorScheme.surfaceContainerHighest
                    : null,
              ),
              child: imagePath == null || imagePath!.isEmpty
                  ? Icon(Icons.add_photo_alternate, color: colorScheme.onSurface.withOpacity(0.5))
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
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
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.hintText,
    this.keyboardType,
    this.validator,
    this.onTap,
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
      style: TextStyle(
        color: enabled ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.7)),
        filled: true,
        fillColor: colorScheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.18)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
              Icon(Icons.person_outline, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
          ),
          child: Row(
            children: genders.map((gender) {
              final isSelected = gender == selectedGender;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(gender),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        gender,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : colorScheme.onSurface,
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
