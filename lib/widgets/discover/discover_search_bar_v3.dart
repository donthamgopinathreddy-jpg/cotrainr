import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class DiscoverSearchBarV3 extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onSearchChanged;

  const DiscoverSearchBarV3({
    super.key,
    required this.controller,
    required this.placeholder,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: TextField(
        controller: controller,
        onChanged: onSearchChanged,
        style: TextStyle(
          color: DesignTokens.textPrimaryOf(context),
          fontSize: DesignTokens.fontSizeBodySmall,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            color: DesignTokens.textSecondaryOf(context),
            fontSize: DesignTokens.fontSizeBodySmall,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: DesignTokens.textSecondaryOf(context),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing14,
            vertical: DesignTokens.spacing10,
          ),
        ),
      ),
    );
  }
}
