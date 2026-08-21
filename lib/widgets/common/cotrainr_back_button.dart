import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Shared page-back control: chevron, 44dp target, stack-aware navigation.
class CotrainrBackButton extends StatelessWidget {
  final String? fallbackRoute;
  final VoidCallback? onPressed;
  final Color? color;

  const CotrainrBackButton({
    super.key,
    this.fallbackRoute,
    this.onPressed,
    this.color,
  });

  static const iconSize = 32.0;
  static const tapTarget = 48.0;

  static bool canNavigateBack(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) return true;
    try {
      return GoRouter.maybeOf(context) != null && context.canPop();
    } catch (_) {
      return false;
    }
  }

  /// Pops the current page when history exists. Otherwise goes to [fallbackRoute].
  static void popOrFallback(
    BuildContext context, {
    String? fallbackRoute,
  }) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    try {
      if (GoRouter.maybeOf(context) != null && context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}
    if (fallbackRoute != null && fallbackRoute.isNotEmpty) {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: IconButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          if (onPressed != null) {
            onPressed!();
            return;
          }
          popOrFallback(context, fallbackRoute: fallbackRoute);
        },
        icon: Icon(
          Icons.chevron_left_rounded,
          size: iconSize,
          color: color ?? IconTheme.of(context).color,
        ),
        tooltip: 'Back',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: tapTarget,
          minHeight: tapTarget,
        ),
        splashRadius: 24,
      ),
    );
  }
}

/// Standard child-page app bar: `<` chevron + title.
class CotrainrAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? titleWidget;
  final bool implyLeading;
  final double? titleSpacing;

  const CotrainrAppBar({
    super.key,
    this.title = '',
    this.fallbackRoute,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.titleWidget,
    this.implyLeading = true,
    this.titleSpacing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: implyLeading
          ? CotrainrBackButton(
              fallbackRoute: fallbackRoute,
              color: foregroundColor,
            )
          : null,
      leadingWidth: implyLeading ? CotrainrBackButton.tapTarget + 8 : 0,
      titleSpacing: titleSpacing ?? 0,
      title: titleWidget ??
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      actions: actions,
    );
  }
}

/// Lets Android/iOS system back use the same pop-or-fallback rule.
class CotrainrPopScope extends StatelessWidget {
  final String? fallbackRoute;
  final Widget child;

  const CotrainrPopScope({
    super.key,
    this.fallbackRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = CotrainrBackButton.canNavigateBack(context);
    Widget tree = PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        CotrainrBackButton.popOrFallback(
          context,
          fallbackRoute: fallbackRoute,
        );
      },
      child: child,
    );
    // GoRouter skips Navigator.maybePop when canPop is false, so PopScope
    // never runs. Listen at the router dispatcher instead.
    if (!canPop && Router.maybeOf(context) != null) {
      tree = BackButtonListener(
        onBackButtonPressed: () async {
          CotrainrBackButton.popOrFallback(
            context,
            fallbackRoute: fallbackRoute,
          );
          return true;
        },
        child: tree,
      );
    }
    return tree;
  }
}
