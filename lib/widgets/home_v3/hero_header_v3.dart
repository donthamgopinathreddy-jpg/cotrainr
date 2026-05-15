import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_colors.dart';

/// Premium layered hero: cover with welcome (top-left), avatar inset on the right,
/// streak bottom-left, notification bell on the avatar corner.
class HeroHeaderV3 extends StatefulWidget {
  final String username;
  final int notificationCount;
  final String? coverImageUrl;
  final String? avatarUrl;
  final int streakDays;
  final VoidCallback? onNotificationTap;

  const HeroHeaderV3({
    super.key,
    required this.username,
    required this.notificationCount,
    this.coverImageUrl,
    this.avatarUrl,
    required this.streakDays,
    this.onNotificationTap,
  });

  @override
  State<HeroHeaderV3> createState() => _HeroHeaderV3State();
}

/// Curated fitness atmosphere (runner / golden hour). Replace with asset when available.
const String _kDefaultHeroImageUrl =
    'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=1400&q=85';

/// Slight desaturation to quiet busy photography behind text.
const List<double> _kDesaturateMatrix = <double>[
  0.88, 0.08, 0.08, 0, 0,
  0.08, 0.82, 0.08, 0, 0,
  0.08, 0.08, 0.88, 0, 0,
  0, 0, 0, 1, 0,
];

class _HeroHeaderV3State extends State<HeroHeaderV3>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _avatarPressed = false;
  bool _streakPressed = false;

  static const double _coverRadius = 30;
  static const double _avatarRadius = 29;
  static const double _coverHeight = 142;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _animForDelay(double delayMs) {
    final start = (delayMs / 240).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
  }

  Widget _fadeSlide(Animation<double> anim, Widget child) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  Widget _buildCoverImage() {
    final url = widget.coverImageUrl;
    if (url != null && url.isNotEmpty && !url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradientFallback(),
      );
    }
    final networkUrl =
        (url != null && url.isNotEmpty) ? url : _kDefaultHeroImageUrl;
    return CachedNetworkImage(
      imageUrl: networkUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 280),
      placeholder: (_, __) => _gradientFallback(),
      errorWidget: (_, __, ___) => _gradientFallback(),
    );
  }

  Widget _gradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E),
            Color(0xFF4A148C),
            Color(0xFFBF360C),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    const double avatarSize = 86;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: safeTop + 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            elevation: 14,
            shadowColor: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(_coverRadius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_coverRadius),
              child: SizedBox(
                height: _coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(_kDesaturateMatrix),
                        child: _buildCoverImage(),
                      ),
                    ),
                    // Dark cinematic scrim for depth + readability
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.58),
                            Colors.black.withValues(alpha: 0.68),
                            Colors.black.withValues(alpha: 0.86),
                          ],
                          stops: const [0.0, 0.42, 1.0],
                        ),
                      ),
                    ),
                    // Soft edge vignette (reduced noise vs strong radial)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.15),
                          radius: 1.25,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                    ),
                    // Welcome + name on cover (top-left), clear of avatar column
                    Positioned(
                      left: 14,
                      top: 14,
                      right: 108,
                      child: _fadeSlide(
                        _animForDelay(40),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                height: 1.2,
                                color: Colors.white.withValues(alpha: 0.88),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    offset: const Offset(0, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.username,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.5,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    offset: const Offset(0, 1),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.center,
                        child: _fadeSlide(
                          _animForDelay(0),
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _avatarPressed = true),
                                onTapUp: (_) =>
                                    setState(() => _avatarPressed = false),
                                onTapCancel: () =>
                                    setState(() => _avatarPressed = false),
                                child: AnimatedScale(
                                  scale: _avatarPressed ? 0.97 : 1.0,
                                  duration: const Duration(milliseconds: 100),
                                  child: _SquircleAvatar(
                                    size: avatarSize,
                                    radius: _avatarRadius,
                                    avatarUrl: widget.avatarUrl,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: _fadeSlide(
                                  _animForDelay(100),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        widget.onNotificationTap?.call();
                                      },
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black
                                              .withValues(alpha: 0.42),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.22),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              Icons.notifications_rounded,
                                              color: Colors.white,
                                              size: 22,
                                              shadows: const [
                                                Shadow(
                                                  color: Color(0x99000000),
                                                  offset: Offset(0, 1),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            if (widget.notificationCount > 0)
                                              Positioned(
                                                right: -1,
                                                top: -1,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.red,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.streakDays > 0)
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _fadeSlide(
                          _animForDelay(90),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.black.withValues(alpha: 0.38),
                              border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: _StreakIconBadge(
                                days: widget.streakDays,
                                pressed: _streakPressed,
                                onTapDown: () =>
                                    setState(() => _streakPressed = true),
                                onTap: () {
                                  setState(() => _streakPressed = false);
                                  HapticFeedback.lightImpact();
                                },
                                onTapCancel: () =>
                                    setState(() => _streakPressed = false),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _SquircleAvatar extends StatelessWidget {
  final double size;
  final double radius;
  final String? avatarUrl;

  const _SquircleAvatar({
    required this.size,
    required this.radius,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 0,
            spreadRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white,
              width: 2.5,
            ),
            color: AppColors.surfaceSoft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 2),
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? (avatarUrl!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : Image.file(
                        File(avatarUrl!),
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: AppColors.textPrimary,
                        ),
                      ))
                : const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: AppColors.textPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Lightning bolt + streak count beside it (horizontal).
class _StreakIconBadge extends StatelessWidget {
  final int days;
  final bool pressed;
  final VoidCallback onTapDown;
  final VoidCallback onTap;
  final VoidCallback onTapCancel;

  const _StreakIconBadge({
    required this.days,
    required this.pressed,
    required this.onTapDown,
    required this.onTap,
    required this.onTapCancel,
  });

  static const Color _boltColor = Color(0xFFFFE082);
  static const Color _boltGlow = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    const double boltSize = 24;
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTap: onTap,
      onTapCancel: onTapCancel,
      child: AnimatedScale(
        scale: pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.bolt,
                size: boltSize,
                color: _boltColor,
                shadows: [
                  Shadow(
                    color: _boltGlow.withValues(alpha: 0.55),
                    blurRadius: 10,
                    offset: const Offset(0, 1),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                '$days',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: days >= 100 ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.4,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
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
}
