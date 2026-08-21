import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/leads_models.dart' show Lead;
import '../widgets/provider/provider_clients_summary.dart';
import 'accepted_client_trainers_provider.dart';
import 'leads_provider.dart';

/// Which My Clients tab to show: 0 = Clients, 1 = Requests.
final providerClientsTabIntentProvider = StateProvider<int>((ref) => 0);

class ProviderPracticeSummary {
  final int activeCount;
  final int requestCount;
  final List<ProviderClientPreview> clients;

  const ProviderPracticeSummary({
    required this.activeCount,
    required this.requestCount,
    this.clients = const [],
  });

  static const empty = ProviderPracticeSummary(
    activeCount: 0,
    requestCount: 0,
    clients: [],
  );
}

ProviderClientPreview previewFromLead(Lead lead) {
  final client = lead.client;
  final name = (client?['full_name'] as String?)?.trim() ?? '';
  final username = (client?['username'] as String?)?.trim() ?? '';
  return ProviderClientPreview(
    id: lead.clientId,
    name: name.isNotEmpty ? name : (username.isNotEmpty ? username : 'Client'),
    subtitle: username.isNotEmpty ? '@$username' : 'Active',
    avatarUrl: (client?['avatar_url'] as String?)?.trim(),
    leadId: lead.id,
  );
}

final providerPracticeSummaryProvider =
    FutureProvider.family<ProviderPracticeSummary, String>((ref, providerType) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return ProviderPracticeSummary.empty;

  final leads = await ref.watch(leadsProvider.future);
  final mine = leads
      .where((l) => l.providerId == uid && l.providerType == providerType)
      .toList();
  final accepted = mine.where((l) => l.status == 'accepted').toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final requested = mine.where((l) => l.status == 'requested').toList();

  return ProviderPracticeSummary(
    activeCount: accepted.length,
    requestCount: requested.length,
    clients: accepted.take(3).map(previewFromLead).toList(),
  );
});

void invalidateProviderHomeCounts(WidgetRef ref) {
  ref.invalidate(leadsProvider);
  ref.invalidate(incomingLeadsProvider);
  ref.invalidate(providerPracticeSummaryProvider);
  ref.invalidate(acceptedClientTrainersProvider);
}
