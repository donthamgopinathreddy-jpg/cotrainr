import 'package:flutter/material.dart';

/// Bottom sheet with drag-down-to-dismiss gesture
/// Wraps showModalBottomSheet with enhanced gesture support
class DraggableBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Animation<Color?>? barrierColor,
    String? barrierLabel,
    bool useSafeArea = false,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor?.value,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
    );
  }
}
