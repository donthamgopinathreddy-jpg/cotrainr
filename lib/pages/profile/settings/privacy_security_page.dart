import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/location_permission_status.dart';
import '../../../services/privacy_preferences_service.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../utils/launch_utils.dart';
import '../../../utils/page_transitions.dart';
import '../../../widgets/profile/account_hub_widgets.dart';
import 'change_password_page.dart';
import 'info_pages.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({
    super.key,
    this.preferencesService,
    this.locationGateway,
  });

  final PrivacyPreferencesStore? preferencesService;
  final LocationPermissionGateway? locationGateway;

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage>
    with WidgetsBindingObserver {
  late final PrivacyPreferencesStore _service;
  late final LocationPermissionGateway _location;
  PrivacyPreferences _prefs = const PrivacyPreferences();
  bool _loading = true;
  bool _saving = false;
  LocationAccessLabel _locationLabel = LocationAccessLabel.notRequested;

  @override
  void initState() {
    super.initState();
    _service = widget.preferencesService ?? PrivacyPreferencesService();
    _location = widget.locationGateway ?? const LocationPermissionGateway();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocation();
    }
  }

  Future<void> _load() async {
    final prefs = await _service.load();
    final locationLabel = await _location.readLabel();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _locationLabel = locationLabel;
      _loading = false;
    });
  }

  Future<void> _refreshLocation() async {
    final locationLabel = await _location.readLabel();
    if (!mounted) return;
    setState(() => _locationLabel = locationLabel);
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

  Future<void> _requestAccountDeletion() async {
    final ok = await showHubConfirmDialog(
      context,
      title: 'Request Account Deletion',
      message:
          'Account deletion is not available in the app yet. You can email Cotrainr Support to request that your account and associated data be removed. Support will confirm with you before anything is deleted.',
      confirmLabel: 'Email Support',
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
                  child: HubActionRow(
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
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Data Sharing',
                  animationDelayMs: 40,
                  child: Column(
                    children: [
                      HubToggleRow(
                        title: 'Share Activity Data with Trainer',
                        subtitle:
                            'Steps, calories, distance, and water from your daily metrics.',
                        value: _prefs.shareActivityWithTrainer,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(
                            shareActivityWithTrainer: v,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Share Meal Data with Trainer',
                        subtitle: 'Meals you log in Meal Tracker.',
                        value: _prefs.shareMealsWithTrainer,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(
                            shareMealsWithTrainer: v,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Share Meal Logs with Nutritionist',
                        subtitle:
                            'Logged meals only. Calorie and planner targets stay private.',
                        value: _prefs.shareNutritionWithNutritionist,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(
                            shareNutritionWithNutritionist: v,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Permissions',
                  animationDelayMs: 80,
                  child: HubActionRow(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    subtitle:
                        '${locationAccessLabelText(_locationLabel)} · Nearby trainers, nutritionists, and fitness services',
                    trailing: TextButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _location.manage();
                        await _refreshLocation();
                      },
                      child: const Text('Manage'),
                    ),
                    showChevron: false,
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Legal & Data',
                  animationDelayMs: 120,
                  child: Column(
                    children: [
                      HubActionRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      HubActionRow(
                        icon: Icons.description_outlined,
                        title: 'Terms & Conditions',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServicePage(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      const HubActionRow(
                        icon: Icons.download_outlined,
                        title: 'Download My Data',
                        trailing: ComingSoonBadge(),
                        showChevron: false,
                      ),
                      const Divider(height: 1),
                      HubDangerButton(
                        label: 'Request Account Deletion',
                        onTap: _requestAccountDeletion,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Contact',
                  animationDelayMs: 160,
                  child: HubActionRow(
                    icon: Icons.email_outlined,
                    title: 'Contact Support',
                    subtitle: LaunchUtils.supportEmail,
                    showChevron: false,
                    onTap: () => LaunchUtils.sendEmail(
                      context,
                      to: LaunchUtils.supportEmail,
                      subject: 'Privacy & Security',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
