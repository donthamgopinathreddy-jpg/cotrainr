import 'package:flutter/material.dart';

import '../../../theme/account_hub_theme.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Units'),
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
                        'Metric / Imperial preferences',
                        style: AccountHubTheme.rowTitle(context),
                      ),
                    ),
                    const ComingSoonBadge(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Global unit preferences are coming soon. Edit Profile currently supports per-field unit toggles for height and weight.',
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
