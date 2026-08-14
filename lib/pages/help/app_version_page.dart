import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/branding_assets.dart';
import '../../utils/launch_utils.dart';
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

  Future<void> _copyVersion() async {
    if (_isLoading) return;
    await Clipboard.setData(
      ClipboardData(text: 'Cotrainr $_version (build $_buildNumber)'),
    );
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showHubSnackBar(context, 'Version copied');
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
        title: const Text('App Version'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HubSectionCard(
            animationDelayMs: 0,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    BrandingAssets.appIcon1024,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Cotrainr app icon',
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      BrandingAssets.appIcon,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Cotrainr',
                  style: AccountHubTheme.rowTitle(context).copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoading
                      ? 'Loading version…'
                      : 'Version $_version · Build $_buildNumber',
                  style: AccountHubTheme.rowSubtitle(context),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your fitness companion',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'Build details',
            animationDelayMs: 40,
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    children: [
                      HubActionRow(
                        icon: Icons.tag_rounded,
                        title: 'Version',
                        showChevron: false,
                        trailing: Text(
                          _version,
                          style: AccountHubTheme.rowTitle(context)
                              .copyWith(fontSize: 14),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: cs.onSurface.withValues(alpha: 0.08),
                      ),
                      HubActionRow(
                        icon: Icons.construction_outlined,
                        title: 'Build',
                        showChevron: false,
                        trailing: Text(
                          _buildNumber,
                          style: AccountHubTheme.rowTitle(context)
                              .copyWith(fontSize: 14),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: cs.onSurface.withValues(alpha: 0.08),
                      ),
                      HubActionRow(
                        icon: Icons.cloud_outlined,
                        title: 'Environment',
                        showChevron: false,
                        trailing: Text(
                          'Production',
                          style: AccountHubTheme.rowTitle(context)
                              .copyWith(fontSize: 14),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: cs.onSurface.withValues(alpha: 0.08),
                      ),
                      HubActionRow(
                        icon: Icons.rocket_launch_outlined,
                        title: 'Release channel',
                        showChevron: false,
                        trailing: Text(
                          'Stable',
                          style: AccountHubTheme.rowTitle(context)
                              .copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'Actions',
            animationDelayMs: 80,
            child: Column(
              children: [
                HubActionRow(
                  icon: Icons.copy_rounded,
                  title: 'Copy version',
                  subtitle: _isLoading
                      ? null
                      : 'Cotrainr $_version (build $_buildNumber)',
                  onTap: _copyVersion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'Support',
            animationDelayMs: 120,
            child: Column(
              children: [
                HubActionRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Support email',
                  subtitle:
                      'Automated outgoing mail uses ${LaunchUtils.noReplyEmail}',
                  showChevron: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
