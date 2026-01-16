import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../widgets/common/modern_input_box.dart';

class CocircleCreatePostPage extends StatefulWidget {
  const CocircleCreatePostPage({super.key});

  @override
  State<CocircleCreatePostPage> createState() => _CocircleCreatePostPageState();
}

class _CocircleCreatePostPageState extends State<CocircleCreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedMedia;
  bool _isImage = false;

  Future<void> _openGallery() async {
    HapticFeedback.lightImpact();
    
    try {
      // Show bottom sheet to choose between photo and video
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildMediaSourceSheet(),
      );

      if (source == null) return;

      XFile? pickedFile;
      
      if (source == ImageSource.gallery) {
        // First try to pick image, then video if user cancels image picker
        pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 85,
        );
        
        if (pickedFile != null) {
          _isImage = true;
        } else {
          // If no image selected, try video
          pickedFile = await _imagePicker.pickVideo(source: source);
          if (pickedFile != null) {
            _isImage = false;
          }
        }
      } else {
        // Camera source
        pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          _isImage = true;
        }
      }

      if (pickedFile != null) {
        // If it's an image, open cropper
        if (_isImage) {
          final croppedFile = await _cropImage(File(pickedFile.path));
          if (croppedFile != null) {
            setState(() {
              _selectedMedia = XFile(croppedFile.path);
            });
          }
        } else {
          // For video, just set it
          setState(() {
            _selectedMedia = pickedFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e')),
        );
      }
    }
  }

  Future<CroppedFile?> _cropImage(File imageFile) async {
    final cropper = ImageCropper();
    
    return await cropper.cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF4DA3FF),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
    );
  }

  Widget _buildMediaSourceSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final cocircleGradient = const LinearGradient(
      colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: cocircleGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: cocircleGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
              ),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cocircleGradient = const LinearGradient(
      colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (rect) => cocircleGradient.createShader(rect),
          child: Text(
            'Create Post',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: cocircleGradient,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4DA3FF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.person,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'gopinath',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '@alexjohnson',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ModernInputBox(
            controller: _textController,
            hintText: "Share your fitness journey... What's on your mind?",
            maxLines: 5,
            minLines: 5,
          ),
          const SizedBox(height: 12),
          if (_selectedMedia != null) ...[
            Container(
              height: 200,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _isImage
                        ? Image.file(
                            File(_selectedMedia!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Icon(Icons.videocam, size: 60),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMedia = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                onPressed: _openGallery,
                icon: ShaderMask(
                  shaderCallback: (rect) => cocircleGradient.createShader(rect),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  // TODO: Handle post submission
                  Navigator.pop(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: cocircleGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4DA3FF).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Add Tags (optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _TagChip(label: 'Boxing'),
              _TagChip(label: 'Yoga'),
              _TagChip(label: 'Weight Loss'),
              _TagChip(label: 'Strength'),
              _TagChip(label: 'Cardio'),
              _TagChip(label: 'Nutrition'),
              _TagChip(label: 'Motivation'),
              _TagChip(label: 'Progress'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withOpacity(0.75),
        ),
      ),
    );
  }
}
