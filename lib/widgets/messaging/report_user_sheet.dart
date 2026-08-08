import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_safety_models.dart';
import '../../services/user_safety_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../common/app_overlays.dart';

/// Multi-step report flow for ChatScreen (reason → details → confirm).
Future<bool> showReportUserFlow(
  BuildContext context, {
  required String reportedUserId,
  required String reportedName,
  String? conversationId,
  UserSafetyService? safetyService,
}) async {
  final service = safetyService ?? UserSafetyService();
  String? reasonId;

  reasonId = await showAppBottomSheet<String>(
    context: context,
    builder: (ctx) => _ReportReasonSheet(reportedName: reportedName),
  );
  if (reasonId == null || !context.mounted) return false;

  final details = await showAppBottomSheet<String?>(
    context: context,
    builder: (ctx) => _ReportDetailsSheet(
      reasonId: reasonId!,
      reportedName: reportedName,
    ),
  );
  // null = cancelled; empty string = submitted with no details
  if (details == null || !context.mounted) return false;

  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Submit this report?'),
      content: const Text(
        "Reports are reviewed by the Cotrainr team.\n"
        "The person you're reporting won't be told who submitted the report.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await service.submitReport(
      reportedUserId: reportedUserId,
      reasonId: reasonId,
      details: details.trim().isEmpty ? null : details.trim(),
      conversationId: conversationId,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
    return false;
  }

  if (!context.mounted) return true;

  final wantBlock = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report submitted'),
      content: const Text(
        "Thanks for letting us know. We'll review the report.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Done'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Block this user'),
        ),
      ],
    ),
  );

  if (wantBlock == true && context.mounted) {
    // Caller may treat a true return as "submitted"; block is offered separately
    // via returning a special sentinel — use Navigator result on a wrapper.
    // For simplicity, trigger block here if user chose it.
    try {
      await service.blockUser(reportedUserId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  return true;
}

class _ReportReasonSheet extends StatefulWidget {
  final String reportedName;
  const _ReportReasonSheet({required this.reportedName});

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report this user',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Why are you reporting ${widget.reportedName}?',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final opt in UserReportReasons.options)
                  RadioListTile<String>(
                    value: opt.id,
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v),
                    title: Text(opt.label, style: const TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: DesignTokens.accentOrange,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, _selected);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.accentOrange,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailsSheet extends StatefulWidget {
  final String reasonId;
  final String reportedName;

  const _ReportDetailsSheet({
    required this.reasonId,
    required this.reportedName,
  });

  @override
  State<_ReportDetailsSheet> createState() => _ReportDetailsSheetState();
}

class _ReportDetailsSheetState extends State<_ReportDetailsSheet> {
  final _controller = TextEditingController();
  static const _max = 500;

  bool get _otherRequired => widget.reasonId == UserReportReasons.other;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final text = _controller.text.trim();
    final canSubmit = !_otherRequired || text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        16 + bottom + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Additional details${_otherRequired ? '' : ' (optional)'}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            UserReportReasons.labelFor(widget.reasonId),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: _max,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tell us what happened...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: !canSubmit
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, _controller.text);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
