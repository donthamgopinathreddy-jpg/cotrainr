import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class CocircleCreateFAB extends StatelessWidget {
  final VoidCallback? onTap;

  const CocircleCreateFAB({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: DesignTokens.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: DesignTokens.glowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

