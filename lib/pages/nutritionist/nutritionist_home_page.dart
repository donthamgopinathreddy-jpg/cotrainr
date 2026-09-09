import 'package:flutter/material.dart';

import '../provider/provider_role_home_page.dart';

class NutritionistHomePage extends StatelessWidget {
  const NutritionistHomePage({
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
      providerType: 'nutritionist',
      clientPathPrefix: '/nutritionist/clients',
      onNavigateToMessagesTab: onNavigateToMessagesTab,
      onNavigateToMealsTab: onNavigateToMealsTab,
      onNavigateToClientsTab: onNavigateToClientsTab,
    );
  }
}
