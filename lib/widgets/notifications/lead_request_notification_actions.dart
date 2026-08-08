import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../utils/lead_request_ui_state.dart';

/// Compact action row for provider connection-request notifications.
class LeadRequestNotificationActions extends StatelessWidget {
  final LeadRequestUiState uiState;
  final bool isBusy;
  final VoidCallback? onViewProfile;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const LeadRequestNotificationActions({
    super.key,
    required this.uiState,
    this.isBusy = false,
    this.onViewProfile,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (uiState == LeadRequestUiState.accepted) {
      return _ResolvedLabel(
        icon: Icons.check_circle_rounded,
        label: 'Connection accepted',
        color: const Color(0xFF3ED598),
      );
    }
    if (uiState == LeadRequestUiState.declined) {
      return _ResolvedLabel(
        icon: Icons.cancel_rounded,
        label: 'Request declined',
        color: cs.onSurfaceVariant,
      );
    }
    if (uiState == LeadRequestUiState.cancelled) {
      return _ResolvedLabel(
        icon: Icons.block_rounded,
        label: 'Request cancelled',
        color: cs.onSurfaceVariant,
      );
    }
    if (!leadRequestShowsActions(uiState)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: isBusy ? null : onViewProfile,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurface,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            minimumSize: const Size.fromHeight(34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text(
            'View Profile',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? null : onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size.fromHeight(34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Decline',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy ? null : onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size.fromHeight(34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Accept',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResolvedLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResolvedLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDeclineLeadRequest(BuildContext context) async {
  HapticFeedback.selectionClick();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Decline this request?'),
        content: const Text(
          'The client will be notified that you declined their connection request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Decline', style: TextStyle(color: cs.error)),
          ),
        ],
      );
    },
  );
  return result == true;
}
