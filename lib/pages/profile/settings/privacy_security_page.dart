import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/privacy_preferences_service.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../utils/launch_utils.dart';
import '../../../widgets/profile/account_hub_widgets.dart';
import 'change_password_page.dart';
import 'info_pages.dart';
import '../../../utils/page_transitions.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _service = PrivacyPreferencesService();
  PrivacyPreferences _prefs = const PrivacyPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.load();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    try {
      await _service.save(_prefs);
      if (mounted) {
        showHubSnackBar(context, 'Privacy settings saved');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showHubSnackBar(context, 'Could not save settings');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showHubConfirmDialog(
      context,
      title: 'Delete Account?',
      message:
          'This action cannot be undone. Account deletion is not yet available in the app — contact support to request removal.',
      confirmLabel: 'Contact Support',
      isDanger: true,
    );
    if (!ok || !mounted) return;
    LaunchUtils.sendEmail(
      context,
      to: LaunchUtils.supportEmail,
      subject: 'Account deletion request',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Privacy & Security'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                HubSectionCard(
                  title: 'Security',
                  animationDelayMs: 0,
                  child: Column(
                    children: [
                      HubActionRow(
                        icon: Icons.lock_outline_rounded,
                        title: 'Change Password',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageTransitions.slideRoute(
                              const ChangePasswordPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      HubActionRow(
                        icon: Icons.phonelink_lock_outlined,
                        title: 'Two-Factor Authentication',
                        trailing: const ComingSoonBadge(),
                        onTap: () => showHubSnackBar(
                          context,
                          'Two-factor authentication coming soon',
                        ),
                      ),
                      const Divider(height: 1),
                      HubActionRow(
                        icon: Icons.devices_outlined,
                        title: 'Active Sessions',
                        trailing: const ComingSoonBadge(),
                        onTap: () => showHubSnackBar(
                          context,
                          'Session management coming soon',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Data Sharing',
                  animationDelayMs: 40,
                  child: Column(
                    children: [
                      HubToggleRow(
                        title: 'Share Activity Data with Trainer',
                        value: _prefs.shareActivityWithTrainer,
                        onChanged: (v) => setState(
                          () => _prefs =
                              _prefs.copyWith(shareActivityWithTrainer: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Share Meal Data with Trainer',
                        value: _prefs.shareMealsWithTrainer,
                        onChanged: (v) => setState(
                          () => _prefs =
                              _prefs.copyWith(shareMealsWithTrainer: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Share Nutrition Data with Nutritionist',
                        value: _prefs.shareNutritionWithNutritionist,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(
                            shareNutritionWithNutritionist: v,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Share Health Metrics with Providers',
                        value: _prefs.shareHealthMetricsWithProviders,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(
                            shareHealthMetricsWithProviders: v,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Location',
                  animationDelayMs: 80,
                  child: HubToggleRow(
                    title: 'Location Access',
                    subtitle:
                        'Used for nearby fitness places and Discover.',
                    value: _prefs.locationAccess,
                    onChanged: (v) => setState(
                      () => _prefs = _prefs.copyWith(locationAccess: v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Legal / Data',
                  animationDelayMs: 120,
                  child: Column(
                    children: [
                      HubActionRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'View Privacy Policy',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      HubActionRow(
                        icon: Icons.download_outlined,
                        title: 'Download My Data',
                        trailing: const ComingSoonBadge(),
                        onTap: () => showHubSnackBar(
                          context,
                          'Data export coming soon',
                        ),
                      ),
                      const Divider(height: 1),
                      HubDangerButton(
                        label: 'Delete Account',
                        onTap: _confirmDeleteAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Contact',
                  animationDelayMs: 160,
                  child: Column(
                    children: [
                      HubActionRow(
                        icon: Icons.email_outlined,
                        title: 'support@cotrainr.com',
                        subtitle: 'Support',
                        showChevron: false,
                        onTap: () => LaunchUtils.sendEmail(
                          context,
                          to: LaunchUtils.supportEmail,
                          subject: 'Privacy & Security',
                        ),
                      ),
                      const Divider(height: 1),
                      HubActionRow(
                        icon: Icons.mail_outline_rounded,
                        title: 'noreply@cotrainr.com',
                        subtitle: 'Legal / Automated',
                        showChevron: false,
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
