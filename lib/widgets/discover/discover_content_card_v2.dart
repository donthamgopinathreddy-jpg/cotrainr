import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class DiscoverContentCardV2 extends StatefulWidget {
  final dynamic item; // DiscoverItem
  final bool isFeatured;
  final VoidCallback? onTap;

  const DiscoverContentCardV2({
    super.key,
    required this.item,
    this.isFeatured = false,
    this.onTap,
  });

  @override
  State<DiscoverContentCardV2> createState() => _DiscoverContentCardV2State();
}

class _DiscoverContentCardV2State extends State<DiscoverContentCardV2>
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
    _elevationAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _longPressController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon() {
    if (widget.item.subtitle.toLowerCase().contains('strength') ||
        widget.item.subtitle.toLowerCase().contains('crossfit')) {
      return Icons.fitness_center_rounded;
    } else if (widget.item.subtitle.toLowerCase().contains('hiit')) {
      return Icons.flash_on_rounded;
    } else if (widget.item.subtitle.toLowerCase().contains('yoga')) {
      return Icons.self_improvement_rounded;
    } else if (widget.item.subtitle.toLowerCase().contains('nutrition')) {
      return Icons.restaurant_menu_rounded;
    } else if (widget.item.subtitle.toLowerCase().contains('gym') ||
        widget.item.subtitle.toLowerCase().contains('center')) {
      return Icons.location_city_rounded;
    }
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = widget.isFeatured 
        ? (screenWidth * 0.85).clamp(280.0, 340.0) 
        : double.infinity;
    
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
              width: cardWidth,
              margin: widget.isFeatured
                  ? const EdgeInsets.only(right: DesignTokens.spacing16)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                gradient: widget.isFeatured
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DesignTokens.surfaceOf(context),
                          DesignTokens.surfaceOf(context).withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                color: widget.isFeatured ? null : DesignTokens.surfaceOf(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                border: Border.all(
                  color: _isPressed
                      ? DesignTokens.accentOrange.withValues(alpha: 0.5)
                      : DesignTokens.borderColorOf(context),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.2 + (_elevationAnimation.value * 0.05),
                    ),
                    blurRadius: 25 + (_elevationAnimation.value * 3),
                    offset: Offset(0, 12 + _elevationAnimation.value),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background Pattern (Subtle)
                  if (widget.isFeatured)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: CustomPaint(
                          painter: _FitnessPatternPainter(),
                        ),
                      ),
                    ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row with Category Icon
                        Row(
                          children: [
                            // Category Icon Badge
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: DesignTokens.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: DesignTokens.accentOrange
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getCategoryIcon(),
                                color: Colors.white,
                                size: 24,
                              ),
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
                                            fontWeight: FontWeight.w800,
                                            color: DesignTokens.textPrimaryOf(context),
                                            letterSpacing: 0.3,
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
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                DesignTokens.accentGreen,
                                                DesignTokens.accentGreen
                                                    .withValues(alpha: 0.7),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: DesignTokens.accentGreen
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.verified_rounded,
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
                                      fontWeight: FontWeight.w500,
                                      color: DesignTokens.textSecondaryOf(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Specialties Tags
                        if (widget.item.specialties.isNotEmpty) ...[
                          const SizedBox(height: DesignTokens.spacing12),
                          Wrap(
                            spacing: DesignTokens.spacing8,
                            runSpacing: DesignTokens.spacing8,
                            children: widget.item.specialties.take(2).map((spec) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spacing12,
                                  vertical: DesignTokens.spacing8,
                                ),
                                decoration: BoxDecoration(
                                  color: DesignTokens.accentBlue
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusChip,
                                  ),
                                  border: Border.all(
                                    color: DesignTokens.accentBlue
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  spec,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: DesignTokens.accentBlue,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: DesignTokens.spacing16),

                        // Stats Row
                        Row(
                          children: [
                            // Rating Badge
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
                                boxShadow: [
                                  BoxShadow(
                                    color: DesignTokens.accentOrange
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.item.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: DesignTokens.fontSizeBody,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacing12),
                            // Distance Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DesignTokens.spacing12,
                                vertical: DesignTokens.spacing8,
                              ),
                              decoration: BoxDecoration(
                                color: DesignTokens.surfaceOf(context),
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusChip,
                                ),
                                border: Border.all(
                                  color: DesignTokens.borderColorOf(context),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: DesignTokens.accentOrange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.item.distance.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      fontSize: DesignTokens.fontSizeMeta,
                                      fontWeight: FontWeight.w700,
                                      color: DesignTokens.textPrimaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Experience Badge (if available)
                            if (widget.item.experience != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spacing12,
                                  vertical: DesignTokens.spacing8,
                                ),
                                decoration: BoxDecoration(
                                  color: DesignTokens.accentPurple
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusChip,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.work_outline_rounded,
                                      size: 14,
                                      color: DesignTokens.accentPurple,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        widget.item.experience!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: DesignTokens.accentPurple,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: DesignTokens.spacing12),

                        // Location Row
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 16,
                              color: DesignTokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.item.location,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeMeta,
                                  fontWeight: FontWeight.w500,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom Painter for Fitness Pattern
class _FitnessPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.accentOrange
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines pattern
    for (double i = -size.height; i < size.width + size.height; i += 30) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

