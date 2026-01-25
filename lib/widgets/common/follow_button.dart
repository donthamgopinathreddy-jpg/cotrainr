import 'package:flutter/material.dart';
import '../common/pressable_card.dart';

class FollowButton extends StatefulWidget {
  final bool isFollowing;
  final VoidCallback? onTap;
  final double? width;
  final EdgeInsets? padding;

  const FollowButton({
    super.key,
    required this.isFollowing,
    this.onTap,
    this.width,
    this.padding,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static const _cocircleGradient = LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _lightGradient = LinearGradient(
    colors: [
      Color(0xFFB3D9FF), // Light blue
      Color(0xFFD4C5F0), // Light purple
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _animationController.forward(from: 0.0).then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = PressableCard(
      onTap: widget.onTap,
      borderRadius: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        width: widget.width,
        decoration: BoxDecoration(
          gradient: widget.isFollowing ? _lightGradient : _cocircleGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: 1.0 - (_fadeAnimation.value * 0.3),
                child: Text(
                  widget.isFollowing ? 'Following' : 'Follow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.width != null ? 14 : 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isFollowing
                        ? const Color(0xFF4A5568) // Darker text for light gradient
                        : Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: button);
    }
    return button;
  }
}
