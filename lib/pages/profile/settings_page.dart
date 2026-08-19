import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/common/logout_confirmation_sheet.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../subscription/subscription_page.dart';
import 'edit_profile_page.dart';
import 'goals_preferences_page.dart';
import 'settings/change_password_page.dart';
import 'settings/health_devices_page.dart';
import 'settings/help_center_page.dart';
import 'settings/info_pages.dart';
import 'settings/integrations_page.dart';
import 'settings/notifications_page.dart';
import 'settings/privacy_security_page.dart';
import 'settings/service_locations_page.dart';
import '../../repositories/profile_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    this.appVersionLoader,
  });

  /// Optional override for tests. Defaults to [PackageInfo.version].
  final Future<String> Function()? appVersionLoader;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final ProfileRepository _profileRepo = ProfileRepository();
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadAppVersion() async {
    final loader = widget.appVersionLoader ?? _defaultAppVersionLoader;
    try {
      final version = await loader();
      if (!mounted) return;
      setState(() => _appVersion = version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = '');
    }
  }

  static Future<String> _defaultAppVersionLoader() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  String? get _userRole => _profile?['role'] as String?;

  bool get _isProvider {
    final role = _userRole;
    return role == 'trainer' || role == 'nutritionist';
  }

  void _push(BuildContext context, Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(context, PageTransitions.slideRoute(page));
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go('/welcome');
    } catch (e) {
      if (!mounted) return;
      showHubSnackBar(context, 'Logout failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: RefreshIndicator(
        color: DesignTokens.accentOrange,
        backgroundColor: DesignTokens.surfaceOf(context),
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            HubSectionCard(
              title: 'Account',
              animationDelayMs: 0,
              child: Column(
                children: [
                  HubActionRow(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    onTap: () => _push(context, const EditProfilePage()),
                  ),
                  const Divider(height: 1),
                  HubActionRow(
                    icon: Icons.security_outlined,
                    title: 'Privacy & Security',
                    onTap: () => _push(context, const PrivacySecurityPage()),
                  ),
                  const Divider(height: 1),
                  HubActionRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    onTap: () => _push(context, const ChangePasswordPage()),
                  ),
                  if (_isProvider && !_isLoadingProfile) ...[
                    const Divider(height: 1),
                    HubActionRow(
                      icon: Icons.location_on_outlined,
                      title: 'Service Locations',
                      onTap: () =>
                          _push(context, const ServiceLocationsPage()),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            HubSectionCard(
              title: 'Fitness',
              animationDelayMs: 40,
              child: SettingsFitnessSection(
                onOpenGoals: () =>
                    _push(context, const GoalsPreferencesPage()),
                onOpenHealthConnect: () =>
                    _push(context, const HealthDevicesPage()),
              ),
            ),
            const SizedBox(height: 12),
            HubSectionCard(
              title: 'Preferences',
              animationDelayMs: 80,
              child: Column(
                children: [
                  HubActionRow(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                    onTap: () => _push(context, const NotificationsPage()),
                  ),
                  const Divider(height: 1),
                  HubActionRow(
                    icon: Icons.hub_outlined,
                    title: 'Integrations',
                    subtitle: 'Google Meet',
                    onTap: () => _push(context, const IntegrationsPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            HubSectionCard(
              title: 'Subscription',
              animationDelayMs: 120,
              child: Column(
                children: [
                  HubActionRow(
                    icon: Icons.star_outline_rounded,
                    title: 'Manage Plan',
                    iconColor: AccountHubTheme.subscriptionAmber,
                    onTap: () => _push(context, const SubscriptionPage()),
                  ),
                  const Divider(height: 1),
                  HubActionRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Billing History',
                    trailing: const ComingSoonBadge(),
                    onTap: () => showHubSnackBar(
                      context,
                      'Billing history coming soon',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            HubSectionCard(
              title: 'Support',
              animationDelayMs: 160,
              child: Column(
                children: [
                  HubActionRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    onTap: () => _push(context, const HelpCenterPage()),
                  ),
                  const Divider(height: 1),
                  HubActionRow(
                    icon: Icons.feedback_outlined,
                    title: 'Feedback',
                    onTap: () => _push(context, const FeedbackPage()),
                  ),
                  const Divider(height: 1),
                  HubActionRow(
                    icon: Icons.report_problem_outlined,
                    title: 'Report a Problem',
                    onTap: () => _push(context, const ReportProblemPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            HubSectionCard(
              title: 'Legal',
              animationDelayMs: 200,
              child: SettingsLegalSection(
                appVersion: _appVersion,
                onOpenTerms: () =>
                    _push(context, const TermsOfServicePage()),
                onOpenPrivacy: () =>
                    _push(context, const PrivacyPolicyPage()),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await LogoutConfirmationSheet.show(
                    context,
                    () => _handleLogout(context),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.white,
                  side: BorderSide.none,
                  backgroundColor: colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fitness rows for Settings. Extracted for focused widget tests.
class SettingsFitnessSection extends StatelessWidget {
  const SettingsFitnessSection({
    super.key,
    required this.onOpenGoals,
    required this.onOpenHealthConnect,
  });

  final VoidCallback onOpenGoals;
  final VoidCallback onOpenHealthConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HubActionRow(
          icon: Icons.flag_outlined,
          title: 'Goals & Preferences',
          iconColor: AccountHubTheme.goalsGreen,
          onTap: onOpenGoals,
        ),
        const Divider(height: 1),
        HubActionRow(
          icon: Icons.favorite_outline_rounded,
          title: 'Health Connect',
          subtitle: Platform.isIOS ? 'Apple Health' : 'Steps, calories & more',
          iconColor: AccountHubTheme.goalsGreen,
          onTap: onOpenHealthConnect,
        ),
      ],
    );
  }
}

/// Legal rows for Settings. Extracted for focused widget tests.
class SettingsLegalSection extends StatelessWidget {
  const SettingsLegalSection({
    super.key,
    required this.appVersion,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final String appVersion;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        HubActionRow(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: onOpenTerms,
        ),
        const Divider(height: 1),
        HubActionRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: onOpenPrivacy,
        ),
        const Divider(height: 1),
        Semantics(
          label: appVersion.isEmpty
              ? 'App Version'
              : 'App Version, $appVersion',
          button: false,
          child: HubActionRow(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            showChevron: false,
            trailing: Text(
              appVersion.isEmpty ? '—' : appVersion,
              style: AccountHubTheme.rowSubtitle(context).copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
