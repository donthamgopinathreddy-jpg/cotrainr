import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/subscription_plans.dart';
import '../../theme/design_tokens.dart';
import '../common/app_overlays.dart';

/// Shown when monthly unique provider connection quota is exhausted.
Future<void> showConnectionLimitSheet(
  BuildContext context, {
  required String plan,
  int? limit,
}) {
  HapticFeedback.mediumImpact();
  final resolvedLimit =
      limit ?? SubscriptionPlans.monthlyConnectionRequestLimit(plan) ?? 5;
  final planName = SubscriptionPlans.displayName(plan);

  return showAppBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final textPrimary = DesignTokens.textPrimaryOf(ctx);
      final textSecondary = DesignTokens.textSecondaryOf(ctx);
      final bottom = MediaQuery.paddingOf(ctx).bottom;

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Monthly connection limit reached',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "You've used all $resolvedLimit new provider requests available "
              'on your $planName plan this month.\n\n'
              'Your existing providers and conversations are still available.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/subscription');
              },
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.accentOrange,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'View Plans',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Not Now',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
