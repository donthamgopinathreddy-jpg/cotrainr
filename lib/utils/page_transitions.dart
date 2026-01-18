import 'package:flutter/material.dart';

class PageTransitions {
  static const Duration _defaultDuration = Duration(milliseconds: 320);
  static const Curve _defaultCurve = Curves.easeOutCubic;

  /// Fade + slight slide up; smooth for modals and sheets.
  static PageRouteBuilder<T> fadeRoute<T extends Object?>(
    Widget page, {
    Duration duration = _defaultDuration,
    Offset slideOffset = const Offset(0, 0.03),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _defaultCurve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Fade + scale (zoom); good for emphasis and detail pushes.
  static PageRouteBuilder<T> scaleFadeRoute<T extends Object?>(
    Widget page, {
    Duration duration = _defaultDuration,
    double beginScale = 0.96,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _defaultCurve);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: beginScale, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide from side + fade; standard for back/forward navigation.
  static PageRouteBuilder<T> slideRoute<T extends Object?>(
    Widget page, {
    Duration duration = _defaultDuration,
    Offset beginOffset = const Offset(0.08, 0.0),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _defaultCurve);
        return SlideTransition(
          position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}
