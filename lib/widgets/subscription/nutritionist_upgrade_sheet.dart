import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/subscription_plans.dart';
import '../../theme/design_tokens.dart';
import '../common/app_overlays.dart';

/// Upgrade sheet for Free users attempting nutritionist connect / message / book.
Future<void> showNutritionistUpgradeSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showAppBottomSheet<void>(
    context: context,
    builder: (ctx) => const _NutritionistUpgradeSheet(),
  );
}

class _NutritionistUpgradeSheet extends StatelessWidget {
  const _NutritionistUpgradeSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DesignTokens.accentOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: DesignTokens.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlock Nutritionist Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Browse profiles for free, then upgrade to connect, message, '
            'book consultations and receive meal plans.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Included with',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlanChip(label: SubscriptionPlans.displayName(SubscriptionPlans.basic)),
              _PlanChip(
                label: SubscriptionPlans.displayName(SubscriptionPlans.unlimited),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Not Now',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String label;

  const _PlanChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignTokens.accentOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: DesignTokens.accentOrange.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: DesignTokens.accentOrange,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
