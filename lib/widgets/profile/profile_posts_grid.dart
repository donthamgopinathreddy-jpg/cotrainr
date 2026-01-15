import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';

class ProfilePostsGrid extends StatelessWidget {
  final List<String> images;

  const ProfilePostsGrid({
    super.key,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(DesignTokens.spacing32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.grid_off,
                size: 64,
                color: DesignTokens.textSecondaryOf(context),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                'No posts yet',
                style: AppTextStyles.h2(context),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: DesignTokens.spacing8,
          mainAxisSpacing: DesignTokens.spacing8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return _PostGridItem(
            imageUrl: images[index],
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Navigate to post detail
            },
          );
        },
      ),
    );
  }
}

class _PostGridItem extends StatefulWidget {
  final String? imageUrl;
  final VoidCallback? onTap;

  const _PostGridItem({
    required this.imageUrl,
    this.onTap,
  });

  @override
  State<_PostGridItem> createState() => _PostGridItemState();
}

class _PostGridItemState extends State<_PostGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        // TODO: Show options menu
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.imageUrl == null || widget.imageUrl!.isEmpty
                ? DesignTokens.primaryGradient
                : null,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSecondary),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSecondary),
                  child: Image.network(
                    widget.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: DesignTokens.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
