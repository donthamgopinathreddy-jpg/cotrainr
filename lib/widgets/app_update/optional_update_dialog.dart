import 'package:flutter/material.dart';

import '../../services/app_version_service.dart';
import '../../theme/design_tokens.dart';

Future<void> showOptionalUpdateDialog(
  BuildContext context,
  AppVersionCheckResult result,
) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Update available'),
      content: const Text(
        'A new version of Cotrainr is available.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await AppVersionService.instance
                .dismissOptionalForVersion(result.config.recommendedVersion);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            await AppVersionService.instance.openStore(
              storeUrl: result.config.storeUrl,
            );
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.accentOrange,
          ),
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
