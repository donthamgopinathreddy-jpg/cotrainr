import 'package:flutter/material.dart';

import '../provider/provider_my_clients_page.dart';

class NutritionistMyClientsPage extends StatelessWidget {
  const NutritionistMyClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderMyClientsPage(
      providerType: 'nutritionist',
      clientPathPrefix: '/nutritionist/clients',
    );
  }
}
