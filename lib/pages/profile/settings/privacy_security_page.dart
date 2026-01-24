import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/launch_utils.dart';
import '../settings/info_pages.dart';

class PrivacySecurityResult {
  final bool privateAccount;
  final bool showLocation;

  const PrivacySecurityResult({
    required this.privateAccount,
    required this.showLocation,
  });
}

class PrivacySecurityPage extends StatefulWidget {
  final bool privateAccount;
  final bool showLocation;

  const PrivacySecurityPage({
    super.key,
    required this.privateAccount,
    required this.showLocation,
  });

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  late bool _privateAccount;
  late bool _showLocation;

  @override
  void initState() {
    super.initState();
    _privateAccount = widget.privateAccount;
    _showLocation = widget.showLocation;
  }

  void _save() {
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      PrivacySecurityResult(
        privateAccount: _privateAccount,
        showLocation: _showLocation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? cs.surface : const Color(0xFFFFF3E0);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Privacy & Security'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionCard(
            title: 'Account privacy',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _privateAccount,
                  onChanged: (v) => setState(() => _privateAccount = v),
                  title: const Text('Private account'),
                  subtitle: const Text(
                    'Only approved followers can see your profile and activity.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showLocation,
                  onChanged: (v) => setState(() => _showLocation = v),
                  title: const Text('Show location'),
                  subtitle: const Text(
                    'Allow showing your location on posts and profile.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Privacy policy',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('View Privacy Policy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Contact',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('support@cotrainr.com'),
                  subtitle: const Text('Support'),
                  onTap: () => LaunchUtils.sendEmail(
                    context,
                    to: LaunchUtils.supportEmail,
                    subject: 'Privacy & Security',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('noreply@cotrainr.com'),
                  subtitle: const Text('Legal/Automated'),
                  onTap: () => LaunchUtils.sendEmail(
                    context,
                    to: LaunchUtils.noReplyEmail,
                    subject: 'Privacy & Security',
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

