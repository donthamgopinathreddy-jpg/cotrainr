import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen chat image viewer with pinch / double-tap zoom.
class ChatImageViewerPage extends StatefulWidget {
  final String? imageUrl;
  final String? imagePath;
  final String? heroTag;

  const ChatImageViewerPage({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.heroTag,
  }) : assert(imageUrl != null || imagePath != null);

  static Future<void> open(
    BuildContext context, {
    String? imageUrl,
    String? imagePath,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ChatImageViewerPage(
          imageUrl: imageUrl,
          imagePath: imagePath,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ChatImageViewerPage> createState() => _ChatImageViewerPageState();
}

class _ChatImageViewerPageState extends State<ChatImageViewerPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late AnimationController _animController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final a = _animation;
        if (a != null) _transform.value = a.value;
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final details = _doubleTapDetails;
    final current = _transform.value;
    final isZoomed = current.getMaxScaleOnAxis() > 1.05;
    Matrix4 end;
    if (isZoomed) {
      end = Matrix4.identity();
    } else if (details != null) {
      final position = details.localPosition;
      end = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    } else {
      end = Matrix4.identity()..scale(2.0);
    }
    _animation = Matrix4Tween(begin: current, end: end).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: _buildImage(),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 8,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final path = widget.imagePath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _error(),
      );
    }
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return _error();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
      ),
      errorWidget: (_, __, ___) => _error(),
    );
  }

  Widget _error() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
        SizedBox(height: 12),
        Text(
          'Could not load image',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
