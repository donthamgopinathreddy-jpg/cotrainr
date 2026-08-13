import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';

/// Compact production startup status (offline / error / retry) on black splash.
class StartupStatusPanel extends StatelessWidget {
  const StartupStatusPanel({
    super.key,
    required this.title,
    required this.body,
    required this.onRetry,
    this.retrying = false,
    this.slowHint = false,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;
  final bool retrying;
  final bool slowHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (slowHint) ...[
            const SizedBox(height: 14),
            Text(
              'Taking a little longer than usual…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: retrying
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onRetry();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.accentOrange,
                disabledBackgroundColor:
                    DesignTokens.accentOrange.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: retrying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Try Again',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
