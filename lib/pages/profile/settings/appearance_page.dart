import 'package:flutter/material.dart';

import '../../../theme/account_hub_theme.dart';
import '../../../widgets/profile/appearance_toggle.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HubSectionCard(
            title: 'Theme',
            child: const AppearanceToggle(),
          ),
        ],
      ),
    );
  }
}
