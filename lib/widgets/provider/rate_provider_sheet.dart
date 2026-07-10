import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/account_hub_theme.dart';

Future<bool?> showRateProviderSheet({
  required BuildContext context,
  required String providerLabel,
  required Future<void> Function(int rating, String? body) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _RateProviderSheet(
      providerLabel: providerLabel,
      onSubmit: onSubmit,
    ),
  );
}

class _RateProviderSheet extends StatefulWidget {
  final String providerLabel;
  final Future<void> Function(int rating, String? body) onSubmit;

  const _RateProviderSheet({
    required this.providerLabel,
    required this.onSubmit,
  });

  @override
  State<_RateProviderSheet> createState() => _RateProviderSheetState();
}

class _RateProviderSheetState extends State<_RateProviderSheet> {
  int _rating = 0;
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _rating,
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rate ${widget.providerLabel}',
            style: AccountHubTheme.rowTitle(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = star <= _rating;
              return IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = star);
                      },
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AccountHubTheme.subscriptionAmber,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: 'Optional feedback (visible on profile)',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_rating < 1 || _submitting) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit review'),
          ),
        ],
      ),
    );
  }
}
