import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/entitlement_service.dart';

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService();
});

class EntitlementsNotifier extends AsyncNotifier<Entitlements?> {
  @override
  Future<Entitlements?> build() async {
    final service = ref.read(entitlementServiceProvider);
    try {
      return await service.getEntitlements();
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(entitlementServiceProvider);
      return await service.getEntitlements();
    });
  }
}

final entitlementsProvider = AsyncNotifierProvider<EntitlementsNotifier, Entitlements?>(() {
  return EntitlementsNotifier();
});
