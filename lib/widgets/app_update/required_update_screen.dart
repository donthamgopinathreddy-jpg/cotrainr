import 'package:flutter/material.dart';

import '../../services/app_version_service.dart';
import '../../theme/design_tokens.dart';

class RequiredUpdateScreen extends StatelessWidget {
  final AppVersionCheckResult result;
  final VoidCallback onUpdate;

  const RequiredUpdateScreen({
    super.key,
    required this.result,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.darkBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                size: 64,
                color: DesignTokens.accentOrange,
              ),
              const SizedBox(height: 24),
              Text(
                'Update required',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'This version of Cotrainr is no longer supported. '
                'Update to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onUpdate,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Update Cotrainr',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
