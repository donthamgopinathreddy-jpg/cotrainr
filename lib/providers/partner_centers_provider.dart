import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/partner_centers_repository.dart';

final partnerCentersRepositoryProvider = Provider<PartnerCentersRepository>((ref) {
  return PartnerCentersRepository();
});

/// Canonical Cotrainr partner centers for Home + Discover (Supabase RPC).
final homePartnerCentersProvider =
    FutureProvider<List<PartnerCenterDiscoverItem>>((ref) async {
  return ref.watch(partnerCentersRepositoryProvider).listForDiscover();
});
