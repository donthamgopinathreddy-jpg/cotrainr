import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/fitness_notification_preferences_service.dart';
import '../../../services/os_notification_permission_status.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.preferencesService,
    this.osPermissionGateway,
  });

  final FitnessNotificationPreferencesStore? preferencesService;
  final OsNotificationPermissionGateway? osPermissionGateway;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  late final FitnessNotificationPreferencesStore _service;
  late final OsNotificationPermissionGateway _osPermission;
  FitnessNotificationPreferences _prefs = const FitnessNotificationPreferences();
  bool _loading = true;
  bool _saving = false;
  OsNotificationAccessLabel _osLabel = OsNotificationAccessLabel.notDetermined;

  @override
  void initState() {
    super.initState();
    _service =
        widget.preferencesService ?? FitnessNotificationPreferencesService();
    _osPermission =
        widget.osPermissionGateway ?? const OsNotificationPermissionGateway();
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
      _refreshOsPermission();
    }
  }

  Future<void> _load() async {
    final prefs = await _service.load();
    final osLabel = await _osPermission.readLabel();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _osLabel = osLabel;
      _loading = false;
    });
  }

  Future<void> _refreshOsPermission() async {
    final osLabel = await _osPermission.readLabel();
    if (!mounted) return;
    setState(() => _osLabel = osLabel);
  }

  Future<void> _persist(FitnessNotificationPreferences next) async {
    if (_saving) return;
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    HapticFeedback.lightImpact();
    try {
      await _service.save(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      showHubSnackBar(context, 'Could not save preferences');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final dependentsEnabled = _prefs.all && !_saving;
    final osDenied = _osLabel == OsNotificationAccessLabel.denied ||
        _osLabel == OsNotificationAccessLabel.permanentlyDenied ||
        _osLabel == OsNotificationAccessLabel.restricted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                HubSectionCard(
                  title: 'Device permission',
                  animationDelayMs: 0,
                  child: HubActionRow(
                    icon: Icons.notifications_outlined,
                    title: 'System notifications',
                    subtitle:
                        '${osNotificationAccessLabelText(_osLabel)} · Controlled by your device settings',
                    trailing: TextButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _osPermission.manage();
                        await _refreshOsPermission();
                      },
                      child: Text(
                        'Manage',
                        style: TextStyle(
                          color: DesignTokens.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    showChevron: false,
                  ),
                ),
                if (osDenied) ...[
                  const SizedBox(height: 8),
                  Text(
                    'App switches cannot override system notification permission while it is denied.',
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                ],
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Push notifications',
                  animationDelayMs: 40,
                  child: HubToggleRow(
                    title: 'All notifications',
                    subtitle: 'Master switch for notifications',
                    value: _prefs.all,
                    enabled: !_saving,
                    onChanged: (v) => _persist(_prefs.copyWith(all: v)),
                  ),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  title: 'Reminders',
                  animationDelayMs: 80,
                  child: HubToggleRow(
                    title: 'Water reminders',
                    subtitle: 'Hydration reminders',
                    value: _prefs.waterReminders,
                    enabled: dependentsEnabled,
                    onChanged: (v) =>
                        _persist(_prefs.copyWith(waterReminders: v)),
                  ),
                ),
              ],
            ),
    );
  }
}
