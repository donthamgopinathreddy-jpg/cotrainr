import 'package:flutter/material.dart';

import '../../../theme/account_hub_theme.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class HealthDevicesPage extends StatelessWidget {
  const HealthDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Health Devices'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HubSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Connect wearables and health apps',
                        style: AccountHubTheme.rowTitle(context),
                      ),
                    ),
                    const ComingSoonBadge(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Apple Health, Google Fit, and smartwatch sync will be available in a future update.',
                  style: AccountHubTheme.rowSubtitle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
