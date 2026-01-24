import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/launch_utils.dart';

Color _settingsBg(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? cs.surface : const Color(0xFFFFF3E0); // light orange
}

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _settingsBg(context),
      appBar: AppBar(
        backgroundColor: _settingsBg(context),
        elevation: 0,
        title: const Text('Help Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact support and we’ll help you as quickly as possible.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('support@cotrainr.com'),
                  subtitle: const Text('Support'),
                  onTap: () => LaunchUtils.sendEmail(
                    context,
                    to: LaunchUtils.supportEmail,
                    subject: 'Help Center',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.public_rounded),
                  title: const Text('www.cotrainr.com'),
                  subtitle: const Text('Reference (not opened automatically)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _settingsBg(context),
      appBar: AppBar(
        backgroundColor: _settingsBg(context),
        elevation: 0,
        title: const Text('FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _FaqItem(
                  q: 'How do I track meals?',
                  a: 'Open Meal Tracker, choose a meal, and tap Add Food.',
                ),
                _FaqItem(
                  q: 'How do I edit my goals?',
                  a: 'In Meal Tracker, use the Edit Goals button on the top summary card.',
                ),
                _FaqItem(
                  q: 'Where can I get support?',
                  a: 'Email us at support@cotrainr.com.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: const Text('Ask a question'),
              subtitle: const Text('support@cotrainr.com'),
              onTap: () => LaunchUtils.sendEmail(
                context,
                to: LaunchUtils.supportEmail,
                subject: 'FAQ Question',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeedbackFormPage();
  }
}

class ReportProblemPage extends StatelessWidget {
  const ReportProblemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReportProblemFormPage();
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _settingsBg(context),
      appBar: AppBar(
        backgroundColor: _settingsBg(context),
        elevation: 0,
        title: const Text('Terms of Service'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This is a short in-app version of our Terms. For the most current version, visit www.cotrainr.com.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 14),
                _LegalSection(
                  title: '1. Acceptable use',
                  body:
                      'Use CoTrainr responsibly. Don’t misuse the service, attempt unauthorized access, or harm other users.',
                ),
                _LegalSection(
                  title: '2. Accounts',
                  body:
                      'You are responsible for your account activity and keeping access secure.',
                ),
                _LegalSection(
                  title: '3. Contact',
                  body: 'Legal email: noreply@cotrainr.com',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('Email (legal)'),
              subtitle: const Text('noreply@cotrainr.com'),
              onTap: () => LaunchUtils.sendEmail(
                context,
                to: LaunchUtils.noReplyEmail,
                subject: 'Terms of Service',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _settingsBg(context),
      appBar: AppBar(
        backgroundColor: _settingsBg(context),
        elevation: 0,
        title: const Text('Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This page explains how CoTrainr handles your information. For the most current version, visit www.cotrainr.com.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 14),
                _LegalSection(
                  title: 'What we collect',
                  body:
                      'Account and profile details, app usage data, and content you choose to submit.',
                ),
                _LegalSection(
                  title: 'How we use it',
                  body:
                      'To provide the service, improve features, and support users.',
                ),
                _LegalSection(
                  title: 'Contact',
                  body: 'Legal email: noreply@cotrainr.com',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('Email (legal)'),
              subtitle: const Text('noreply@cotrainr.com'),
              onTap: () => LaunchUtils.sendEmail(
                context,
                to: LaunchUtils.noReplyEmail,
                subject: 'Privacy Policy',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        q,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            a,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;
  const _LegalSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackFormPage extends StatefulWidget {
  const _FeedbackFormPage();

  @override
  State<_FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<_FeedbackFormPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    final subject = _subject.text.trim().isEmpty ? 'CoTrainr Feedback' : _subject.text.trim();
    final body = _message.text.trim();
    await LaunchUtils.sendEmail(
      context,
      to: LaunchUtils.supportEmail,
      subject: subject,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _settingsBg(context),
      appBar: AppBar(
        backgroundColor: _settingsBg(context),
        elevation: 0,
        title: const Text('Feedback'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This will open your email app and send to support@cotrainr.com.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportProblemFormPage extends StatefulWidget {
  const _ReportProblemFormPage();

  @override
  State<_ReportProblemFormPage> createState() => _ReportProblemFormPageState();
}

class _ReportProblemFormPageState extends State<_ReportProblemFormPage> {
  final _title = TextEditingController();
  final _steps = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _steps.dispose();
    _expected.dispose();
    _actual.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    final subject =
        _title.text.trim().isEmpty ? 'Report a Problem' : _title.text.trim();
    final body = [
      'Title: $subject',
      '',
      'Steps to reproduce:',
      _steps.text.trim(),
      '',
      'Expected:',
      _expected.text.trim(),
      '',
      'Actual:',
      _actual.text.trim(),
      '',
      'Device/OS:',
      '',
    ].join('\n');
    await LaunchUtils.sendEmail(
      context,
      to: LaunchUtils.supportEmail,
      subject: 'Report a Problem: $subject',
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _settingsBg(context),
      appBar: AppBar(
        backgroundColor: _settingsBg(context),
        elevation: 0,
        title: const Text('Report a Problem'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell us what happened',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _steps,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Steps to reproduce',
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _expected,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Expected behavior',
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actual,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Actual behavior',
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send report'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
