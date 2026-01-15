import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class PillChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final IconData? icon;
  final double? fontSize;
  final LinearGradient? gradient;

  const PillChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.icon,
    this.fontSize,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? (gradient ?? DesignTokens.primaryGradient) : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: DesignTokens.iconSizeList,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: DesignTokens.opacityInactive),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize ?? DesignTokens.fontSizeMeta,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: DesignTokens.opacityInactive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



