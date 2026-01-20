import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class BecomeTrainerPage extends StatefulWidget {
  const BecomeTrainerPage({super.key});

  @override
  State<BecomeTrainerPage> createState() => _BecomeTrainerPageState();
}

class _BecomeTrainerPageState extends State<BecomeTrainerPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _certificateNameController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedGovIdType;
  File? _certificateImage;
  File? _govIdImage;
  
  final List<String> _categories = [
    'GYM',
    'Boxing',
    'Yoga',
    'Pilates',
    'Zumba',
    'Calisthenics',
  ];
  
  final List<String> _govIdTypes = [
    'Aadhar Card',
    'Driving License',
    'Passport',
    'PAN Card',
    'Voter ID',
    'Other',
  ];
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _yearsExperienceController.dispose();
    _certificateNameController.dispose();
    super.dispose();
  }

  Future<void> _pickCertificateImage() async {
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    
    if (image != null && mounted) {
      setState(() {
        _certificateImage = File(image.path);
      });
    }
  }

  Future<void> _pickGovIdImage() async {
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    
    if (image != null && mounted) {
      setState(() {
        _govIdImage = File(image.path);
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_certificateImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload certificate image'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedGovIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select government ID type'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_govIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload government ID image'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.stepsGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Application Submitted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Your trainer application has been submitted successfully. We will review your application and get back to you soon.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
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
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Become a Trainer',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              _SectionHeader(
                title: 'Personal Information',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              
              // First Name
              _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                hint: 'Enter your first name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Last Name
              _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                hint: 'Enter your last name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Professional Information Section
              _SectionHeader(
                title: 'Professional Information',
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 16),
              
              // Years of Experience
              _buildTextField(
                controller: _yearsExperienceController,
                label: 'Years of Experience',
                hint: 'e.g., 5',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter years of experience';
                  }
                  final years = int.tryParse(value);
                  if (years == null || years < 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Category Dropdown
              _buildDropdown(
                label: 'Category',
                value: _selectedCategory,
                items: _categories,
                icon: Icons.category,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                hint: 'Select your category',
              ),
              const SizedBox(height: 24),
              
              // Certificate Section
              _SectionHeader(
                title: 'Certificate',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              
              // Certificate Name
              _buildTextField(
                controller: _certificateNameController,
                label: 'Certificate Name',
                hint: 'e.g., Certified Personal Trainer',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter certificate name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Certificate Image Upload
              _buildImageUpload(
                label: 'Certificate Image',
                image: _certificateImage,
                onTap: _pickCertificateImage,
                icon: Icons.upload_file,
              ),
              const SizedBox(height: 24),
              
              // Government ID Verification Section
              _SectionHeader(
                title: 'Government ID Verification',
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: 16),
              
              // Government ID Type
              _buildDropdown(
                label: 'ID Type',
                value: _selectedGovIdType,
                items: _govIdTypes,
                icon: Icons.credit_card,
                onChanged: (value) {
                  setState(() {
                    _selectedGovIdType = value;
                  });
                },
                hint: 'Select ID type',
              ),
              const SizedBox(height: 16),
              
              // Government ID Image Upload
              _buildImageUpload(
                label: 'Government ID Image',
                image: _govIdImage,
                onTap: _pickGovIdImage,
                icon: Icons.upload_file,
              ),
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Application',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        color: AppColors.textPrimaryOf(context),
        fontSize: 16,
      ),
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
          borderSide: const BorderSide(
            color: AppColors.orange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          borderSide: const BorderSide(
            color: AppColors.red,
            width: 1,
          ),
        ),
        labelStyle: TextStyle(
          color: AppColors.textSecondaryOf(context),
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondaryOf(context),
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
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
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
          borderSide: const BorderSide(
            color: AppColors.orange,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(
          color: AppColors.textSecondaryOf(context),
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondaryOf(context),
        ),
      ),
      style: TextStyle(
        color: AppColors.textPrimaryOf(context),
        fontSize: 16,
      ),
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
                        borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
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
                            color: Colors.black.withOpacity(0.6),
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
                            color: AppColors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: AppColors.orange,
                            size: 32,
                          ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

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
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}
