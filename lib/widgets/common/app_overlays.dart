import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../theme/design_tokens.dart';

/// Shared smooth modal bottom sheet — fade/slide open & close.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = true,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
}) {
  final bg = backgroundColor ?? DesignTokens.surfaceOf(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    backgroundColor: bg,
    elevation: elevation ?? 0,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.modalDuration,
      reverseDuration: Motion.pageTransitionReverseDuration,
      curve: Motion.primaryCurve,
      reverseCurve: Curves.easeIn,
    ),
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
  );
}

/// Shared dialog with subtle fade + scale.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Motion.modalDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
