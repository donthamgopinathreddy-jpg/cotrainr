import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/provider_professional_profile.dart';
import '../repositories/provider_professional_repository.dart';

final providerProfessionalRepositoryProvider =
    Provider<ProviderProfessionalRepository>((ref) {
  return ProviderProfessionalRepository();
});

final myProviderProfessionalProvider =
    AsyncNotifierProvider<MyProviderProfessionalNotifier,
        ProviderProfessionalProfile?>(MyProviderProfessionalNotifier.new);

class MyProviderProfessionalNotifier
    extends AsyncNotifier<ProviderProfessionalProfile?> {
  @override
  Future<ProviderProfessionalProfile?> build() {
    return ref.read(providerProfessionalRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(providerProfessionalRepositoryProvider).fetchMine(),
    );
  }

  Future<void> save({
    required String providerType,
    String? professionalHeadline,
    String? bio,
    int? experienceYears,
    required List<String> specializationIds,
    required List<String> sessionModes,
    required List<String> languages,
    double? hourlyRate,
    required bool acceptingNewClients,
  }) async {
    await ref.read(providerProfessionalRepositoryProvider).saveProfessional(
          providerType: providerType,
          professionalHeadline: professionalHeadline,
          bio: bio,
          experienceYears: experienceYears,
          specializationIds: specializationIds,
          sessionModes: sessionModes,
          languages: languages,
          hourlyRate: hourlyRate,
          acceptingNewClients: acceptingNewClients,
        );
    await refresh();
  }
}

final publicProviderProfessionalProvider = FutureProvider.family<
    ProviderProfessionalProfile?, String>((ref, userId) async {
  return ref
      .read(providerProfessionalRepositoryProvider)
      .fetchByUserId(userId);
});

final providerCertificationsProvider = FutureProvider.family<
    List<ProviderCertification>, ({String providerId, bool publicOnly})>(
  (ref, args) async {
    return ref
        .read(providerProfessionalRepositoryProvider)
        .listCertifications(args.providerId, publicOnly: args.publicOnly);
  },
);
