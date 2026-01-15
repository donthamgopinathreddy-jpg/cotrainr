import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class DiscoverFilterChips extends StatelessWidget {
  final Set<String> selectedChips;
  final ValueChanged<String> onChipToggled;

  const DiscoverFilterChips({
    super.key,
    required this.selectedChips,
    required this.onChipToggled,
  });

  static const List<String> _filterChips = [
    'Goal',
    'Experience',
    'Price Range',
    'Availability',
    'Session Type',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DesignTokens.spacing8,
      runSpacing: DesignTokens.spacing8,
      children: _filterChips.map((chip) {
        final isSelected = selectedChips.contains(chip);
        return _FilterChip(
          label: chip,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            onChipToggled(chip);
          },
        );
      }).toList(),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing16,
                vertical: DesignTokens.spacing8,
              ),
              decoration: BoxDecoration(
                gradient: widget.isSelected
                    ? DesignTokens.primaryGradient
                    : null,
                color: widget.isSelected ? null : DesignTokens.surfaceOf(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.transparent
                      : DesignTokens.borderColorOf(context),
                  width: 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeMeta,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected
                      ? Colors.white
                      : DesignTokens.textPrimaryOf(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

