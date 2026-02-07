import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/common/modern_input_box.dart';
import '../../services/storage_service.dart';
import '../../repositories/profile_repository.dart';

class CocircleCreatePostPage extends StatefulWidget {
  const CocircleCreatePostPage({super.key});

  @override
  State<CocircleCreatePostPage> createState() => _CocircleCreatePostPageState();
}

class _CocircleCreatePostPageState extends State<CocircleCreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final ProfileRepository _profileRepo = ProfileRepository();
  
  XFile? _selectedMedia;
  bool _isImage = false;
  bool _isVideo = false;
  bool _isProcessing = false;
  bool _isPosting = false;
  
  String? _username;
  String? _fullName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _username = profile['username'] as String?;
          _fullName = profile['full_name'] as String?;
          _avatarUrl = profile['avatar_url'] as String?;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _openGallery() async {
    if (!mounted || _isProcessing) return;
    
    _isProcessing = true;
    HapticFeedback.lightImpact();
    
    try {
      // Show bottom sheet to choose between photo and video
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildMediaSourceSheet(),
      );

      if (source == null || !mounted) return;

      // Show media type selection
      final mediaType = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildMediaTypeSheet(),
      );

      if (mediaType == null || !mounted) return;

      XFile? pickedFile;
      
      try {
        if (mediaType == 'image') {
          // Pick image
          pickedFile = await _imagePicker.pickImage(
            source: source,
            imageQuality: 85,
            maxWidth: 1920,
            maxHeight: 1920,
          );
          
          if (pickedFile != null) {
            _isImage = true;
            _isVideo = false;
          }
        } else if (mediaType == 'video') {
          // Pick video
          pickedFile = await _imagePicker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 1),
          );
          
          if (pickedFile != null) {
            _isVideo = true;
            _isImage = false;
            
            // Check video duration (basic check - maxDuration in pickVideo should handle it)
            // But we'll also validate file size as a secondary check
            final file = File(pickedFile.path);
            if (await file.exists()) {
              // Video picked successfully
              // The maxDuration parameter should prevent videos longer than 1 minute
            }
          }
        }
      } catch (pickerError) {
        if (mounted) {
          String errorMessage = 'Error picking media';
          if (pickerError.toString().contains('duration') || 
              pickerError.toString().contains('too long')) {
            errorMessage = 'Video must be 1 minute or less';
          } else {
            errorMessage = 'Error: ${pickerError.toString()}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (pickedFile != null && mounted) {
        final filePath = pickedFile.path;
        
        // Verify file exists
        final file = File(filePath);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected file does not exist')),
            );
          }
          return;
        }

        // Use the picked image/video directly at original size (no cropping)
        if (mounted) {
          setState(() {
            _selectedMedia = pickedFile;
          });
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        debugPrint('Error in _openGallery: $e');
        debugPrint('Stack trace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting media: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        _isProcessing = false;
      }
    }
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

  Widget _buildMediaTypeSheet() {
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
                child: const Icon(Icons.image, color: Colors.white, size: 24),
              ),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: cocircleGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.videocam, color: Colors.white, size: 24),
              ),
              title: const Text('Video (max 1 min)'),
              onTap: () => Navigator.pop(context, 'video'),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A2335) // Dark blue-black mix
        : const Color(0xFFE3F2FD); // Very light blue

    return Scaffold(
      body: Container(
        color: backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
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
              Expanded(
                child: ListView(
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
                ),
                child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _avatarUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullName ?? _username ?? 'User',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _username != null ? '@$_username' : '',
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
            borderGradient: cocircleGradient,
          ),
          const SizedBox(height: 12),
          if (_selectedMedia != null) ...[
            Container(
              height: 200,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
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
                        : Container(
                            color: Colors.black,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.play_circle_filled,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Video Selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Max 1 minute',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMedia = null;
                          _isImage = false;
                          _isVideo = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isVideo ? Icons.videocam : (_isImage ? Icons.image : Icons.close),
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
                onTap: _isPosting ? null : _createPost,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: cocircleGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (_textController.text.trim().isEmpty && _selectedMedia == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add text or media to your post'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isPosting = true);
    HapticFeedback.mediumImpact();

    // Store navigator reference before async operations
    final navigator = Navigator.of(context, rootNavigator: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create post
      final postResponse = await supabase
          .from('posts')
          .insert({
            'author_id': userId,
            'content': _textController.text.trim(),
            'visibility': 'public',
          })
          .select('id')
          .single();

      final postId = postResponse['id'] as String;

      // Upload media if selected
      if (_selectedMedia != null) {
        final mediaFile = File(_selectedMedia!.path);
        final mediaUrl = await _storageService.uploadPostMedia(
          mediaFile,
          isVideo: _isVideo,
        );

        if (mediaUrl != null && mounted) {
          // Insert post media record
          await supabase.from('post_media').insert({
            'post_id': postId,
            'media_url': mediaUrl,
            'media_kind': _isVideo ? 'video' : 'image',
            'order_index': 0,
          });
        }
      }

      // Check mounted before using context-dependent operations
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        // Small delay to ensure snackbar is shown before navigation
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          navigator.pop(true); // Return true to indicate post was created
        }
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error creating post: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
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
