import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../common/cover_with_blur_bridge.dart';

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

class _HeroHeaderV3State extends State<HeroHeaderV3>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _avatarPressed = false;
  bool _streakPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _animForDelay(double delayMs) {
    final start = (delayMs / 220).clamp(0.0, 1.0);
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
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 380; // Increased from 320 to show more image
    const double avatarSize = 80;
    const double avatarOverlap = 36; // Increased overlap to free vertical space
    final double safeTop = MediaQuery.of(context).padding.top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;

    // Cover image widget
    Widget coverWidget = Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: widget.coverImageUrl != null && widget.coverImageUrl!.isNotEmpty
          ? Image(
              image: widget.coverImageUrl!.startsWith('http')
                  ? NetworkImage(widget.coverImageUrl!)
                  : FileImage(File(widget.coverImageUrl!)) as ImageProvider,
              fit: BoxFit.cover,
            )
          : null,
    );

    // Overlay content (avatar + welcome text + streak)
    Widget overlayContent = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _fadeSlide(
          _animForDelay(0),
          GestureDetector(
            onTapDown: (_) => setState(() => _avatarPressed = true),
            onTapUp: (_) => setState(() => _avatarPressed = false),
            onTapCancel: () => setState(() => _avatarPressed = false),
            child: AnimatedScale(
              scale: _avatarPressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 90),
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: const CircleBorder(),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.7),
                      width: 1.5,
                    ),
                    image: widget.avatarUrl != null &&
                            widget.avatarUrl!.isNotEmpty
                        ? DecorationImage(
                            image: widget.avatarUrl!.startsWith('http')
                                ? NetworkImage(widget.avatarUrl!)
                                : FileImage(File(widget.avatarUrl!)) as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                        ? AppColors.surfaceSoft
                        : null,
                  ),
                  child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: AppColors.textPrimary,
                          size: 32,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fadeSlide(
                _animForDelay(40),
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.85)
                        : Colors.black.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _fadeSlide(
                _animForDelay(70),
                Text(
                  widget.username,
                  style: GoogleFonts.montserrat(
                    color: textColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        _fadeSlide(
          _animForDelay(110),
          GestureDetector(
            onTapDown: (_) => setState(() => _streakPressed = true),
            onTapUp: (_) {
              setState(() => _streakPressed = false);
              HapticFeedback.lightImpact();
            },
            onTapCancel: () => setState(() => _streakPressed = false),
            child: AnimatedScale(
              scale: _streakPressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 90),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.streakDays}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      height: coverHeight + avatarOverlap,
      child: Stack(
        children: [
          CoverWithBlurBridge(
            height: coverHeight,
            cover: coverWidget,
            overlayContent: overlayContent,
            overlayBottom: 28, // Increased from default 22 to give breathing room
          ),
          // Notification bell (positioned at top right)
          Positioned(
            right: 20,
            top: safeTop + 16,
            child: _fadeSlide(
              _animForDelay(130),
              Material(
                color: Colors.transparent,
                child: InkResponse(
                  radius: 22,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNotificationTap?.call();
                  },
                  child: Stack(
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      if (widget.notificationCount > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
