import 'package:flutter/material.dart';

import '../../repositories/verification_repository.dart';
import '../../theme/app_colors.dart';
import '../common/pressable_card.dart';

/// Shared Trainer / Nutritionist verification card.
///
/// Driven by the server-authoritative [ProviderVerificationStatus] so both
/// provider profiles render identical, canonical states.
class ProviderVerificationCard extends StatelessWidget {
  const ProviderVerificationCard({
    super.key,
    required this.status,
    required this.role,
    required this.onTap,
  });

  final ProviderVerificationStatus status;
  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleLabel = role == 'nutritionist' ? 'Nutritionist' : 'Trainer';
    final isPending = status == ProviderVerificationStatus.pending;
    final isRejected = status == ProviderVerificationStatus.rejected;

    return PressableCard(
      onTap: onTap,
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.orange.withValues(alpha: isPending ? 0.1 : 0.15),
              AppColors.orange.withValues(alpha: isPending ? 0.05 : 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.orange.withValues(alpha: isPending ? 0.3 : 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isPending
                    ? LinearGradient(
                        colors: [
                          AppColors.orange.withValues(alpha: 0.2),
                          AppColors.orange.withValues(alpha: 0.1),
                        ],
                      )
                    : AppColors.stepsGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPending
                    ? Icons.hourglass_empty
                    : isRejected
                        ? Icons.error_outline_rounded
                        : Icons.verified_user_outlined,
                color: isPending ? AppColors.orange : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPending
                        ? 'Verification Pending'
                        : isRejected
                            ? 'Verification Rejected'
                            : 'Verify Your $roleLabel Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPending
                        ? 'Documents submitted. Please wait up to 24 hours for verification.'
                        : isRejected
                            ? 'Tap to review feedback and submit new documents.'
                            : 'Submit documents to verify your $roleLabel account and unlock all features.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Retry card shown when verification state could not be loaded.
///
/// Never claims the provider is unverified.
class ProviderVerificationErrorCard extends StatelessWidget {
  const ProviderVerificationErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification status unavailable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We couldn’t check your verification status. Try again.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
