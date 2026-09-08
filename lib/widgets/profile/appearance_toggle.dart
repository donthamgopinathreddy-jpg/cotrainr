import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode_provider.dart';

/// Tap cycles System → Light → Dark; icon updates with mode. No menu / bubble.
class AppearanceThemeIconButton extends ConsumerWidget {
  const AppearanceThemeIconButton({super.key});

  static IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  static String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  static ThemeMode _nextMode(ThemeMode current) {
    switch (current) {
      case ThemeMode.system:
        return ThemeMode.light;
      case ThemeMode.light:
        return ThemeMode.dark;
      case ThemeMode.dark:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Appearance theme',
      value: _labelFor(mode),
      hint: 'Double tap to cycle theme',
      child: IconButton(
        tooltip: 'Theme: ${_labelFor(mode)}',
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurface,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          overlayColor: cs.primary.withValues(alpha: 0.10),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          final next = _nextMode(mode);
          ref.read(themeModeProvider.notifier).state = next;
          unawaited(saveThemeMode(next));
        },
        icon: Icon(
          _iconFor(mode),
          size: 24,
        ),
      ),
    );
  }
}

/// Shared appearance toggle (System/Light/Dark) with sliding pill animation.
class AppearanceToggle extends StatelessWidget {
  const AppearanceToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeModeProvider);
        return _AppearanceToggleContent(
          themeMode: themeMode,
          onChanged: (mode) {
            ref.read(themeModeProvider.notifier).state = mode;
            unawaited(saveThemeMode(mode));
          },
        );
      },
    );
  }
}

class _AppearanceToggleContent extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  const _AppearanceToggleContent({
    required this.themeMode,
    required this.onChanged,
  });

  int _indexFromMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 0;
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
    }
  }

  ThemeMode _modeFromIndex(int index) {
    switch (index) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 0:
      default:
        return ThemeMode.system;
    }
  }

  static String _segmentLabel(int index) {
    switch (index) {
      case 1:
        return 'Light';
      case 2:
        return 'Dark';
      case 0:
      default:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _indexFromMode(themeMode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.6)
            : cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = 6.0;
          const pillMargin = 0.0;
          final innerWidth = constraints.maxWidth - 2 * padding;
          final segmentWidth = innerWidth / 3;
          final pillWidth = segmentWidth - 2 * pillMargin;
          final pillLeft = padding + pillMargin + selected * segmentWidth;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: reduceMotion ? Curves.linear : Curves.easeOutCubic,
                left: pillLeft,
                top: padding,
                bottom: padding,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.stepsGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildSegment(
                    context,
                    0,
                    Icons.brightness_auto_rounded,
                    selected,
                    cs,
                  ),
                  _buildSegment(
                    context,
                    1,
                    Icons.light_mode_rounded,
                    selected,
                    cs,
                  ),
                  _buildSegment(
                    context,
                    2,
                    Icons.dark_mode_rounded,
                    selected,
                    cs,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    int index,
    IconData icon,
    int selected,
    ColorScheme cs,
  ) {
    final isSelected = index == selected;
    final label = _segmentLabel(index);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label theme',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(_modeFromIndex(index));
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
