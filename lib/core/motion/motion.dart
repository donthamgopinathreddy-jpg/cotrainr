import 'package:flutter/material.dart';

/// Global Motion System
/// Centralized motion tokens for consistent animations across the app
class Motion {
  // ========== DURATIONS ==========
  /// Fast micro-interactions (press feedback, toggles)
  static const Duration fast = Duration(milliseconds: 150);
  
  /// Standard transitions (page transitions, card animations)
  static const Duration standard = Duration(milliseconds: 250);
  
  /// Smooth transitions (larger movements, modal presentations)
  static const Duration smooth = Duration(milliseconds: 300);
  
  /// Slow, deliberate animations (complex transitions, emphasis)
  static const Duration slow = Duration(milliseconds: 400);

  // ========== CURVES ==========
  /// Primary curve for most animations (fastOutSlowIn - smooth, natural, iOS-like)
  static const Curve primaryCurve = Curves.fastOutSlowIn;
  
  /// For spring-like, bouncy animations
  static const Curve springCurve = Curves.easeOutBack;
  
  /// For fast, snappy interactions
  static const Curve snapCurve = Curves.easeOut;
  
  /// For large transitions (fastOutSlowIn)
  static const Curve largeTransitionCurve = Curves.fastOutSlowIn;
  
  /// For page transitions (smooth, polished feel)
  static const Curve pageTransitionCurve = Curves.fastOutSlowIn;

  // ========== PAGE TRANSITIONS ==========
  /// Standard page transition duration (optimized for smoothness)
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  
  /// Reverse page transition duration (slightly faster for snappy back navigation)
  static const Duration pageTransitionReverseDuration = Duration(milliseconds: 250);
  
  /// Slide offset for page transitions (subtle vertical movement)
  static const Offset pageSlideOffset = Offset(0, 0.02);
  
  /// Horizontal slide offset for side navigation
  static const Offset pageSlideHorizontalOffset = Offset(0.05, 0);

  // ========== PRESS INTERACTIONS ==========
  /// Scale value when pressed (0.98 = 2% smaller)
  static const double pressScale = 0.98;
  
  /// Duration for press/release animations
  static const Duration pressDuration = Duration(milliseconds: 120);
  
  /// Curve for press animations
  static const Curve pressCurve = Curves.easeOut;

  // ========== STAGGER ANIMATIONS ==========
  /// Delay between staggered items (50ms per item)
  static const Duration staggerDelay = Duration(milliseconds: 50);
  
  /// Initial delay for first item in staggered list
  static const Duration staggerInitialDelay = Duration(milliseconds: 100);
  
  /// Calculate delay for item at [index] in a staggered list
  static Duration staggerDelayFor(int index) {
    return Duration(
      milliseconds: staggerInitialDelay.inMilliseconds + (index * staggerDelay.inMilliseconds),
    );
  }

  // ========== MODAL TRANSITIONS ==========
  /// Slide up offset for bottom sheets and modals
  static const Offset modalSlideUpOffset = Offset(0, 0.1);
  
  /// Duration for modal presentations
  static const Duration modalDuration = Duration(milliseconds: 300);

  // ========== FADE ANIMATIONS ==========
  /// Standard fade duration
  static const Duration fadeDuration = Duration(milliseconds: 200);
  
  /// Fast fade for micro-interactions
  static const Duration fadeFastDuration = Duration(milliseconds: 150);

  // ========== HELPER METHODS ==========
  /// Create a curved animation from a parent animation
  static CurvedAnimation curvedAnimation(
    Animation<double> parent, {
    Curve curve = primaryCurve,
  }) {
    return CurvedAnimation(parent: parent, curve: curve);
  }

  /// Create a tween animation builder with standard settings
  static TweenAnimationBuilder<T> tweenBuilder<T extends Object>({
    required T begin,
    required T end,
    required Duration duration,
    required Widget Function(BuildContext, T, Widget?) builder,
    Curve curve = primaryCurve,
    Widget? child,
  }) {
    return TweenAnimationBuilder<T>(
      tween: Tween<T>(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: builder,
      child: child,
    );
  }

  /// Standard page transition builder (smooth fade + subtle slide with scale)
  static Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)
      standardPageTransition({
    Offset slideOffset = pageSlideOffset,
    Duration duration = pageTransitionDuration,
    Curve curve = pageTransitionCurve,
  }) {
    return (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve);
      
      // Use a subtle scale + fade + slide for smooth transitions
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset,
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.99,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            )),
            child: child,
          ),
        ),
      );
    };
  }
  
  /// Smooth horizontal slide transition (for side navigation)
  static Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)
      horizontalSlideTransition({
    Offset slideOffset = pageSlideHorizontalOffset,
    Duration duration = pageTransitionDuration,
    Curve curve = pageTransitionCurve,
  }) {
    return (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve);
      
      return SlideTransition(
        position: Tween<Offset>(
          begin: slideOffset,
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    };
  }

  /// Fade-only transition (for tab navigation, no slide)
  static Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)
      fadeOnlyTransition({
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) {
    return (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: curve,
        ),
        child: child,
      );
    };
  }

  /// Modal slide-up transition (for bottom sheets, dialogs)
  static Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)
      modalSlideUpTransition({
    Offset slideOffset = modalSlideUpOffset,
    Duration duration = modalDuration,
    Curve curve = primaryCurve,
  }) {
    return (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    };
  }
}
