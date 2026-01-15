import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/design_tokens.dart';
import '../common/pill_chip.dart';

class DiscoverContentCard extends StatefulWidget {
  final dynamic item; // DiscoverItem
  final VoidCallback? onTap;

  const DiscoverContentCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<DiscoverContentCard> createState() => _DiscoverContentCardState();
}

class _DiscoverContentCardState extends State<DiscoverContentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _longPressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _longPressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _longPressController.dispose();
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
        _longPressController.forward();
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        _longPressController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _longPressController]),
        builder: (context, child) {
          final longPressScale = 1.0 + (_longPressController.value * 0.02);
          return Transform.scale(
            scale: _scaleAnimation.value * longPressScale,
            child: Container(
              width: 320,
              margin: const EdgeInsets.only(right: DesignTokens.spacing16),
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.15 + (_elevationAnimation.value * 0.05),
                    ),
                    blurRadius: 20 + (_elevationAnimation.value * 2),
                    offset: Offset(0, 10 + _elevationAnimation.value),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Avatar with Press Effect
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.item.avatarUrl == null
                              ? DesignTokens.primaryGradient
                              : null,
                          image: widget.item.avatarUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    widget.item.avatarUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: _isPressed
                              ? [
                                  BoxShadow(
                                    color: DesignTokens.accentOrange
                                        .withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: widget.item.avatarUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 36,
                              )
                            : null,
                      ),
                      const SizedBox(width: DesignTokens.spacing16),

                      // Name & Verified
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.item.name,
                                    style: TextStyle(
                                      fontSize: DesignTokens.fontSizeH2,
                                      fontWeight: FontWeight.w700,
                                      color: DesignTokens.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.item.isVerified)
                                  Container(
                                    margin: const EdgeInsets.only(
                                      left: DesignTokens.spacing8,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: DesignTokens.accentGreen,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: DesignTokens.accentGreen
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: DesignTokens.spacing4),
                            Text(
                              widget.item.subtitle,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeBody,
                                color: DesignTokens.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: DesignTokens.spacing16),

                  // Rating & Distance Row
                  Row(
                    children: [
                      // Rating with Gradient
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spacing12,
                          vertical: DesignTokens.spacing8,
                        ),
                        decoration: BoxDecoration(
                          gradient: DesignTokens.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusChip,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: DesignTokens.fontSizeMeta,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing12),
                      // Distance Chip
                      PillChip(
                        label: '${widget.item.distance.toStringAsFixed(1)} km',
                        icon: Icons.location_on,
                      ),
                    ],
                  ),

                  const SizedBox(height: DesignTokens.spacing12),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: DesignTokens.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.item.location,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeMeta,
                            color: DesignTokens.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
