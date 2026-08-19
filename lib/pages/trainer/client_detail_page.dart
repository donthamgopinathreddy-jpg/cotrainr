import 'package:flutter/material.dart';

import '../client_monitoring/client_detail_shell.dart';
import 'create_client_page.dart';

class ClientDetailPage extends StatelessWidget {
  final ClientItem? client;
  final String? clientId;

  const ClientDetailPage({
    super.key,
    this.client,
    this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    return ClientDetailShell(
      clientId: clientId ?? client?.id ?? '',
      initialClient: client,
      isNutritionist: false,
    );
  }
}
