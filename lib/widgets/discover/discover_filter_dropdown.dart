import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class DiscoverFilterDropdown extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? value;
  final ValueChanged<String?> onChanged;

  const DiscoverFilterDropdown({
    super.key,
    required this.label,
    required this.icon,
    this.value,
    required this.onChanged,
  });

  @override
  State<DiscoverFilterDropdown> createState() => _DiscoverFilterDropdownState();
}

class _DiscoverFilterDropdownState extends State<DiscoverFilterDropdown>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showFilterOptions() {
    HapticFeedback.lightImpact();
    // TODO: Show filter options bottom sheet
    // For now, just toggle a simple value
    if (widget.label == 'Within 5km') {
      widget.onChanged(widget.value == '5km' ? null : '5km');
    } else if (widget.label == 'Nearest') {
      widget.onChanged(widget.value == 'nearest' ? null : 'nearest');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.value != null;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        _showFilterOptions();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing16,
                vertical: DesignTokens.spacing12,
              ),
              decoration: BoxDecoration(
                gradient: isActive ? DesignTokens.primaryGradient : null,
                color: isActive ? null : DesignTokens.surfaceOf(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : DesignTokens.borderColorOf(context),
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: isActive
                        ? Colors.white
                        : DesignTokens.textSecondaryOf(context),
                  ),
                  const SizedBox(width: DesignTokens.spacing8),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : DesignTokens.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing8),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 20,
                    color: isActive
                        ? Colors.white
                        : DesignTokens.textSecondaryOf(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

