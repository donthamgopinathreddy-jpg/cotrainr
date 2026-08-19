import 'package:flutter/material.dart';

import '../provider/provider_my_clients_page.dart';

class TrainerMyClientsPage extends StatelessWidget {
  const TrainerMyClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderMyClientsPage(
      providerType: 'trainer',
      clientPathPrefix: '/clients',
    );
  }
}
