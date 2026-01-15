import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DiscoverContentCardV3 extends StatefulWidget {
  final dynamic item; // DiscoverItem
  final int categoryIndex; // 0=Trainers, 1=Nutritionists, 2=Centers
  final VoidCallback? onTap;

  const DiscoverContentCardV3({
    super.key,
    required this.item,
    required this.categoryIndex,
    this.onTap,
  });

  @override
  State<DiscoverContentCardV3> createState() => _DiscoverContentCardV3State();
}

class _DiscoverContentCardV3State extends State<DiscoverContentCardV3>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBadgeColor() {
    switch (widget.categoryIndex) {
      case 0: // Trainers
        return DesignTokens.accentOrange;
      case 1: // Nutritionists
        return DesignTokens.accentGreen;
      case 2: // Centers
        return DesignTokens.accentBlue;
      default:
        return DesignTokens.accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.spacing10),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceOf(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.08 + (_elevationAnimation.value * 0.02),
                    ),
                    blurRadius: 12 + (_elevationAnimation.value * 2),
                    offset: Offset(0, 4 + _elevationAnimation.value),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Status Badge
                  Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
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
                          boxShadow: [
                            BoxShadow(
                              color: _getBadgeColor().withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: widget.item.avatarUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 26,
                              )
                            : null,
                      ),
                      // Status Badge
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getBadgeColor(),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DesignTokens.surfaceOf(context),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: DesignTokens.spacing10),

                  // Name & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.name,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeBodySmall,
                                  fontWeight: FontWeight.w700,
                                  color: DesignTokens.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.item.isVerified)
                              Container(
                                margin: const EdgeInsets.only(
                                  left: DesignTokens.spacing6,
                                ),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: _getBadgeColor(),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing2),
                        // Specialization
                        Text(
                          widget.item.subtitle,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeCaption,
                            fontWeight: FontWeight.w500,
                            color: DesignTokens.textSecondaryOf(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DesignTokens.spacing6),
                        // Rating & Distance Row
                        Row(
                          children: [
                            // Rating
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: DesignTokens.accentAmber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.item.rating.toStringAsFixed(1)} (${widget.item.reviews})',
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeCaption,
                                    fontWeight: FontWeight.w600,
                                    color: DesignTokens.textPrimaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: DesignTokens.spacing6),
                            // Dot Separator
                            Container(
                              width: 2.5,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: DesignTokens.textSecondaryOf(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacing6),
                            // Distance
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: DesignTokens.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.item.distance.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeCaption,
                                    fontWeight: FontWeight.w500,
                                    color: DesignTokens.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing2),
                        // Location
                        Text(
                          widget.item.location,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeCaption,
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
            ),
          );
        },
      ),
    );
  }
}
