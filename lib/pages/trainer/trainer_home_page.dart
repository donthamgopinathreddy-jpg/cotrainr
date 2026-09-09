import 'package:flutter/material.dart';

import '../provider/provider_role_home_page.dart';

class TrainerHomePage extends StatelessWidget {
  const TrainerHomePage({
    super.key,
    this.onNavigateToMessagesTab,
    this.onNavigateToMealsTab,
    this.onNavigateToClientsTab,
  });

  final VoidCallback? onNavigateToMessagesTab;
  final VoidCallback? onNavigateToMealsTab;
  final VoidCallback? onNavigateToClientsTab;

  @override
  Widget build(BuildContext context) {
    return ProviderRoleHomePage(
      providerType: 'trainer',
      clientPathPrefix: '/clients',
      onNavigateToMessagesTab: onNavigateToMessagesTab,
      onNavigateToMealsTab: onNavigateToMealsTab,
      onNavigateToClientsTab: onNavigateToClientsTab,
    );
  }
}
