import 'package:flutter/material.dart';

import '../client_monitoring/client_detail_shell.dart';
import '../trainer/create_client_page.dart';

class NutritionistClientDetailPage extends StatelessWidget {
  final ClientItem? client;
  final String? clientId;

  const NutritionistClientDetailPage({
    super.key,
    this.client,
    this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    return ClientDetailShell(
      clientId: clientId ?? client?.id ?? '',
      initialClient: client,
      isNutritionist: true,
    );
  }
}
