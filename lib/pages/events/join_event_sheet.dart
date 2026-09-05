import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/community_event.dart';
import '../../providers/community_events_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/event_registration_validation.dart';
import '../../widgets/common/app_overlays.dart';

/// Opens the Join Event registration sheet.
Future<void> showJoinEventSheet(
  BuildContext context, {
  required CommunityEventCardData data,
  required VoidCallback onRegistered,
}) {
  HapticFeedback.selectionClick();
  return showAppBottomSheet<void>(
    context: context,
    builder: (ctx) => _JoinEventSheet(
      data: data,
      onRegistered: onRegistered,
    ),
  );
}

class _JoinEventSheet extends ConsumerStatefulWidget {
  const _JoinEventSheet({
    required this.data,
    required this.onRegistered,
  });

  final CommunityEventCardData data;
  final VoidCallback onRegistered;

  @override
  ConsumerState<_JoinEventSheet> createState() => _JoinEventSheetState();
}

class _JoinEventSheetState extends ConsumerState<_JoinEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _prefillLoading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPrefill();
  }

  Future<void> _loadPrefill() async {
    try {
      final prefill = await ref
          .read(communityEventsRepositoryProvider)
          .fetchProfilePrefill();
      if (!mounted) return;
      setState(() {
        if (prefill.name != null && prefill.name!.isNotEmpty) {
          _nameCtrl.text = prefill.name!;
        }
        if (prefill.phone != null && prefill.phone!.isNotEmpty) {
          _phoneCtrl.text = prefill.phone!;
        }
        if (prefill.email != null && prefill.email!.isNotEmpty) {
          _emailCtrl.text = prefill.email!;
        }
        _prefillLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _prefillLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _submitting = true);
    try {
      final result = await ref.read(communityEventsRepositoryProvider).register(
            eventId: widget.data.event.id,
            name: _nameCtrl.text,
            phone: _phoneCtrl.text,
            email: _emailCtrl.text,
          );

      if (!mounted) return;

      if (result.ok || result.alreadyRegistered) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        widget.onRegistered();
        messenger.showSnackBar(
          const SnackBar(
            content: Text("You're registered for this event."),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            EventRegistrationValidation.sanitizedRegistrationError(
              result.errorCode,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom + viewInsets),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join ${widget.data.event.title}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Confirm your details for this event only. '
                'Changes here do not update your profile.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_prefillLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else ...[
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: EventRegistrationValidation.nameError,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone *',
                    border: OutlineInputBorder(),
                  ),
                  validator: EventRegistrationValidation.phoneError,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                  ),
                  validator: EventRegistrationValidation.emailError,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 14),
                Text(
                  'By joining, you agree that Cotrainr may contact you about '
                  'this event by email and WhatsApp using the details you provide.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_submitting || _prefillLoading)
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Join Event'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
