import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../legal/legal_document_meta.dart';
import '../../../legal/privacy_policy_content.dart';
import '../../../legal/terms_of_service_content.dart';
import '../../../services/support_email_composer.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/launch_utils.dart';
import '../../../widgets/auth/auth_ui.dart';
import '../../../widgets/common/app_form_fields.dart';
import '../../../widgets/common/cotrainr_back_button.dart';
import '../../../widgets/legal/legal_document.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({
    super.key,
    this.diagnosticsLoader,
    this.emailSender,
  });

  /// Test seams.
  final Future<SupportDiagnostics> Function()? diagnosticsLoader;
  final Future<bool> Function(
    BuildContext context, {
    required String to,
    String? subject,
    String? body,
  })? emailSender;

  @override
  Widget build(BuildContext context) {
    return _FeedbackFormPage(
      diagnosticsLoader: diagnosticsLoader,
      emailSender: emailSender,
    );
  }
}

class ReportProblemPage extends StatelessWidget {
  const ReportProblemPage({
    super.key,
    this.diagnosticsLoader,
    this.emailSender,
  });

  final Future<SupportDiagnostics> Function()? diagnosticsLoader;
  final Future<bool> Function(
    BuildContext context, {
    required String to,
    String? subject,
    String? body,
  })? emailSender;

  @override
  Widget build(BuildContext context) {
    return _ReportProblemFormPage(
      diagnosticsLoader: diagnosticsLoader,
      emailSender: emailSender,
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: TermsOfServiceContent.title,
      tagline: TermsOfServiceContent.tagline,
      versionLabel: LegalDocumentMeta.version,
      effectiveLabel: LegalDocumentMeta.effectiveDateLabel,
      updatedLabel: LegalDocumentMeta.lastUpdatedLabel,
      atAGlance: TermsOfServiceContent.atAGlance,
      callout: const LegalCallout(
        child: SelectableText(TermsOfServiceContent.introCallout),
      ),
      sections: TermsOfServiceContent.sections,
      contact: const LegalContactSection(
        intro:
            'For questions about these Terms, account issues or deletion requests, email Cotrainr Support.',
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: PrivacyPolicyContent.title,
      tagline: PrivacyPolicyContent.tagline,
      versionLabel: LegalDocumentMeta.version,
      effectiveLabel: LegalDocumentMeta.effectiveDateLabel,
      updatedLabel: LegalDocumentMeta.lastUpdatedLabel,
      atAGlance: PrivacyPolicyContent.atAGlance,
      callout: const LegalCallout(
        child: SelectableText(PrivacyPolicyContent.introCallout),
      ),
      sections: PrivacyPolicyContent.sections,
      contact: const LegalContactSection(
        intro:
            'For privacy questions, data requests or account-deletion requests, email Cotrainr Support.',
      ),
    );
  }
}

class _FeedbackFormPage extends StatefulWidget {
  const _FeedbackFormPage({
    this.diagnosticsLoader,
    this.emailSender,
  });

  final Future<SupportDiagnostics> Function()? diagnosticsLoader;
  final Future<bool> Function(
    BuildContext context, {
    required String to,
    String? subject,
    String? body,
  })? emailSender;

  @override
  State<_FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<_FeedbackFormPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  FeedbackType _type = FeedbackType.suggestion;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_submitting && SupportEmailComposer.isNonEmptyText(_message.text);

  Future<void> _submit() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      final diagnostics =
          await (widget.diagnosticsLoader ?? SupportDiagnostics.load)();
      if (!mounted) return;
      final subject = SupportEmailComposer.feedbackSubject(
        type: _type,
        subject: _subject.text,
      );
      final body = SupportEmailComposer.feedbackBody(
        type: _type,
        message: _message.text,
        diagnostics: diagnostics,
      );
      final sender = widget.emailSender ?? LaunchUtils.sendEmail;
      await sender(
        context,
        to: LaunchUtils.supportEmail,
        subject: subject,
        body: body,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Feedback',
        backgroundColor: bg,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            HubSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help us improve Cotrainr',
                    style: AccountHubTheme.rowTitle(context).copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Feedback type',
                    style: AccountHubTheme.sectionTitle(context),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in FeedbackType.values)
                        _TypeChip(
                          label: type.label,
                          selected: _type == type,
                          onTap: () => setState(() => _type = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subject,
                    textInputAction: TextInputAction.next,
                    decoration: AppFormFields.decoration(
                      context,
                      labelText: 'Subject (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _message,
                    maxLines: 7,
                    minLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    textInputAction: TextInputAction.newline,
                    decoration: AppFormFields.decoration(
                      context,
                      labelText: 'Message',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: 'Send feedback',
                    onPressed: _canSend ? _submit : null,
                    isLoading: _submitting,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your email app will open to send your feedback to '
                    '${LaunchUtils.supportEmail}.',
                    style: AccountHubTheme.rowSubtitle(context).copyWith(
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportProblemFormPage extends StatefulWidget {
  const _ReportProblemFormPage({
    this.diagnosticsLoader,
    this.emailSender,
  });

  final Future<SupportDiagnostics> Function()? diagnosticsLoader;
  final Future<bool> Function(
    BuildContext context, {
    required String to,
    String? subject,
    String? body,
  })? emailSender;

  @override
  State<_ReportProblemFormPage> createState() => _ReportProblemFormPageState();
}

class _ReportProblemFormPageState extends State<_ReportProblemFormPage> {
  final _problem = TextEditingController();
  final _doing = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _problem.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _problem.dispose();
    _doing.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_submitting && SupportEmailComposer.isNonEmptyText(_problem.text);

  Future<void> _submit() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      final diagnostics =
          await (widget.diagnosticsLoader ?? SupportDiagnostics.load)();
      if (!mounted) return;
      final body = SupportEmailComposer.problemBody(
        problem: _problem.text,
        context: _doing.text,
        diagnostics: diagnostics,
      );
      final sender = widget.emailSender ?? LaunchUtils.sendEmail;
      await sender(
        context,
        to: LaunchUtils.supportEmail,
        subject: SupportEmailComposer.problemSubject,
        body: body,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Report a Problem',
        backgroundColor: bg,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            HubSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell us what went wrong',
                    style: AccountHubTheme.rowTitle(context).copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _problem,
                    maxLines: 6,
                    minLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    textInputAction: TextInputAction.newline,
                    decoration: AppFormFields.decoration(
                      context,
                      labelText: 'Problem',
                      hintText: 'Describe what happened',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _doing,
                    maxLines: 4,
                    minLines: 3,
                    textAlignVertical: TextAlignVertical.top,
                    textInputAction: TextInputAction.newline,
                    decoration: AppFormFields.decoration(
                      context,
                      labelText: 'What were you doing when it happened?',
                      hintText:
                          'Example: I was logging a meal and the app closed.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: 'Report problem',
                    onPressed: _canSend ? _submit : null,
                    isLoading: _submitting,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your email app will open to send this report to '
                    '${LaunchUtils.supportEmail}. Safe app version details are '
                    'included automatically.',
                    style: AccountHubTheme.rowSubtitle(context).copyWith(
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = DesignTokens.accentOrange;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : AccountHubTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : cs.outline.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
