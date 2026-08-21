import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'home_premium_theme.dart';

/// Compact recoverable error for a single Home section.
class HomeSectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const HomeSectionError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isLight
            ? HomePremiumTheme.lightCreamCard
            : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: DesignTokens.accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
