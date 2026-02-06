import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/leads_service.dart';
import '../services/leads_models.dart' show Lead;

final leadsServiceProvider = Provider<LeadsService>((ref) {
  return LeadsService();
});

class LeadsNotifier extends AsyncNotifier<List<Lead>> {
  @override
  Future<List<Lead>> build() async {
    final service = ref.read(leadsServiceProvider);
    return await service.getMyLeads();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(leadsServiceProvider);
      return await service.getMyLeads();
    });
  }
}

final leadsProvider = AsyncNotifierProvider<LeadsNotifier, List<Lead>>(() {
  return LeadsNotifier();
});

class IncomingLeadsNotifier extends AsyncNotifier<List<Lead>> {
  @override
  Future<List<Lead>> build() async {
    final service = ref.read(leadsServiceProvider);
    return await service.getIncomingLeads();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(leadsServiceProvider);
      return await service.getIncomingLeads();
    });
  }
}

final incomingLeadsProvider = AsyncNotifierProvider<IncomingLeadsNotifier, List<Lead>>(() {
  return IncomingLeadsNotifier();
});
