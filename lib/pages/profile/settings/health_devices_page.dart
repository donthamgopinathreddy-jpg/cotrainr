import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/health_connect_settings_info.dart';
import '../../../services/health_tracking_service.dart';
import '../../../services/metrics_sync_service.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class HealthDevicesPage extends ConsumerStatefulWidget {
  const HealthDevicesPage({super.key});

  @override
  ConsumerState<HealthDevicesPage> createState() => _HealthDevicesPageState();
}

class _HealthDevicesPageState extends ConsumerState<HealthDevicesPage>
    with WidgetsBindingObserver {
  final _healthService = HealthTrackingService();
  HealthConnectSettingsInfo? _info;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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
    if (state == AppLifecycleState.resumed && !_busy) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final info = await _healthService.getHealthConnectSettingsInfo();
      if (mounted) setState(() => _info = info);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    HapticFeedback.lightImpact();

    final info = _info;
    if (Platform.isAndroid && info != null && !info.isAvailable) {
      await _healthService.installHealthConnectApp();
      if (mounted) {
        showHubSnackBar(
          context,
          'Install Health Connect, then tap the button again',
        );
      }
      await _load(silent: true);
      return;
    }

    setState(() => _busy = true);
    try {
      // Opens the native Health Connect permission sheet on tap.
      final granted = await _healthService.requestHealthConnectPermissions();

      if (!mounted) return;

      if (!granted && Platform.isAndroid) {
        final status = await _healthService.getHealthConnectSettingsInfo();
        if (!status.isAvailable) {
          await _healthService.installHealthConnectApp();
          if (mounted) {
            showHubSnackBar(
              context,
              'Install Health Connect, then tap the button again',
            );
          }
          await _load(silent: true);
          return;
        }
      }

      await _healthService.reinitializeMetricsSource();

      if (granted) {
        await ref.read(metricsSyncServiceProvider).syncNow();
        if (!mounted) return;
        showHubSnackBar(
          context,
          '${info?.platformLabel ?? 'Health Connect'} connected successfully',
        );
      } else if (mounted) {
        showHubSnackBar(
          context,
          'Select Steps, Calories, Distance, and Water in Health Connect',
        );
      }

      await _load(silent: true);
    } catch (e) {
      if (mounted) showHubSnackBar(context, 'Could not open permissions: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await _healthService.installHealthConnectApp();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(BuildContext context) {
    final info = _info;
    if (info == null) return Colors.grey;
    if (info.isActiveSource && info.permissionsGranted) {
      return AccountHubTheme.goalsGreen;
    }
    if (info.isAvailable) return AccountHubTheme.subscriptionAmber;
    return AccountHubTheme.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final info = _info;
    final title = info?.platformLabel ?? HealthTrackingService.platformHealthLabel();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HubSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _statusColor(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            info?.statusLabel ?? 'Loading…',
                            style: AccountHubTheme.rowTitle(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusDescription(info),
                        style: AccountHubTheme.rowSubtitle(context),
                      ),
                      if (info != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Metrics source: ${info.activeSourceLabel}',
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (info != null && info.typePermissions.isNotEmpty)
                  HubSectionCard(
                    title: 'Permissions',
                    child: Column(
                      children: info.typePermissions.entries.map((entry) {
                        final granted = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                granted
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 20,
                                color: granted
                                    ? AccountHubTheme.goalsGreen
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: AccountHubTheme.rowTitle(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      _connectButtonLabel(info, title),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (Platform.isAndroid &&
                    info != null &&
                    (!info.isAvailable || info.needsInstall)) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _install,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Install Health Connect'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                HubSectionCard(
                  child: Text(
                    'Cotrainr uses $title as the primary source for steps, '
                    'calories, distance, and water. Device sensors are only '
                    'used when $title is unavailable.',
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                ),
              ],
            ),
    );
  }

  String _connectButtonLabel(HealthConnectSettingsInfo? info, String title) {
    if (info == null) return 'Connect $title';
    if (info.isActiveSource && info.permissionsGranted) {
      return 'Manage Health Connect permissions';
    }
    if (!info.isAvailable && Platform.isAndroid) {
      return 'Install Health Connect';
    }
    return 'Allow Health Connect access';
  }

  String _statusDescription(HealthConnectSettingsInfo? info) {
    if (info == null) return '';
    final label = info.platformLabel;
    if (info.isActiveSource && info.permissionsGranted) {
      return 'Your home metrics, goals, and insights sync from $label.';
    }
    if (!info.isAvailable && Platform.isAndroid) {
      return 'Install Health Connect from the Play Store to sync fitness data.';
    }
    if (info.permissionsGranted) {
      return 'Permissions granted — tap below to refresh the connection.';
    }
    return 'Connect $label so steps, calories, distance, and water stay accurate.';
  }
}
