import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/account_hub_theme.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class AppVersionPage extends StatefulWidget {
  const AppVersionPage({super.key});

  @override
  State<AppVersionPage> createState() => _AppVersionPageState();
}

class _AppVersionPageState extends State<AppVersionPage> {
  String _version = '1.0.0';
  String _buildNumber = '1';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('App Version'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _HeroCard(isLight: isLight, isLoading: _isLoading, version: _version),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'Build details',
            animationDelayMs: 40,
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Column(
                    children: [
                      _InfoRow(label: 'Version', value: _version),
                      Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                      ),
                      _InfoRow(label: 'Build', value: _buildNumber),
                      Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                      ),
                      const _InfoRow(label: 'Environment', value: 'Production'),
                      Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                      ),
                      const _InfoRow(label: 'Release channel', value: 'Stable'),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'Support',
            animationDelayMs: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: AccountHubTheme.iconSize,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emails are sent from noreply@cotrainr.com',
                    style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.4),
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

class _HeroCard extends StatelessWidget {
  final bool isLight;
  final bool isLoading;
  final String version;

  const _HeroCard({
    required this.isLight,
    required this.isLoading,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return HubSectionCard(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AccountHubTheme.messagesBlue.withValues(alpha: isLight ? 0.12 : 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AccountHubTheme.messagesBlue,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cotrainr',
            style: AccountHubTheme.rowTitle(context).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLoading ? 'Loading version…' : 'Version $version',
            style: AccountHubTheme.rowSubtitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            'Your fitness companion',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AccountHubTheme.rowSubtitle(context)),
          ),
          Text(
            value,
            style: AccountHubTheme.rowTitle(context).copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
