import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../video_sessions/video_session_notification_logic.dart';

class VideoSessionRejectResult {
  final String reasonCode;
  final String? reasonText;

  const VideoSessionRejectResult({
    required this.reasonCode,
    this.reasonText,
  });
}

Future<VideoSessionRejectResult?> showVideoSessionRejectSheet({
  required BuildContext context,
  required String counterpartDisplayName,
}) {
  return showModalBottomSheet<VideoSessionRejectResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _VideoSessionRejectSheet(
      counterpartDisplayName: counterpartDisplayName,
    ),
  );
}

class _VideoSessionRejectSheet extends StatefulWidget {
  final String counterpartDisplayName;

  const _VideoSessionRejectSheet({required this.counterpartDisplayName});

  @override
  State<_VideoSessionRejectSheet> createState() =>
      _VideoSessionRejectSheetState();
}

class _VideoSessionRejectSheetState extends State<_VideoSessionRejectSheet> {
  String? _code;
  final _otherCtrl = TextEditingController();

  static const _options = [
    ('cant_attend', "Can't attend"),
    ('running_late', 'Running late'),
    ('need_to_reschedule', 'Need to reschedule'),
    ('emergency', 'Emergency'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code;
    if (code == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      VideoSessionRejectResult(
        reasonCode: code,
        reasonText: code == 'other' ? _otherCtrl.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.counterpartDisplayName.trim().isEmpty
        ? 'them'
        : widget.counterpartDisplayName.trim();
    final canSubmit = _code != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: AccountHubTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Can't attend?",
                style: AccountHubTheme.rowTitle(context).copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Let $name know why.',
                style: AccountHubTheme.rowSubtitle(context),
              ),
              const SizedBox(height: 16),
              for (final option in _options)
                RadioListTile<String>(
                  value: option.$1,
                  groupValue: _code,
                  onChanged: (v) => setState(() => _code = v),
                  activeColor: DesignTokens.videoSessionsAccent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.$2,
                    style: AccountHubTheme.rowTitle(context).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_code == 'other') ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _otherCtrl,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add a short note (optional)',
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: DesignTokens.videoSessionsAccent
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: DesignTokens.videoSessionsAccent,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        minimumSize: const Size(0, 48),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.22),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.videoSessionsAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: DesignTokens
                            .videoSessionsAccent
                            .withValues(alpha: 0.35),
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

String rejectReasonPreview(String code, {String? otherText}) =>
    VideoSessionNotificationLogic.rejectReasonLabel(code, otherText: otherText);
