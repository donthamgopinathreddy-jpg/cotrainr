import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode_provider.dart';

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
          onChanged: (mode) =>
              ref.read(themeModeProvider.notifier).state = mode,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _indexFromMode(themeMode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withOpacity(0.6)
            : cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.06),
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
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
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
                  _buildSegment(context, 0, Icons.brightness_auto_rounded, selected, cs),
                  _buildSegment(context, 1, Icons.light_mode_rounded, selected, cs),
                  _buildSegment(context, 2, Icons.dark_mode_rounded, selected, cs),
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
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(_modeFromIndex(index));
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Icon(
            icon,
            size: 22,
            color: isSelected ? Colors.white : cs.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
