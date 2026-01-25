import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;

class ImageCropPage extends StatefulWidget {
  final File imageFile;

  const ImageCropPage({super.key, required this.imageFile});

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  late final CropController _cropController;
  double? _aspectRatio;
  bool _isProcessing = false;
  bool _hasNavigated = false;
  Uint8List? _imageBytes;

  final _gradient = const LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.imageFile.readAsBytesSync();
    _cropController = CropController();
  }

  void _handleCrop() {
    if (_isProcessing || !mounted || _hasNavigated) return;
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);
    try {
      debugPrint('Calling crop controller...');
      // Ensure crop is called properly
      _cropController.crop();
      debugPrint('Crop controller called successfully');
    } catch (e, stackTrace) {
      debugPrint('Error cropping: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping image: $e')),
        );
      }
    }
  }

  void _handleBack() {
    if (!mounted || _hasNavigated) return;
    Navigator.of(context).pop();
  }

  void _rotateImage() {
    HapticFeedback.lightImpact();
    final bytes = _imageBytes ?? widget.imageFile.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final rotated = img.copyRotate(decoded, angle: 90);
      setState(() {
        _imageBytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 100));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageData = _imageBytes ?? widget.imageFile.readAsBytesSync();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop || _hasNavigated) return;
        _handleBack();
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor = isDark
              ? const Color(0xFF1A2335) // Dark blue-black mix
              : const Color(0xFFE3F2FD); // Very light blue
          return Container(
            color: backgroundColor,
            child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
          onPressed: _isProcessing ? null : _handleBack,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton(
              onPressed: _isProcessing ? null : _handleCrop,
              child: Text(
                _isProcessing ? 'Processing...' : 'Done',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Crop area
          Center(
            child: Crop(
              image: imageData,
              controller: _cropController,
              onCropped: (result) {
                if (!mounted || _hasNavigated) return;
                _hasNavigated = true;
                
                // Extract cropped data from CropResult
                final croppedData = (result as dynamic).data as Uint8List?;
                
                if (croppedData != null) {
                  debugPrint('Crop completed, bytes length: ${croppedData.length}');
                  // Navigate immediately with the cropped result
                  Future.microtask(() {
                    if (mounted) {
                      setState(() => _isProcessing = false);
                      Navigator.of(context).pop(croppedData);
                    }
                  });
                } else {
                  debugPrint('Crop result is null or invalid. Result type: ${result.runtimeType}');
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to crop image')),
                    );
                  }
                }
              },
              aspectRatio: _aspectRatio,
              radius: 0,
              baseColor: Colors.transparent,
              maskColor: Colors.black.withOpacity(0.7),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Aspect ratio buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _AspectRatioButton(
                          icon: Icons.crop_free,
                          label: 'Free',
                          isActive: _aspectRatio == null,
                          onTap: () {
                            setState(() {
                              _aspectRatio = null;
                              _cropController.aspectRatio = null;
                            });
                          },
                          gradient: _gradient,
                        ),
                        _AspectRatioButton(
                          icon: Icons.crop_square,
                          label: '1:1',
                          isActive: _aspectRatio == 1.0,
                          onTap: () {
                            setState(() {
                              _aspectRatio = 1.0;
                              _cropController.aspectRatio = 1.0;
                            });
                          },
                          gradient: _gradient,
                        ),
                        _AspectRatioButton(
                          icon: Icons.phone_android,
                          label: '9:16',
                          isActive: _aspectRatio == 9 / 16,
                          onTap: () {
                            setState(() {
                              _aspectRatio = 9 / 16;
                              _cropController.aspectRatio = 9 / 16;
                            });
                          },
                          gradient: _gradient,
                        ),
                        _AspectRatioButton(
                          icon: Icons.phone_iphone,
                          label: '16:9',
                          isActive: _aspectRatio == 16 / 9,
                          onTap: () {
                            setState(() {
                              _aspectRatio = 16 / 9;
                              _cropController.aspectRatio = 16 / 9;
                            });
                          },
                          gradient: _gradient,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Rotation button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _rotateImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (rect) =>
                                      _gradient.createShader(rect),
                                  child: const Icon(
                                    Icons.rotate_right,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Rotate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
              ),
            ),
          ),
        ],
      ),
        ),
      ),
            ),
          },
        ),
      ),
    );
  }
}

class _AspectRatioButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final LinearGradient gradient;

  const _AspectRatioButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isActive ? gradient : null,
              color: isActive ? null : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: isActive
                  ? null
                  : Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
            ),
            child: Center(
              child: isActive
                  ? Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    )
                  : ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Colors.white, Colors.white],
                      ).createShader(rect),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
